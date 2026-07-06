#include "updater.h"

#include "config/configparser.h"

#include <QtConcurrent>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QCryptographicHash>
#include <QProcess>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QEventLoop>
#include <QStandardPaths>
#include <QUrl>
#include <QRegularExpression>
#include <QVariantMap>
#include <QVariantList>
#include <QCoreApplication>

#ifndef APP_VERSION
#define APP_VERSION "0.0.0"
#endif

namespace {

// Compare dotted numeric versions ("3.10.0" > "3.9.0"). Non-numeric tails are
// compared lexically as a tie-breaker. Returns >0 if a>b, <0 if a<b, 0 if equal.
int compareVersions(const QString &a, const QString &b) {
    const QStringList as = a.split(QRegularExpression("[._-]"), Qt::SkipEmptyParts);
    const QStringList bs = b.split(QRegularExpression("[._-]"), Qt::SkipEmptyParts);
    const int n = qMax(as.size(), bs.size());
    for (int i = 0; i < n; ++i) {
        const QString ap = i < as.size() ? as[i] : QString();
        const QString bp = i < bs.size() ? bs[i] : QString();
        bool aok = false, bok = false;
        const int ai = ap.toInt(&aok);
        const int bi = bp.toInt(&bok);
        if (aok && bok) {
            if (ai != bi) return ai < bi ? -1 : 1;
        } else {
            const int c = QString::compare(ap, bp);
            if (c != 0) return c < 0 ? -1 : 1;
        }
    }
    return 0;
}

// Manifest key ("reader-win") → on-disk package folder ("win").
QString platformFolderForKey(const QString &key) {
    if (!key.startsWith(QLatin1String("reader-")))
        return QString();
    return key.mid(QStringLiteral("reader-").size());
}

// On-disk platform folder → the name shown in the update menu.
QString platformDisplayName(const QString &folder) {
    if (folder == QLatin1String("win"))   return QStringLiteral("Windows");
    if (folder == QLatin1String("mac"))   return QStringLiteral("macOS");
    if (folder == QLatin1String("linux")) return QStringLiteral("Linux");
    return folder;
}

// Pull a clean dotted version out of a version-folder name for display
// (e.g. "(win) FlowBook v1.7.0" -> "1.7.0"); falls back to the raw name.
QString extractVersionLabel(const QString &name) {
    static const QRegularExpression re(QStringLiteral("\\d+(?:\\.\\d+)+"));
    const QRegularExpressionMatch m = re.match(name);
    return m.hasMatch() ? m.captured(0) : name;
}

// Recursively copy the contents of src into dst (creating dst). Overwrites files.
bool copyDirRecursively(const QString &src, const QString &dst) {
    QDir sdir(src);
    if (!sdir.exists())
        return false;
    if (!QDir().mkpath(dst))
        return false;
    const QFileInfoList entries = sdir.entryInfoList(
        QDir::NoDotAndDotDot | QDir::AllEntries | QDir::Hidden | QDir::System);
    for (const QFileInfo &fi : entries) {
        const QString target = dst + "/" + fi.fileName();
        if (fi.isDir()) {
            if (!copyDirRecursively(fi.absoluteFilePath(), target))
                return false;
        } else {
            QFile::remove(target); // QFile::copy won't overwrite
            if (!QFile::copy(fi.absoluteFilePath(), target))
                return false;
        }
    }
    return true;
}

} // namespace

Updater::Updater(QObject *parent) : QObject(parent) {
    refreshInstalled();
    // On startup, make sure the latest installed win build is mirrored into the
    // test/ folder (handles the reader that shipped with the installer). Done on
    // a worker thread — the data/ copy is large and must not block the UI.
    QtConcurrent::run([this]() { mirrorWinToTest(); });
}

void Updater::mirrorDataToTest(const QString &dataDir, const QString &versionLabel, bool force) {
    // The test build is the win reader WITHOUT the root starter exe or the data/
    // wrapper: just the contents of data/ (which include the real FlowBook.exe),
    // under test/FlowBookTestVersion v<version>/.
    if (!QDir(dataDir).exists())
        return;
    const QString testRoot = ConfigParser::programRoot() + "test";
    const QString name = "FlowBookTestVersion v" + versionLabel;
    const QString testDir = testRoot + "/" + name;

    bool needCopy = true;
    if (QDir(testDir).exists()) {
        if (force)
            QDir(testDir).removeRecursively();
        else
            needCopy = false; // already mirrored for this version
    }
    if (needCopy) {
        setStatusMessage(QString("Preparing test version %1…").arg(versionLabel));
        copyDirRecursively(dataDir, testDir);
    }

    // Only the latest test build is kept — drop any older FlowBookTestVersion folders.
    QDir tr(testRoot);
    if (tr.exists()) {
        const QStringList olds =
            tr.entryList({QStringLiteral("FlowBookTestVersion v*")}, QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &s : olds) {
            if (s != name)
                QDir(testRoot + "/" + s).removeRecursively();
        }
    }
}

