#include "pdfprocess.h"
#include <QDebug>
#include <QProcess>
#include <QTemporaryFile>
#include <QDir>
#include <QRegularExpression>
#include <QTextStream>
#include <QFile>
#include <QGuiApplication>
#include <algorithm>
#include <QtConcurrent>
#include <QStandardPaths>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFileInfo>
#include <QDateTime>

QString PdfProcess::scriptsDir()
{
    static QString cached;
    if (!cached.isEmpty())
        return cached;

    // Dev override: point at a live source dir to edit scripts without a
    // rebuild (set FLOWBOOK_SCRIPTS_DIR=/path/to/scripts).
    const QByteArray env = qgetenv("FLOWBOOK_SCRIPTS_DIR");
    if (!env.isEmpty() && QDir(QString::fromLocal8Bit(env)).exists()) {
        cached = QString::fromLocal8Bit(env);
        qDebug() << "Scripts dir (env override):" << cached;
        return cached;
    }

    // Extract the bundled scripts (scripts.qrc) to a writable dir once.
    // Same path on macOS and Windows — no fragile relative navigation.
    const QString dest =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
        + "/scripts";
    QDir().mkpath(dest);

    const QDir res(":/scripts");
    const QStringList files = res.entryList(QDir::Files);
    for (const QString &name : files) {
        const QString out = dest + "/" + name;
        QFile::remove(out);                 // copy won't overwrite
        if (QFile::copy(":/scripts/" + name, out)) {
            QFile::setPermissions(out, QFileDevice::ReadOwner
                                       | QFileDevice::WriteOwner
                                       | QFileDevice::ReadGroup
                                       | QFileDevice::ReadOther);
        } else {
            qWarning() << "scriptsDir: failed to extract" << name;
        }
    }
    qDebug() << "Scripts extracted:" << files.size() << "->" << dest;
    cached = dest;
    return cached;
}

QString PdfProcess::pythonExecutable()
{
    // QProcess does NOT use shell aliases, so "python" (only a shell alias on
    // most setups) fails to start. We also can't just grab the first python3 on
    // PATH: a GUI .app bundle runs with a minimal PATH where the first match is
    // Apple's /usr/bin/python3 stub, which lacks PyMuPDF ("fitz"). So we probe
    // candidate interpreters and pick the first one that can import fitz.
    static QString cached;
    if (!cached.isEmpty())
        return cached;

    QStringList candidates;
    // Real interpreters that typically carry third-party packages come first.
#ifdef Q_OS_WIN
    // On Windows the binary is usually "python"; "python3" is often the
    // Microsoft Store stub, so prefer "python" and the "py" launcher.
    const QStringList preferred = {
        QStandardPaths::findExecutable("python"),
        QStandardPaths::findExecutable("py"),
        QStandardPaths::findExecutable("python3")
    };
#else
    const QStringList preferred = {
        QStandardPaths::findExecutable("python3"),
        QStandardPaths::findExecutable("python"),
        "/opt/homebrew/bin/python3",
        "/usr/local/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3",
        // Apple's stub is the last resort - it rarely has the deps installed.
        "/usr/bin/python3"
    };
#endif
    for (const QString &p : preferred) {
        if (!p.isEmpty() && QFile::exists(p) && !candidates.contains(p))
            candidates << p;
    }

#ifdef Q_OS_WIN
    // A GUI app launched from Explorer inherits a PATH that may not contain
    // Python (e.g. it was added to PATH after the session/Explorer started),
    // so findExecutable above finds nothing. Scan the standard install roots
    // directly so we locate python.exe regardless of PATH. Newest version
    // first (Reversed sort: Python313 before Python311).
    QStringList winRoots;
    const QByteArray localAppData = qgetenv("LOCALAPPDATA");
    if (!localAppData.isEmpty())
        winRoots << QString::fromLocal8Bit(localAppData) + "/Programs/Python";
    winRoots << "C:/Program Files/Python"
             << "C:/Program Files (x86)/Python"
             << "C:/";
    for (const QString &root : winRoots) {
        QDir dir(root);
        if (!dir.exists())
            continue;
        const QStringList subs = dir.entryList({"Python3*"}, QDir::Dirs,
                                               QDir::Name | QDir::Reversed);
        for (const QString &sub : subs) {
            const QString exe = dir.filePath(sub) + "/python.exe";
            if (QFile::exists(exe) && !candidates.contains(exe))
                candidates << exe;
        }
    }
#endif

    QString firstUsable;
    for (const QString &path : candidates) {
        if (firstUsable.isEmpty())
            firstUsable = path; // remember a runnable interpreter as a fallback
        QProcess probe;
        probe.start(path, {"-c", "import fitz"});
        if (probe.waitForFinished(5000) && probe.exitStatus() == QProcess::NormalExit
            && probe.exitCode() == 0) {
            cached = path; // this interpreter has the required modules
            return cached;
        }
    }

    // No interpreter could import fitz; fall back to a runnable one (the script
    // will surface a clear ModuleNotFoundError if deps are genuinely missing).
    cached = firstUsable.isEmpty() ? QStringLiteral("python3") : firstUsable;
    return cached;
}

