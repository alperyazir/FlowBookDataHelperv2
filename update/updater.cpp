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

} // namespace

Updater::Updater(QObject *parent) : QObject(parent) {}

void Updater::applyManifest(const QVariantMap &manifest) {
    if (m_busy)
        return; // a pass is already running; the next heartbeat will retry
    if (manifest.isEmpty()) {
        emit finished();
        return;
    }
    setBusy(true);
    // Detach a copy onto a worker thread — networking + unzip must not block UI.
    QVariantMap copy = manifest;
    QtConcurrent::run([this, copy]() {
        runManifest(copy);
        setProgress(0);
        setBusy(false);
        emit finished();
    });
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

void Updater::runManifest(const QVariantMap &manifest) {
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

    // 2) Readers: sync every advertised platform build that is newer than local.
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
        syncReader(folder, url, sha, version);
    }
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