void Updater::mirrorWinToTest() {
    const QString winFolder = installedReaderVersion(QStringLiteral("win"));
    if (winFolder.isEmpty())
        return;
    const QString dataDir =
        ConfigParser::programRoot() + "package/win/" + winFolder + "/data";
    mirrorDataToTest(dataDir, extractVersionLabel(winFolder), false);
}

void Updater::refreshInstalled() {
    QVariantList list;
    QVariantMap helper;
    helper["label"] = QStringLiteral("Helper");
    helper["version"] = QStringLiteral(APP_VERSION);
    list.append(helper);

    QDir pkg(ConfigParser::programRoot() + "package");
    if (pkg.exists()) {
        const QStringList platforms = pkg.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &p : platforms) {
            const QString folder = installedReaderVersion(p);
            if (folder.isEmpty())
                continue;
            QVariantMap e;
            e["label"] = platformDisplayName(p);
            e["version"] = extractVersionLabel(folder);
            list.append(e);
        }
    }
    m_installedComponents = list;
    emit installedComponentsChanged();
}

void Updater::applyManifest(const QVariantMap &manifest) {
    if (m_busy)
        return; // an apply pass is running; don't re-detect underneath it
    if (manifest.isEmpty())
        return;
    // Detection only — cheap and disk-only. Nothing is downloaded until the user
    // triggers applyUpdate() from the version badge.
    detect(manifest);
}

void Updater::applyEditorUpdate() {
    if (m_busy)
        return;
    if (m_editorUrl.isEmpty()) {
        emit error("No editor update is available to apply.");
        return;
    }
    setBusy(true);
    const QString url = m_editorUrl;
    const QString sha = m_editorSha;
    const QString ver = m_editorUpdateVersion;
    QtConcurrent::run([this, url, sha, ver]() {
        setStatusMessage(QString("Downloading editor %1…").arg(ver));
        const QString zip = downloadToTemp(url, sha);
        if (zip.isEmpty()) {
            setBusy(false);
            emit error("Editor download or checksum failed.");
            return;
        }
        const QString srcDir =
            QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/fbeditor_" + ver;
        setStatusMessage(QString("Preparing editor %1…").arg(ver));
        if (!extractZip(zip, srcDir)) {
            QFile::remove(zip);
            setBusy(false);
            emit error("Editor package could not be extracted.");
            return;
        }
        QFile::remove(zip);
        // The swap (overwrite the running install) must happen after we quit, so
        // hand off to the helper from the main thread.
        QMetaObject::invokeMethod(this, [this, srcDir]() { launchUpdaterAndQuit(srcDir); },
                                  Qt::QueuedConnection);
    });
}

void Updater::launchUpdaterAndQuit(const QString &srcDir) {
    const QString appDir = QCoreApplication::applicationDirPath();
    const QString exePath = QCoreApplication::applicationFilePath();
#ifdef Q_OS_WIN
    const QString helperName = "updater.exe";
#else
    const QString helperName = "updater";
#endif
    const QString installedHelper = appDir + "/" + helperName;
    // Run the helper from a temp copy so it can overwrite its own installed copy
    // as part of the update.
    const QString tmpHelper =
        QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/" + helperName;
    QFile::remove(tmpHelper);
    if (!QFile::copy(installedHelper, tmpHelper)) {
        setBusy(false);
        emit error("Update helper not found next to the app: " + installedHelper);
        return;
    }
#ifndef Q_OS_WIN
    QFile::setPermissions(tmpHelper,
                          QFile::permissions(tmpHelper) | QFile::ExeOwner | QFile::ExeUser);
#endif
    QStringList args;
    args << srcDir << appDir << exePath << QString::number(QCoreApplication::applicationPid());
    if (!QProcess::startDetached(tmpHelper, args)) {
        setBusy(false);
        emit error("Could not launch the update helper.");
        return;
    }
    emit editorUpdateStarted();
    QCoreApplication::quit();
}