void PdfProcess::startProcessing(const QString &pdfConfig)
{
    qDebug() << "Starting PDF processing with config:" << pdfConfig;
    QString mPdfConfig = pdfConfig;
    if (mPdfConfig.size() > 0 && mPdfConfig.startsWith("/")) {
    }
    //emit processingStarted();

    // Create a temporary file to store the JSON config
    QTemporaryFile tempFile;
    if (!tempFile.open()) {
        qDebug() << "Failed to create temporary file for JSON config";
        //emit processingError("Failed to create temporary file for JSON config");
        return;
    }

    // Write the JSON config to the temp file
    QTextStream out(&tempFile);
    out << mPdfConfig;
    out.flush();

    // Keep the temp file open but detach it so it doesn't get deleted when tempFile goes out of scope
    QString tempPath = tempFile.fileName();
    tempFile.setAutoRemove(false);
    tempFile.close();

    // Setup the process to run the Python script
    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("PYTHONIOENCODING", "utf-8");
    process->setProcessEnvironment(env);
    process->setProcessChannelMode(QProcess::MergedChannels);

    // Connect to readyRead to capture output in real-time
    connect(process, &QProcess::readyRead, [this, process]() {
        //QString line = process->readAll();
        //qDebug() << "Process output:" << output;
        QString line = process->readLine().trimmed();

        // PROGRESS mesajlarını yakala
        if (line.startsWith("PROGRESS:")) {
            QString progressStr = line.mid(9, line.indexOf("%") - 9);
            bool ok;
            int progressValue = progressStr.toInt(&ok);
            setProgress(progressValue);

        } else {
            // Normal log mesajları
            setLogMessages(line);
            qDebug() << line;
        }
        //emit processingOutput(output);
    });

    // Connect to finished to handle completion
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            [this, process, tempPath](int exitCode, QProcess::ExitStatus exitStatus) {
                QByteArray remainingOutput = process->readAllStandardOutput();
                if (!remainingOutput.isEmpty()) {
                    QString remainingText = QString::fromUtf8(remainingOutput);
                    // Satır satır işle
                    QStringList lines = remainingText.split('\n', Qt::SkipEmptyParts);
                    for (const QString &line : lines) {
                        if (line.startsWith("PROGRESS:")) {
                            // Progress işleme
                            QString progressStr = line.mid(9, line.indexOf("%") - 9);
                            bool ok;
                            int progressValue = progressStr.toInt(&ok);
                            setProgress(progressValue);
                        } else {
                            // Log mesajı
                            setLogMessages(line);
                            qDebug() << "Remaining output:" << line;
                        }
                    }
                }

                if (exitStatus == QProcess::NormalExit && exitCode == 0) {
                    qDebug() << "PDF processing completed successfully";
                    setLogMessages("PDF processing completed successfully");
                    //emit processingCompleted();
                } else {
                    QString error = "Process failed with exit code: " + QString::number(exitCode);
                    qDebug() << error;
                    //emit processingError(error);
                    setLogMessages(error);
                }

                // Clean up
                QFile::remove(tempPath);
                process->deleteLater();
            });

    // Connect to error handling
    connect(process, &QProcess::errorOccurred, [this, process, tempPath](QProcess::ProcessError error) {
        QString errorMessage = "Process error: " + QString::number(error) + " - " + process->errorString();
        qDebug() << errorMessage;
        //emit processingError(errorMessage);
        setLogMessages(errorMessage);

        // Clean up
        QFile::remove(tempPath);
        process->deleteLater();
    });

    // Scripts are bundled (scripts.qrc) and extracted to a writable dir.
    QString scriptPath = scriptsDir() + "/smartdatahelper.py";



    // Set up the process arguments
    QStringList arguments;
    arguments << "-u" << scriptPath << tempPath;

     qDebug() << "SCRIPT PATH: " << arguments;

    // Start the process with python3 command
    process->start(pythonExecutable(), arguments);

    // Don't wait here - the process will emit signals as it proceeds
    qDebug() << "Python process started";
}

void PdfProcess::startAIAnalysis(const QString &configPath, const QString &settingsPath)
{
    // Re-entry guard: a second concurrent run writes to the same
    // config.json and competes for CPU/RAM, so both runs slow down and
    // their PROGRESS streams interleave on the shared progress bar (the
    // "80% -> 40%" jump). Ignore duplicate requests while one is live.
    if (_aiAnalyzing) {
        qDebug() << "AI Analysis already running — ignoring duplicate request";
        return;
    }
    _aiAnalyzing = true;
    emit aiAnalyzingChanged();

    qDebug() << "Starting AI Analysis with config:" << configPath << "settings:" << settingsPath;

    // Setup the process to run the Python script
    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("PYTHONIOENCODING", "utf-8");
    process->setProcessEnvironment(env);
    process->setProcessChannelMode(QProcess::MergedChannels);

    // Connect to readyRead to capture output in real-time
    connect(process, &QProcess::readyRead, [this, process]() {
        while (process->canReadLine()) {
            QString line = QString::fromUtf8(process->readLine()).trimmed();
            if (line.isEmpty()) continue;

            if (line.startsWith("PROGRESS:")) {
                QString progressStr = line.mid(9, line.indexOf("%") - 9);
                bool ok;
                int progressValue = progressStr.toInt(&ok);
                if (ok) setProgress(progressValue);
            } else {
                setLogMessages(line);
                qDebug() << line;
            }
        }
    });

    // Connect to finished to handle completion
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            [this, process](int exitCode, QProcess::ExitStatus exitStatus) {
                QByteArray remainingOutput = process->readAllStandardOutput();
                if (!remainingOutput.isEmpty()) {
                    QString remainingText = QString::fromUtf8(remainingOutput);
                    QStringList lines = remainingText.split('\n', Qt::SkipEmptyParts);
                    for (const QString &line : lines) {
                        if (line.startsWith("PROGRESS:")) {
                            QString progressStr = line.mid(9, line.indexOf("%") - 9);
                            bool ok;
                            int progressValue = progressStr.toInt(&ok);
                            if (ok) setProgress(progressValue);
                        } else {
                            setLogMessages(line);
                            qDebug() << "Remaining output:" << line;
                        }
                    }
                }

                _aiAnalyzing = false;
                emit aiAnalyzingChanged();

                if (exitStatus == QProcess::NormalExit && exitCode == 0) {
                    qDebug() << "AI Analysis completed successfully";
                    setLogMessages("AI Analysis completed successfully");
                    emit aiAnalysisCompleted(true);
                } else {
                    QString error = "AI Analysis failed with exit code: " + QString::number(exitCode);
                    qDebug() << error;
                    setLogMessages(error);
                    emit aiAnalysisCompleted(false);
                }

                process->deleteLater();
            });

    // Connect to error handling
    connect(process, &QProcess::errorOccurred, [this, process](QProcess::ProcessError error) {
        QString errorMessage = "Process error: " + QString::number(error) + " - " + process->errorString();
        qDebug() << errorMessage;
        setLogMessages(errorMessage);
        _aiAnalyzing = false;
        emit aiAnalyzingChanged();
        emit aiAnalysisCompleted(false);
        process->deleteLater();
    });

    // Construct the path to the Python script
    QString scriptPath = scriptsDir() + "/ai_analyzer.py";

    // Set up the process arguments
    QStringList arguments;
    arguments << "-u" << scriptPath << configPath << settingsPath;

    qDebug() << "AI ANALYZER SCRIPT PATH: " << arguments;

    // Start the process
    process->start(pythonExecutable(), arguments);

    qDebug() << "AI Analyzer process started";
}

void PdfProcess::matchIcons(const QString &configPath,
                            const QString &audioIconPath,
                            const QString &videoIconPath)
{
    if (audioIconPath.isEmpty() && videoIconPath.isEmpty()) {
        qDebug() << "matchIcons: no icon template given — nothing to do";
        emit aiAnalysisCompleted(false);
        return;
    }
    // Share the AI re-entry guard: both write config.json and shouldn't race.
    if (_aiAnalyzing) {
        qDebug() << "matchIcons: a run is already live — ignoring";
        return;
    }
    _aiAnalyzing = true;
    emit aiAnalyzingChanged();

    qDebug() << "matchIcons config:" << configPath
             << "audio:" << audioIconPath << "video:" << videoIconPath;

    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("PYTHONIOENCODING", "utf-8");
    process->setProcessEnvironment(env);
    process->setProcessChannelMode(QProcess::MergedChannels);

    connect(process, &QProcess::readyRead, [this, process]() {
        while (process->canReadLine()) {
            QString line = QString::fromUtf8(process->readLine()).trimmed();
            if (line.isEmpty()) continue;
            if (line.startsWith("PROGRESS:")) {
                bool ok;
                int v = line.mid(9, line.indexOf("%") - 9).toInt(&ok);
                if (ok) setProgress(v);
            } else {
                setLogMessages(line);
                qDebug() << line;
            }
        }
    });

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            [this, process](int exitCode, QProcess::ExitStatus exitStatus) {
                QByteArray rest = process->readAllStandardOutput();
                if (!rest.isEmpty()) {
                    for (const QString &line :
                         QString::fromUtf8(rest).split('\n', Qt::SkipEmptyParts)) {
                        QString t = line.trimmed();
                        if (t.startsWith("PROGRESS:")) {
                            bool ok;
                            int v = t.mid(9, t.indexOf("%") - 9).toInt(&ok);
                            if (ok) setProgress(v);
                        } else {
                            setLogMessages(t);
                            qDebug() << "Remaining output:" << line;
                        }
                    }
                }
                _aiAnalyzing = false;
                emit aiAnalyzingChanged();
                bool ok = (exitStatus == QProcess::NormalExit && exitCode == 0);
                setLogMessages(ok ? "Icon match completed"
                                  : "Icon match failed with exit code: "
                                        + QString::number(exitCode));
                emit aiAnalysisCompleted(ok);
                process->deleteLater();
            });

    connect(process, &QProcess::errorOccurred, [this, process](QProcess::ProcessError error) {
        qDebug() << "matchIcons process error:" << error << process->errorString();
        setLogMessages("Icon match process error: " + process->errorString());
        _aiAnalyzing = false;
        emit aiAnalyzingChanged();
        emit aiAnalysisCompleted(false);
        process->deleteLater();
    });

    QString scriptPath = scriptsDir() + "/proto_icon_match.py";
    QStringList arguments;
    arguments << "-u" << scriptPath << configPath;
    if (!audioIconPath.isEmpty())
        arguments << "--audio-icon" << audioIconPath;
    if (!videoIconPath.isEmpty())
        arguments << "--video-icon" << videoIconPath;

    qDebug() << "ICON MATCH SCRIPT PATH: " << arguments;
    process->start(pythonExecutable(), arguments);
    qDebug() << "Icon match process started";
}

int PdfProcess::firstMediaPage(const QString &bookDir, const QString &kind)
{
    const bool isVideo = (kind == "video");
    const QString sub = isVideo ? "/video" : "/audio";
    const QStringList exts = isVideo
        ? QStringList{"mp4", "m4v", "mov", "webm"}
        : QStringList{"mp3", "wav", "m4a", "ogg"};
    QDir dir(bookDir + sub);
    if (!dir.exists())
        return -1;

    // page-encoded names: "...Pg-12-...", "Page 10 ...", "Unit2_Pg-7", or
    // bare "4.mp3". The lookbehind (not a letter) lets '_'/'-'/'.'/digit
    // precede the token — \b fails on '_' since it is a word char — while
    // still rejecting the 'p' inside ".mp3"/"mp4".
    QRegularExpression labelled(R"((?<![a-z])p(?:age|g)?[\s_\-]*0*(\d+))",
                                QRegularExpression::CaseInsensitiveOption);
    QRegularExpression bare(R"(^0*(\d+)[a-z]?\.)",
                            QRegularExpression::CaseInsensitiveOption);

    int best = -1;
    const QStringList files = dir.entryList(QDir::Files);
    for (const QString &f : files) {
        const QString lf = f.toLower();
        bool isMedia = false;
        for (const QString &e : exts)
            if (lf.endsWith("." + e)) { isMedia = true; break; }
        if (!isMedia)
            continue;
        int pn = -1;
        QRegularExpressionMatch m = labelled.match(f);
        if (m.hasMatch())
            pn = m.captured(1).toInt();
        else {
            QRegularExpressionMatch mb = bare.match(f);
            if (mb.hasMatch())
                pn = mb.captured(1).toInt();
        }
        if (pn > 0 && (best < 0 || pn < best))
            best = pn;
    }
    return best;
}

QString PdfProcess::logMessages() const
{
    return _logMessages;
}

void PdfProcess::setLogMessages(const QString &newLogMessages)
{
    // Every call is a log event — emit the text as a parameter so a
    // cross-thread (queued) receiver gets this exact line, not a re-read of
    // the property that the worker thread may have already overwritten.
    emit logMessage(newLogMessages);
    if (_logMessages == newLogMessages)
        return;
    _logMessages = newLogMessages;
    emit logMessagesChanged();
}

int PdfProcess::progress() const
{
    return _progress;
}

void PdfProcess::setProgress(int newProgress)
{
    if (_progress == newProgress)
        return;
    _progress = newProgress;
    emit progressChanged();
}

bool PdfProcess::aiAnalyzing() const
{
    return _aiAnalyzing;
}

QStringList PdfProcess::getTestVersions() const {
    QStringList versions;
    

    // Construct the path to the Python script
    QString appDir = QGuiApplication::applicationDirPath();
#ifdef Q_OS_MAC
    appDir += "/../../../";
#else
    appDir += "/../";
#endif
    QDir currentDir(appDir);
    // Check if "test" directory exists
    if (currentDir.cd("test")) {
        // Get all directories in the test folder
        QStringList folders = currentDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        
        // Sort in descending order (highest version first)
        std::sort(folders.begin(), folders.end(), std::greater<QString>());
        
        versions = folders;
    } else {
        qDebug() << "Test directory not found in:" << currentDir.absolutePath();
    }
    
    return versions;
}