void Updater::detect(const QVariantMap &manifest) {
    // 1) Editor: flag only — the actual swap is the updater.exe hand-off.
    const QVariantMap editor = manifest.value("editor").toMap();
    if (!editor.isEmpty()) {
        const QString remote = editor.value("version").toString();
        if (!remote.isEmpty() && compareVersions(remote, QStringLiteral(APP_VERSION)) > 0) {
            m_editorUpdateVersion = remote;
            m_editorUrl = editor.value("url").toString();
            m_editorSha = editor.value("sha256").toString().toLower();
            m_editorUpdateAvailable = true;
        } else {
            m_editorUpdateAvailable = false;
            m_editorUpdateVersion.clear();
            m_editorUrl.clear();
            m_editorSha.clear();
        }
        emit editorUpdateAvailableChanged();
    }

    // 2) Content (readers): record every advertised platform build that is newer
    //    than local, but do NOT download — that waits for applyUpdate().
    QVariantList pending;
    const QStringList keys = manifest.keys();
    for (const QString &key : keys) {
        const QString folder = platformFolderForKey(key);
        if (folder.isEmpty())
            continue;
        const QVariantMap e = manifest.value(key).toMap();
        const QString version = e.value("version").toString();
        const QString url = e.value("url").toString();
        const QString sha = e.value("sha256").toString().toLower();
        if (version.isEmpty() || url.isEmpty())
            continue;
        const QString local = installedReaderVersion(folder);
        if (!local.isEmpty() && compareVersions(version, local) <= 0)
            continue; // already current
        QVariantMap entry;
        entry["folder"] = folder;
        entry["url"] = url;
        entry["sha256"] = sha;
        entry["version"] = version;
        pending.append(entry);
    }
    m_pendingReaders = pending;
    m_contentUpdateAvailable = !pending.isEmpty();

    // Build the menu list: the editor (shown as "Helper") first, then each
    // content build. Neutral labels — no internal "reader" wording.
    QVariantList items;
    if (m_editorUpdateAvailable) {
        QVariantMap e;
        e["label"] = QStringLiteral("Helper");
        e["version"] = m_editorUpdateVersion;
        items.append(e);
    }
    for (const QVariant &r : pending) {
        const QVariantMap m = r.toMap();
        QVariantMap e;
        e["label"] = platformDisplayName(m.value("folder").toString());
        e["version"] = m.value("version");
        items.append(e);
    }
    m_pendingUpdates = items;

    recomputeAvailableVersion();
    emit updateAvailableChanged();
}

void Updater::recomputeAvailableVersion() {
    QString v;
    if (m_editorUpdateAvailable) {
        v = m_editorUpdateVersion; // an editor bump takes the headline
    } else {
        for (const QVariant &item : m_pendingReaders) {
            const QString ver = item.toMap().value("version").toString();
            if (v.isEmpty() || compareVersions(ver, v) > 0)
                v = ver;
        }
    }
    m_availableVersion = v;
}

void Updater::applyUpdate() {
    if (m_busy)
        return;
    if (!updateAvailable())
        return;
    setBusy(true);

    // Snapshot the pending work so the worker thread never touches live members.
    const QVariantList readers = m_pendingReaders;
    const bool doEditor = m_editorUpdateAvailable;
    const QString eurl = m_editorUrl;
    const QString esha = m_editorSha;
    const QString ever = m_editorUpdateVersion;

    QtConcurrent::run([this, readers, doEditor, eurl, esha, ever]() {
        // 1) Content builds first: download + verify + extract into
        //    package/<folder>/<version>/ (silent — no running reader to swap).
        for (const QVariant &item : readers) {
            const QVariantMap m = item.toMap();
            syncReader(m.value("folder").toString(), m.value("url").toString(),
                       m.value("sha256").toString(), m.value("version").toString());
        }

        // 2) Editor last: download + verify + extract, then hand off to the
        //    helper (which waits for us to exit, overwrites the install, and
        //    relaunches). This quits the app.
        if (doEditor) {
            setStatusMessage(QString("Downloading version %1…").arg(ever));
            const QString zip = downloadToTemp(eurl, esha);
            if (zip.isEmpty()) {
                setProgress(0);
                setBusy(false);
                emit error("Update download or checksum failed.");
                return;
            }
            const QString srcDir =
                QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/fbeditor_" + ever;
            setStatusMessage(QString("Preparing version %1…").arg(ever));
            if (!extractZip(zip, srcDir)) {
                QFile::remove(zip);
                setProgress(0);
                setBusy(false);
                emit error("Update package could not be extracted.");
                return;
            }
            QFile::remove(zip);
            QMetaObject::invokeMethod(this, [this, srcDir]() { launchUpdaterAndQuit(srcDir); },
                                      Qt::QueuedConnection);
            return; // app quits from here
        }

        // Content-only pass: clear pending state and report done on the main thread.
        setProgress(0);
        setBusy(false);
        QMetaObject::invokeMethod(this, [this]() {
            m_pendingReaders.clear();
            m_contentUpdateAvailable = false;
            m_pendingUpdates.clear();
            recomputeAvailableVersion();
            refreshInstalled();
            emit updateAvailableChanged();
            emit finished();
        }, Qt::QueuedConnection);
    });
}