void PdfProcess::copyBookToTestVersion(const QString &testVersion, const QString &currentBookName) {
    // Asenkron işlem başlat
    QtConcurrent::run([=]() {
        setProgress(0);
        setLogMessages("Starting to copy book files...");

        // Get application directory
        QString appDir = QGuiApplication::applicationDirPath();
#ifdef Q_OS_MAC
        appDir += "/../../../";
#else
        appDir += "/../";
#endif

        // Source directory (books/XXX)
        QDir sourceDir(appDir + "books/" + currentBookName);
        if (!sourceDir.exists()) {
            setLogMessages("Error: Source book directory not found");
            emit copyCompleted(false);
            return;
        }

        setProgress(15);
        setLogMessages("Checking target directory...");
        
        // Target directory (test/version/data/books)
        QDir targetDir(appDir + "test/" + testVersion + "/books");
        qDebug() <<"sourceDir" << sourceDir<<"  targetDir: " << targetDir << " " <<currentBookName;
        
        // Create target directory if it doesn't exist
        if (!targetDir.exists()) {
            setLogMessages("Creating target directory...");
            if (!targetDir.mkpath(".")) {
                setLogMessages("Error: Failed to create target directory");
                emit copyCompleted(false);
                return;
            }
        }

        setProgress(30);
        
        // Check and remove existing book if it exists
        QString targetBookPath = targetDir.absolutePath() + "/" + currentBookName;
        if (QDir(targetBookPath).exists()) {
            setLogMessages("Found existing book, cleaning up...");
            if (!removeDir(targetBookPath)) {
                setLogMessages("Error: Failed to remove existing book directory");
                emit copyCompleted(false);
                return;
            }
            setLogMessages("Successfully removed existing book");
        }

        setProgress(50);
        setLogMessages("Starting to copy new book files...");

        
        // Copy directory
        if (!copyDir(sourceDir.absolutePath(), targetBookPath)) {
            setLogMessages("Error: Failed to copy book directory");
            emit copyCompleted(false);
            return;
        }

        // Verify the copy was successful
        if (!QDir(targetBookPath).exists()) {
            setLogMessages("Error: Book directory was not copied correctly");
            emit copyCompleted(false);
            return;
        }

        setProgress(100);
        setLogMessages("Successfully copied book files to test version");
        emit copyCompleted(true);
    });
}

// Helper function to recursively remove a directory
bool PdfProcess::removeDir(const QString &dirPath) {
    QDir dir(dirPath);
    if (!dir.exists()) {
        return true;
    }

    bool success = true;
    // Remove all files and subdirectories
    for (const QFileInfo &info : dir.entryInfoList(QDir::NoDotAndDotDot | QDir::System | QDir::Hidden  | QDir::AllDirs | QDir::Files, QDir::DirsFirst)) {
        if (info.isDir()) {
            success = removeDir(info.absoluteFilePath());
        } else {
            success = QFile::remove(info.absoluteFilePath());
        }
        
        if (!success) {
            return false;
        }
    }
    
    return dir.rmdir(dirPath);
}

// Entries that must never end up inside a packaged book: editor/AI work
// artifacts, backups, and OS/app junk. Applied only to the book-data copy
// (not the FlowBook runtime, which may legitimately ship .ini/settings.json).
static bool isExcludedFromPackage(const QString &name, bool isDir) {
    const QString lower = name.toLower();
    // raw/ is excluded wholesale here; the package step copies just the
    // original PDF back as raw/original.pdf, so the answered PDF and other
    // raw artifacts still stay out of the package. .pkgcache is a leftover of
    // the old PDF-optimize cache — never ship it.
    if (isDir)
        return name == "raw" || name == "review" || name == "temp"
            || name == ".pkgcache";
    // macOS / Windows junk
    if (name == ".DS_Store" || name.startsWith("._")
        || lower == "thumbs.db" || lower == "desktop.ini")
        return true;
    // book-processing artifacts
    if (name == "ai_overrides.json" || name == "audit_log.jsonl")
        return true;
    // app / config junk
    if (name == "settings.json" || lower.endsWith(".ini"))
        return true;
    if (name == "fbinf" || lower.endsWith(".fbinf"))
        return true;
    // any backup (config.json.bak, .bak.audit, .bak.safe, ...)
    if (name.contains(".bak"))
        return true;
    return false;
}

// Helper function to recursively copy a directory. When filterBookData is
// true, editor artifacts / backups / OS junk are skipped (see above).
bool PdfProcess::copyDir(const QString &srcPath, const QString &dstPath, bool filterBookData) {
    QDir srcDir(srcPath);
    QDir dstDir(dstPath);

    if (!dstDir.exists()) {
        if (!dstDir.mkpath(".")) {
            return false;
        }
    }

    bool success = true;
    for (const QFileInfo &info : srcDir.entryInfoList(QDir::NoDotAndDotDot | QDir::System | QDir::Hidden  | QDir::AllDirs | QDir::Files, QDir::DirsFirst)) {
        if (filterBookData && isExcludedFromPackage(info.fileName(), info.isDir()))
            continue;

        QString srcItemPath = srcPath + "/" + info.fileName();
        QString dstItemPath = dstPath + "/" + info.fileName();

        if (info.isDir()) {
            success = copyDir(srcItemPath, dstItemPath, filterBookData);
        } else {
            success = QFile::copy(srcItemPath, dstItemPath);
        }

        if (!success) {
            return false;
        }
    }
    return true;
}

static bool pdfNameHas(const QString &name, const QStringList &keys) {
    const QString l = name.toLower();
    for (const QString &k : keys)
        if (l.contains(k))
            return true;
    return false;
}

QString PdfProcess::findOriginalPdf(const QString &rawDir) const {
    QDir d(rawDir);
    const QStringList pdfs = d.entryList(QStringList() << "*.pdf", QDir::Files);
    if (pdfs.isEmpty())
        return QString();
    QStringList rest;                         // drop the answer key(s)
    for (const QString &f : pdfs)
        if (!pdfNameHas(f, {"cevap", "answer", "key"}))
            rest << f;
    if (rest.isEmpty())
        return QString();
    for (const QString &f : rest)             // prefer an explicit original
        if (pdfNameHas(f, {"original", "soru"}))
            return d.filePath(f);
    for (const QString &f : rest)             // else skip obvious covers
        if (!pdfNameHas(f, {"kapak", "cover", "kapag"}))
            return d.filePath(f);
    return d.filePath(rest.first());
}

QString PdfProcess::booksDir() const {
    QString appDir = QGuiApplication::applicationDirPath();
#ifdef Q_OS_MAC
    appDir += "/../../../";
#else
    appDir += "/../";
#endif
    return appDir + "books/";
}

QString PdfProcess::originalPdfStatus(const QString &book) {
    const QString bookDir = booksDir() + book;
    const QString rawDir = bookDir + "/raw";
    const QString cacheDir = bookDir + "/.pkgcache";
    const QString cachePdf = cacheDir + "/original.pdf";
    const QString stampPath = cacheDir + "/stamp.json";
    const QString lockPath = cacheDir + "/lock";

    // Ready: the cache exists and its stamp still matches the source original.
    if (QFileInfo::exists(cachePdf) && QFileInfo::exists(stampPath)) {
        QFile f(stampPath);
        if (f.open(QIODevice::ReadOnly)) {
            const QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
            const QFileInfo si(rawDir + "/" + o.value("src").toString());
            if (si.exists()
                && si.size() == (qint64)o.value("size").toDouble()
                && qAbs(si.lastModified().toSecsSinceEpoch()
                        - (qint64)o.value("mtime").toDouble()) <= 2)
                return QStringLiteral("ready");
        }
    }
    // In progress: a lock file that isn't stale (30 min).
    if (QFileInfo::exists(lockPath)) {
        const QFileInfo li(lockPath);
        if (li.lastModified().secsTo(QDateTime::currentDateTime()) < 30 * 60)
            return QStringLiteral("inprogress");
    }
    // None: raw/ has no PDF at all to keep.
    if (QDir(rawDir).entryList(QStringList() << "*.pdf", QDir::Files).isEmpty())
        return QStringLiteral("none");
    return QStringLiteral("stale");
}

QVariantMap PdfProcess::originalPdfInfo(const QString &book) {
    QVariantMap r;
    const QString status = originalPdfStatus(book);
    r["status"] = status;
    const QString orig = findOriginalPdf(booksDir() + book + "/raw");
    r["original"] = orig.isEmpty() ? (qlonglong)-1 : (qlonglong)QFileInfo(orig).size();
    const QString cachePdf = booksDir() + book + "/.pkgcache/original.pdf";
    r["compressed"] = (status == "ready" && QFileInfo::exists(cachePdf))
                          ? (qlonglong)QFileInfo(cachePdf).size() : (qlonglong)-1;
    return r;
}

void PdfProcess::ensureOriginalCompressed(const QString &book) {
    const QString s = originalPdfStatus(book);
    if (s == "ready" || s == "inprogress" || s == "none")
        return;   // already done / running / nothing to do
    QStringList args;
    args << "-u" << (scriptsDir() + "/compress_pdf.py")
         << "--cache" << (booksDir() + book + "/raw") << "150" << "80";
    // Detached: the (possibly slow) job survives the app closing and finishes
    // writing the cache on its own; status is read back from the filesystem.
    QProcess::startDetached(pythonExecutable(), args);
}

void PdfProcess::optimizeOriginalPdf(const QString &book, bool force) {
    if (force)                 // invalidate the cache so it rebuilds
        QFile::remove(booksDir() + book + "/.pkgcache/stamp.json");
    ensureOriginalCompressed(book);
}

bool PdfProcess::launchTestFlowBook(const QString &testVersion) {
    // Get application directory
    QString appDir = QGuiApplication::applicationDirPath();
#ifdef Q_OS_MAC
    appDir += "/../../../";
#else
    appDir += "/../";
#endif

    // Construct path to FlowBook executable based on platform
    QString flowBookPath;
#ifdef Q_OS_MAC
    flowBookPath = appDir + "test/" + testVersion + "/FlowBook.app";
#else
    flowBookPath = appDir + "test/" + testVersion + "/FlowBook.exe";
#endif

    QDir flowBookDir(QFileInfo(flowBookPath).absolutePath());
    if (!flowBookDir.exists()) {
        qDebug() << "FlowBook directory not found at:" << flowBookDir.absolutePath();
        return false;
    }

    if (!QFileInfo(flowBookPath).exists()) {
        qDebug() << "FlowBook executable not found at:" << flowBookPath;
        return false;
    }

    // Create QProcess for launching FlowBook
    QProcess *process = new QProcess(this);
    
    // Set working directory to FlowBook directory
    process->setWorkingDirectory(flowBookDir.absolutePath());
    
    // Platform specific launch
    QStringList arguments;
    arguments << "/../../";
#ifdef Q_OS_MAC
    arguments << flowBookPath;
    process->start("open", arguments);
#else
    // On Windows, directly execute the .exe

    process->start(flowBookPath, arguments);

    qDebug() << "Arguments" << flowBookPath << process->arguments();;
#endif

    // Connect to error handling
    connect(process, &QProcess::errorOccurred, [this, process](QProcess::ProcessError error) {
        QString errorMessage = "Failed to launch FlowBook: " + process->errorString();
        qDebug() << errorMessage;
        setLogMessages(errorMessage);
        process->deleteLater();
    });

    // Connect to finished signal
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            [this, process](int exitCode, QProcess::ExitStatus exitStatus) {
                if (exitStatus == QProcess::NormalExit && exitCode == 0) {
                    qDebug() << "FlowBook launched successfully";
                } else {
                    qDebug() << "FlowBook process ended with exit code:" << exitCode;
                }
                process->deleteLater();
            });

    return true;
}

QString PdfProcess::getPlatformFolderName(const QString &platform) const {
    if (platform == "windows") return "win";
    if (platform == "windows78") return "win7-8";
    if (platform == "linux") return "linux";
    if (platform == "macos") return "mac";
    return QString();
}

QString PdfProcess::getLatestFlowBookVersion(const QString &platformPath) const {
    QDir dir(platformPath);
    QStringList entries = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    
    // Sort in descending order to get the latest version first
    std::sort(entries.begin(), entries.end(), std::greater<QString>());
    
    return entries.isEmpty() ? QString() : entries.first();
}