QString Updater::installedReaderVersion(const QString &platformFolder) const {
    QDir dir(ConfigParser::programRoot() + "package/" + platformFolder);
    if (!dir.exists())
        return QString();
    QStringList versions = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    if (versions.isEmpty())
        return QString();
    std::sort(versions.begin(), versions.end(),
              [](const QString &a, const QString &b) { return compareVersions(a, b) > 0; });
    return versions.first();
}

bool Updater::syncReader(const QString &platformFolder, const QString &url,
                         const QString &sha256, const QString &version) {
    const QString local = installedReaderVersion(platformFolder);
    if (!local.isEmpty() && compareVersions(version, local) <= 0)
        return true; // already current

    setStatusMessage(QString("Downloading %1 reader %2…").arg(platformFolder, version));
    const QString zip = downloadToTemp(url, sha256);
    if (zip.isEmpty()) {
        emit error(QString("Download/verify failed for %1 reader %2").arg(platformFolder, version));
        return false;
    }

    const QString dest = ConfigParser::programRoot() + "package/" + platformFolder + "/" + version;
    setStatusMessage(QString("Installing %1 reader %2…").arg(platformFolder, version));
    if (!extractZip(zip, dest)) {
        QDir(dest).removeRecursively(); // don't leave a half-written version folder
        QFile::remove(zip);
        emit error(QString("Extract failed for %1 reader %2").arg(platformFolder, version));
        return false;
    }
    QFile::remove(zip);
    setStatusMessage(QString("%1 reader updated to %2").arg(platformFolder, version));
    emit readerUpdated(platformFolder, version);

    // Keep the test/ build in step with the latest win reader: mirror the freshly
    // extracted data/ into test/FlowBookTestVersion v<version>/.
    if (platformFolder == QLatin1String("win"))
        mirrorDataToTest(dest + "/data", version, true);

    return true;
}

QString Updater::downloadToTemp(const QString &url, const QString &sha256) {
    // QNAM lives on and is driven by this worker thread via a local event loop.
    QNetworkAccessManager nam;
    QNetworkRequest req((QUrl(url)));
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = nam.get(req);

    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::downloadProgress, &loop,
                     [this](qint64 got, qint64 total) {
                         if (total > 0)
                             setProgress(int(got * 100 / total));
                     });
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const QByteArray data = reply->readAll();
    const bool ok = reply->error() == QNetworkReply::NoError;
    reply->deleteLater();
    if (!ok || data.isEmpty())
        return QString();

    if (!sha256.isEmpty()) {
        const QString actual =
            QString::fromLatin1(QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex());
        if (actual.compare(sha256, Qt::CaseInsensitive) != 0)
            return QString(); // integrity check failed — refuse the payload
    }

    const QString tmpDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    QDir().mkpath(tmpDir);
    const QString path = tmpDir + "/fbupd_" + QFileInfo(QUrl(url).path()).fileName();
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly))
        return QString();
    f.write(data);
    f.close();
    return path;
}

bool Updater::extractZip(const QString &zipPath, const QString &destDir) {
    QDir d(destDir);
    if (d.exists())
        d.removeRecursively();
    if (!QDir().mkpath(destDir))
        return false;

    QString program;
    QStringList args;
#ifdef Q_OS_WIN
    QString sevenZip = "C:/Program Files/7-Zip/7z.exe";
    if (!QFile::exists(sevenZip))
        sevenZip = "C:/Program Files (x86)/7-Zip/7z.exe";
    if (!QFile::exists(sevenZip))
        return false;
    program = sevenZip;
    args << "x" << "-y" << zipPath << ("-o" + destDir);
#else
    program = "unzip";
    args << "-o" << zipPath << "-d" << destDir;
#endif

    QProcess p;
    p.start(program, args);
    if (!p.waitForStarted(10000))
        return false;
    if (!p.waitForFinished(600000)) // large reader builds can take a while
        return false;
    return p.exitStatus() == QProcess::NormalExit && p.exitCode() == 0;
}

void Updater::setBusy(bool v) {
    if (m_busy == v) return;
    m_busy = v;
    QMetaObject::invokeMethod(this, [this]() { emit busyChanged(); }, Qt::QueuedConnection);
}

void Updater::setProgress(int v) {
    if (m_progress == v) return;
    m_progress = v;
    QMetaObject::invokeMethod(this, [this]() { emit progressChanged(); }, Qt::QueuedConnection);
}

void Updater::setStatusMessage(const QString &v) {
    if (m_statusMessage == v) return;
    m_statusMessage = v;
    QMetaObject::invokeMethod(this, [this]() { emit statusMessageChanged(); }, Qt::QueuedConnection);
}