bool PdfProcess::package(const QStringList &platforms, const QStringList &bookNames)
{
    setProgress(0);

    // One package may bundle several books (e.g. a paired Student Book +
    // Workbook); they all go under data/books/. The package is named after
    // the joined book names.
    const QString packageName = bookNames.join(" + ");
    qDebug() << "package() bookNames:" << bookNames << "platforms:" << platforms;

    if (bookNames.isEmpty()) {
        setLogMessages("✖  No books selected.");
        return false;
    }
    setLogMessages(QString("📦  Packaging  \"%1\"   (%2 book%3, %4 platform%5)")
                       .arg(packageName)
                       .arg(bookNames.size()).arg(bookNames.size() == 1 ? "" : "s")
                       .arg(platforms.size()).arg(platforms.size() == 1 ? "" : "s"));

    // Get application directory
    QString appDir = QGuiApplication::applicationDirPath();
#ifdef Q_OS_MAC
    appDir += "/../../../";
#else
    appDir += "/../";
#endif

    // Create/Clean release directory for the book
    setProgress(5);
    QString releaseBookPath = appDir + "release/" + packageName;
    QDir releaseDir(releaseBookPath);

    setLogMessages("🧹  Preparing output folder…");
    if (releaseDir.exists()) {
        if (!removeDir(releaseBookPath)) {
            setLogMessages("✖  Could not clean the existing output folder.");
            qDebug() << "Failed to clean release directory:" << releaseBookPath;
            return false;
        }
    }
    if (!releaseDir.mkpath(".")) {
        setLogMessages("✖  Could not create the output folder.");
        qDebug() << "Failed to create release directory:" << releaseBookPath;
        return false;
    }

    // Source book path
    setProgress(10);
    setLogMessages("📚  Verifying books…");
    for (const QString &book : bookNames) {
        if (!QDir(appDir + "books/" + book).exists()) {
            setLogMessages("✖  Book not found: " + book);
            qDebug() << "Source book not found:" << (appDir + "books/" + book);
            return false;
        }
    }

    int totalPlatforms = platforms.length();
    int currentPlatform = 0;
    // Her platform için progress aralığı (10-100 arası)
    int progressPerPlatform = 90 / totalPlatforms; // 90 = 100 - 10 (önceki işlemler)

    // Process each selected platform
    for (const QString &platform : platforms) {
        currentPlatform++;
        QString platformName = platform == "windows" ? "Windows" :
                             platform == "windows78" ? "Windows 7-8" :
                             platform == "linux" ? "Linux" :
                             platform == "macos" ? "macOS" : platform;

        // Platform başlangıç progress'i
        int baseProgress = 10 + (currentPlatform - 1) * progressPerPlatform;
        
        setProgress(baseProgress);
        setLogMessages(QString("▸  %1   (%2/%3)").arg(platformName).arg(currentPlatform).arg(totalPlatforms));

        QString platformFolder = getPlatformFolderName(platform);
        if (platformFolder.isEmpty()) {
            setLogMessages(QString("    ⚠  Skipping unknown platform %1").arg(platformName));
            continue;
        }

        // FlowBook version bulma
        setProgress(baseProgress + progressPerPlatform * 0.2); // %20
        QString packagePath = appDir + "package/" + platformFolder;
        QString flowBookVersion = getLatestFlowBookVersion(packagePath);

        if (flowBookVersion.isEmpty()) {
            setLogMessages(QString("    ✖  No FlowBook build in package/%1").arg(platformFolder));
            qDebug() << "No FlowBook version found for platform:" << platformFolder << "in" << packagePath;
            continue;
        }
        setLogMessages(QString("    %1 · FlowBook %2").arg(platformName, flowBookVersion));

        // Source FlowBook path
        QString sourceFlowBookPath = packagePath + "/" + flowBookVersion;
        
        // Create the new folder name with the package name
        QString targetFolderName = flowBookVersion + " - " + packageName;
        QString targetPath = releaseBookPath + "/" + targetFolderName;

        // FlowBook kopyalama
        setProgress(baseProgress + progressPerPlatform * 0.4); // %40
        setLogMessages(QString("    %1 · copying app…").arg(platformName));
        qDebug() << "sourceFlowBookPath" << sourceFlowBookPath;
        qDebug() << "targetPath" << targetPath;

        if (!copyDir(sourceFlowBookPath, targetPath)) {
            setLogMessages(QString("    ✖  Failed to copy FlowBook for %1").arg(platformName));
            qDebug() << "Failed to copy FlowBook from" << sourceFlowBookPath << "to" << targetPath;
            continue;
        }

        // Book data kopyalama (her seçili kitap data/books/ altına, filtreli)
        setProgress(baseProgress + progressPerPlatform * 0.6); // %60
        setLogMessages(QString("    %1 · adding books…").arg(platformName));
        bool bookCopyOk = true;
        for (const QString &book : bookNames) {
            QString srcBook = appDir + "books/" + book;
            QString dstBook = targetPath + "/data/books/" + book;
            qDebug() << "copying book" << srcBook << "->" << dstBook;
            if (!copyDir(srcBook, dstBook, true)) {
                setLogMessages(QString("    ✖  Failed to add book %1").arg(book));
                qDebug() << "Failed to copy book from" << srcBook << "to" << dstBook;
                bookCopyOk = false;
                break;
            }
            setLogMessages(QString("       + %1").arg(book));
            // raw/ is excluded above; copy the book's original PDF back as
            // raw/original.pdf — the optimized (compressed) cache if the user
            // ran Optimize, otherwise the source original as-is.
            QString srcPdf;
            if (originalPdfStatus(book) == "ready")
                srcPdf = booksDir() + book + "/.pkgcache/original.pdf";
            else
                srcPdf = findOriginalPdf(srcBook + "/raw");
            if (!srcPdf.isEmpty()) {
                const QString dst = dstBook + "/raw/original.pdf";
                QDir().mkpath(dstBook + "/raw");
                QFile::remove(dst);
                if (!QFile::copy(srcPdf, dst))
                    qDebug() << "Failed to copy original.pdf to" << dst;
            }
        }
        if (!bookCopyOk)
            continue;

        // Zip işlemi
        setProgress(baseProgress + progressPerPlatform * 0.8); // %80
        setLogMessages(QString("    %1 · zipping…").arg(platformName));
        QString zipPath = releaseBookPath + "/" + targetFolderName + ".zip";
        if (!zipFolder(targetPath, zipPath)) {
            setLogMessages(QString("    ✖  Failed to zip %1").arg(platformName));
            qDebug() << "Failed to create zip file for:" << targetPath;
            continue;
        }

        // Temizlik
        setProgress(baseProgress + progressPerPlatform * 0.9); // %90
        if (!removeDir(targetPath)) {
            qDebug() << "Warning: Failed to remove temporary folder:" << targetPath;
        }

        // Platform tamamlandı
        setProgress(baseProgress + progressPerPlatform);
        setLogMessages(QString("    ✅  %1 ready").arg(platformName));
    }

    // Tüm işlem tamamlandı
    setProgress(100);
    setLogMessages(QString("✨  Done — \"%1\" is ready in the release folder.").arg(packageName));
    return true;
}

bool PdfProcess::zipFolder(const QString &sourceDir, const QString &zipFilePath) {
    QProcess *process = new QProcess(this);
    QStringList arguments;
    
#ifdef Q_OS_MAC
    // On macOS, use zip command
    arguments << "-r" << zipFilePath << ".";
    process->setWorkingDirectory(sourceDir);
    process->start("zip", arguments);
#else
    // On Windows, you might want to use 7zip or another tool
    // This is a placeholder - implement according to your needs
    QString sevenZipPath = "C:/Program Files/7-Zip/7z.exe";

    // Alternatif 7z.exe yolu
    if (!QFile::exists(sevenZipPath)) {
        sevenZipPath = "C:/Program Files (x86)/7-Zip/7z.exe";
    }

    // 7z.exe bulunamadıysa hata döndür
    if (!QFile::exists(sevenZipPath)) {
        setLogMessages("7-Zip not found. Please install 7-Zip or verify the path.");
        process->deleteLater();
        return false;
    }

    // 7z.exe çalıştır: "7z.exe a -tzip zipFilePath sourceDir/*"
    arguments << "a" << "-tzip" << zipFilePath << sourceDir + "/*";
    process->start(sevenZipPath, arguments);
#endif

    // Generous timeout: packages can be several hundred MB (uncompressed
    // original PDFs), and zipping that on a slow machine takes minutes. The
    // old 60s cap made zipFolder report failure while 7z kept running in the
    // background — so the caller skipped cleanup and the uncompressed folder
    // was left behind next to a zip that finished later.
    if (!process->waitForFinished(60 * 60 * 1000)) {  // 60 min
        qDebug() << "Zip process timed out";
        process->kill();                 // don't leave an orphaned 7z running
        process->waitForFinished(5000);
        process->deleteLater();
        return false;
    }

    bool success = (process->exitCode() == 0);
    process->deleteLater();
    return success;
}

void PdfProcess::copyAdditionalFiles(const QStringList &filePaths)
{
    /*
    QDir dir(destDir);
    if (!dir.exists()) {
        if (!dir.mkpath(".")) {
            qDebug() << "Failed to create destination directory:" << destDir;
            return;
        }
    }

    for (const QString &filePath : filePaths) {
        QFileInfo fileInfo(filePath);
        QString destFile = destDir + "/" + fileInfo.fileName();

        if (QFile::exists(destFile)) {
            // Eğer aynı isimde dosya varsa üzerine yazma
            if (!QFile::remove(destFile)) {
                qDebug() << "Failed to remove existing file:" << destFile;
                continue;
            }
        }

        if (!QFile::copy(filePath, destFile)) {
            qDebug() << "Failed to copy file from" << filePath << "to" << destFile;
        } else {
            qDebug() << "Successfully copied" << fileInfo.fileName() << "to" << destDir;
        }
    }
*/
}

QString PdfProcess::extractScriptError(const QString &output, int exitCode)
{
    // Prefer the script's own "ERROR: ..." line (last one wins, so a real
    // error beats earlier pip noise); fall back to the last output line,
    // then a generic message. Strip the "ERROR:" prefix for a clean toast.
    const QStringList lines = output.split('\n', Qt::SkipEmptyParts);
    QString err;
    for (const QString &raw : lines) {
        const QString t = raw.trimmed();
        if (t.startsWith(QStringLiteral("ERROR"), Qt::CaseInsensitive))
            err = t;
    }
    if (err.isEmpty() && !lines.isEmpty())
        err = lines.last().trimmed();
    if (err.isEmpty())
        err = QStringLiteral("Process failed (exit code %1)").arg(exitCode);
    if (err.startsWith(QStringLiteral("ERROR:"), Qt::CaseInsensitive))
        err = err.mid(6).trimmed();
    return err;
}

void PdfProcess::cropSectionFromPdf(const QString &pdfPath, int pageIndex,
                                     double x, double y, double w, double h,
                                     double pngWidth, double pngHeight,
                                     const QString &outputPath)
{
    qDebug() << "Cropping section from PDF:" << pdfPath << "page:" << pageIndex
             << "rect:" << x << y << w << h << "png:" << pngWidth << pngHeight
             << "output:" << outputPath;

    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("PYTHONIOENCODING", "utf-8");
    process->setProcessEnvironment(env);
    process->setProcessChannelMode(QProcess::MergedChannels);

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            [this, process, outputPath](int exitCode, QProcess::ExitStatus exitStatus) {
                QByteArray remaining = process->readAllStandardOutput();
                QString output = QString::fromUtf8(remaining).trimmed();
                qDebug() << "Crop script output:" << output;

                if (exitStatus == QProcess::NormalExit && exitCode == 0 && output.contains("OK")) {
                    qDebug() << "Crop completed successfully:" << outputPath;
                    emit cropCompleted(true, outputPath);
                } else {
                    qDebug() << "Crop failed with exit code:" << exitCode;
                    emit scriptError(extractScriptError(output, exitCode));
                    emit cropCompleted(false, outputPath);
                }
                process->deleteLater();
            });

    connect(process, &QProcess::errorOccurred, [this, process, outputPath](QProcess::ProcessError error) {
        qDebug() << "Crop process error:" << error << process->errorString();
        emit scriptError(QStringLiteral("Crop could not start: ") + process->errorString());
        emit cropCompleted(false, outputPath);
        process->deleteLater();
    });

    QString scriptPath = scriptsDir() + "/crop_section.py";

    QStringList arguments;
    arguments << "-u" << scriptPath
              << pdfPath
              << QString::number(pageIndex)
              << QString::number(x, 'f', 2)
              << QString::number(y, 'f', 2)
              << QString::number(w, 'f', 2)
              << QString::number(h, 'f', 2)
              << QString::number(pngWidth, 'f', 2)
              << QString::number(pngHeight, 'f', 2)
              << outputPath;

    qDebug() << "CROP SCRIPT ARGS:" << arguments;

    process->start(pythonExecutable(), arguments);
    qDebug() << "Crop process started";
}

void PdfProcess::redetectCircleOptions(const QString &rawDir, int pageNumber,
                                       double x, double y, double w, double h,
                                       double pngWidth, double pngHeight,
                                       const QString &outputPath,
                                       const QString &kind)
{
    qDebug() << "Redetecting" << kind << "options:" << rawDir << "page:" << pageNumber
             << "rect:" << x << y << w << h << "png:" << pngWidth << pngHeight
             << "output:" << outputPath;

    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("PYTHONIOENCODING", "utf-8");
    process->setProcessEnvironment(env);
    process->setProcessChannelMode(QProcess::MergedChannels);

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            [this, process, outputPath](int exitCode, QProcess::ExitStatus exitStatus) {
                QString output = QString::fromUtf8(process->readAllStandardOutput());
                qDebug() << "Redetect script output:" << output;

                // The result is the last line that looks like a JSON object.
                QString json;
                const QStringList lines = output.split('\n', Qt::SkipEmptyParts);
                for (auto it = lines.rbegin(); it != lines.rend(); ++it) {
                    QString t = it->trimmed();
                    if (t.startsWith('{') && t.endsWith('}')) {
                        json = t;
                        break;
                    }
                }

                bool ok = exitStatus == QProcess::NormalExit && exitCode == 0
                          && !json.isEmpty() && !json.contains("\"error\"");
                if (!ok)
                    emit scriptError(extractScriptError(output, exitCode));
                emit circleRedetectCompleted(ok, json, outputPath);
                process->deleteLater();
            });

    connect(process, &QProcess::errorOccurred, [this, process, outputPath](QProcess::ProcessError error) {
        qDebug() << "Redetect process error:" << error << process->errorString();
        emit scriptError(QStringLiteral("Re-detect could not start: ") + process->errorString());
        emit circleRedetectCompleted(false, QString(), outputPath);
        process->deleteLater();
    });

    // matchTheWords has its own detector script; circle/markwithx
    // share proto_circle's --redetect (which takes a kind argument).
    QString scriptPath = scriptsDir() + (kind == "match"
                                   ? "/proto_match.py"
                                   : "/proto_circle.py");

    QStringList arguments;
    arguments << "-u" << scriptPath << "--redetect"
              << rawDir
              << QString::number(pageNumber)
              << QString::number(x, 'f', 2)
              << QString::number(y, 'f', 2)
              << QString::number(w, 'f', 2)
              << QString::number(h, 'f', 2)
              << QString::number(pngWidth, 'f', 2)
              << QString::number(pngHeight, 'f', 2)
              << outputPath;
    if (kind != "match")
        arguments << kind;

    qDebug() << "REDETECT SCRIPT ARGS:" << arguments;
    process->start(pythonExecutable(), arguments);
}

void PdfProcess::detectHeaderText(const QString &rawDir, int pageNumber,
                                  double x, double y, double w, double h,
                                  double pngWidth, double pngHeight)
{
    qDebug() << "Detecting header text:" << rawDir << "page:" << pageNumber
             << "rect:" << x << y << w << h;

    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("PYTHONIOENCODING", "utf-8");
    process->setProcessEnvironment(env);
    process->setProcessChannelMode(QProcess::MergedChannels);

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            [this, process](int exitCode, QProcess::ExitStatus exitStatus) {
                QString output = QString::fromUtf8(process->readAllStandardOutput());
                qDebug() << "Headertext script output:" << output;

                QString text;
                bool ok = false;
                const QStringList lines = output.split('\n', Qt::SkipEmptyParts);
                for (auto it = lines.rbegin(); it != lines.rend(); ++it) {
                    QString t = it->trimmed();
                    if (t.startsWith('{') && t.endsWith('}')) {
                        QJsonDocument doc = QJsonDocument::fromJson(t.toUtf8());
                        if (doc.isObject() && doc.object().contains("headerText")) {
                            text = doc.object().value("headerText").toString();
                            ok = exitStatus == QProcess::NormalExit && exitCode == 0;
                        }
                        break;
                    }
                }
                // Only a real process failure is an error worth a warning —
                // a clean run that simply found no header text is not.
                if (exitStatus != QProcess::NormalExit || exitCode != 0)
                    emit scriptError(extractScriptError(output, exitCode));
                emit headerTextDetected(ok, text);
                process->deleteLater();
            });

    connect(process, &QProcess::errorOccurred, [this, process](QProcess::ProcessError error) {
        qDebug() << "Headertext process error:" << error << process->errorString();
        emit scriptError(QStringLiteral("Header pick could not start: ") + process->errorString());
        emit headerTextDetected(false, QString());
        process->deleteLater();
    });

    QString scriptPath = scriptsDir() + "/proto_circle.py";

    QStringList arguments;
    arguments << "-u" << scriptPath << "--headertext"
              << rawDir
              << QString::number(pageNumber)
              << QString::number(x, 'f', 2)
              << QString::number(y, 'f', 2)
              << QString::number(w, 'f', 2)
              << QString::number(h, 'f', 2)
              << QString::number(pngWidth, 'f', 2)
              << QString::number(pngHeight, 'f', 2);

    process->start(pythonExecutable(), arguments);
}

bool PdfProcess::packageForPlatforms(const QStringList &platforms, const QStringList &bookNames) {
    // Don't allow a second packaging run to start while one is in flight
    // (overlapping threads would interleave their progress/log output).
    if (!_isPackaging.testAndSetOrdered(0, 1)) {
        setLogMessages("⏳  A package is already being built — please wait.");
        return false;
    }
    QThread* thread = QThread::create([=]() {
        this->package(platforms, bookNames);  // sınıf metodu
        _isPackaging.storeRelease(0);
    });
    qDebug() << "stack size " << thread->stackSize();
    connect(thread, &QThread::finished, thread, &QThread::deleteLater);

    //thread->setStackSize(8 * 1024 * 1024);
    thread->start();
    return true;
}
