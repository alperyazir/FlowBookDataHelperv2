#include "pdfprocess.h"
#include <QDebug>
#include <QProcess>
#include <QTemporaryFile>
#include <QDir>
#include <QTextStream>
#include <QFile>
#include <QGuiApplication>
#include <algorithm>
#include <QtConcurrent>

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

    // Construct the path to the Python script
    QString appDir = QGuiApplication::applicationDirPath();
#ifdef Q_OS_MAC
    appDir += "/../../..";
#else
    appDir += "/";
#endif
    QString scriptPath = appDir + "/scripts/smartdatahelper.py";



    // Set up the process arguments
    QStringList arguments;
    arguments << "-u" << scriptPath << tempPath;

     qDebug() << "SCRIPT PATH: " << arguments;

    // Start the process with python3 command
    process->start("/Library/Frameworks/Python.framework/Versions/3.12/bin/python3", arguments);

    // Don't wait here - the process will emit signals as it proceeds
    qDebug() << "Python process started";
}

void PdfProcess::startAIAnalysis(const QString &configPath, const QString &settingsPath)
{
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
        emit aiAnalysisCompleted(false);
        process->deleteLater();
    });

    // Construct the path to the Python script
    QString appDir = QGuiApplication::applicationDirPath();
#ifdef Q_OS_MAC
    appDir += "/../../..";
#else
    appDir += "/";
#endif
    QString scriptPath = appDir + "/scripts/ai_analyzer.py";

    // Set up the process arguments
    QStringList arguments;
    arguments << "-u" << scriptPath << configPath << settingsPath;

    qDebug() << "AI ANALYZER SCRIPT PATH: " << arguments;

    // Start the process
    process->start("/Library/Frameworks/Python.framework/Versions/3.12/bin/python3", arguments);

    qDebug() << "AI Analyzer process started";
}

QString PdfProcess::logMessages() const
{
    return _logMessages;
}

void PdfProcess::setLogMessages(const QString &newLogMessages)
{
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

// Helper function to recursively copy a directory
bool PdfProcess::copyDir(const QString &srcPath, const QString &dstPath) {
    QDir srcDir(srcPath);
    QDir dstDir(dstPath);

    if (srcPath.endsWith("raw"))  return true;
    if (!dstDir.exists()) {
        if (!dstDir.mkpath(".")) {
            return false;
        }
    }

    bool success = true;
    for (const QFileInfo &info : srcDir.entryInfoList(QDir::NoDotAndDotDot | QDir::System | QDir::Hidden  | QDir::AllDirs | QDir::Files, QDir::DirsFirst)) {
        QString srcItemPath = srcPath + "/" + info.fileName();
        QString dstItemPath = dstPath + "/" + info.fileName();
        
        if (info.isDir()) {
            success = copyDir(srcItemPath, dstItemPath);
        } else {
            success = QFile::copy(srcItemPath, dstItemPath);
        }

        if (!success) {
            return false;
        }
    }
    return true;
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

bool PdfProcess::package(const QStringList &platforms, const QString &currentBookName)
{
    setProgress(0);
    setLogMessages("1/7 - Starting packaging process...");

    // Get application directory
    QString appDir = QGuiApplication::applicationDirPath();
#ifdef Q_OS_MAC
    appDir += "/../../../";
#else
    appDir += "/../";
#endif

    // Create/Clean release directory for the book
    setProgress(5);
    QString releaseBookPath = appDir + "release/" + currentBookName;
    QDir releaseDir(releaseBookPath);

    if (releaseDir.exists()) {
        setLogMessages("2/7 - Cleaning existing release directory...");
        if (!removeDir(releaseBookPath)) {
            setLogMessages("Error: Failed to clean existing release directory");
            qDebug() << "Failed to clean release directory:" << releaseBookPath;
            return false;
        }
    }

    setLogMessages("2/7 - Creating fresh release directory...");
    if (!releaseDir.mkpath(".")) {
        setLogMessages("Error: Failed to create release directory");
        qDebug() << "Failed to create release directory:" << releaseBookPath;
        return false;
    }

    // Source book path
    setProgress(10);
    setLogMessages("3/7 - Checking source book...");
    QString sourceBookPath = appDir + "books/" + currentBookName;
    if (!QDir(sourceBookPath).exists()) {
        setLogMessages("Error: Source book not found");
        qDebug() << "Source book not found:" << sourceBookPath;
        return false;
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
        setLogMessages(QString("4/7 - Processing platform %1 of %2: %3").arg(currentPlatform).arg(totalPlatforms).arg(platformName));
        
        QString platformFolder = getPlatformFolderName(platform);
        if (platformFolder.isEmpty()) {
            setLogMessages(QString("Warning: Skipping unknown platform %1").arg(platformName));
            continue;
        }

        // FlowBook version bulma
        setProgress(baseProgress + progressPerPlatform * 0.2); // %20
        setLogMessages(QString("5/7 - Finding FlowBook version for %1...").arg(platformName));
        QString packagePath = appDir + "package/" + platformFolder;
        QString flowBookVersion = getLatestFlowBookVersion(packagePath);
        
        if (flowBookVersion.isEmpty()) {
            setLogMessages(QString("Error: No FlowBook version found for %1").arg(platformName));
            qDebug() << "No FlowBook version found for platform:" << platformFolder;
            continue;
        }

        // Source FlowBook path
        QString sourceFlowBookPath = packagePath + "/" + flowBookVersion;
        
        // Create the new folder name with book name
        QString targetFolderName = flowBookVersion + " - " + currentBookName;
        QString targetPath = releaseBookPath + "/" + targetFolderName;

        // FlowBook kopyalama
        setProgress(baseProgress + progressPerPlatform * 0.4); // %40
        setLogMessages(QString("6/7 - Copying FlowBook for %1...").arg(platformName));
        qDebug() << "sourceFlowBookPath" << sourceFlowBookPath;
        qDebug() << "targetPath" << targetPath;

        if (!copyDir(sourceFlowBookPath, targetPath)) {
            setLogMessages(QString("Error: Failed to copy FlowBook for %1").arg(platformName));
            qDebug() << "Failed to copy FlowBook from" << sourceFlowBookPath << "to" << targetPath;
            continue;
        }

        // Book data kopyalama
        setProgress(baseProgress + progressPerPlatform * 0.6); // %60
        setLogMessages(QString("6/7 - Copying book data for %1...").arg(platformName));
        QString targetBookPath = targetPath + "/data/books/" + currentBookName;
        if (!copyDir(sourceBookPath, targetBookPath)) {
            setLogMessages(QString("Error: Failed to copy book data for %1").arg(platformName));
            qDebug() << "Failed to copy book from" << sourceBookPath << "to" << targetBookPath;
            continue;
        }

        // Zip işlemiq
        setProgress(baseProgress + progressPerPlatform * 0.8); // %80
        setLogMessages(QString("7/7 - Creating zip file for %1...").arg(platformName));
        QString zipPath = releaseBookPath + "/" + targetFolderName + ".zip";
        if (!zipFolder(targetPath, zipPath)) {
            setLogMessages(QString("Error: Failed to create zip file for %1").arg(platformName));
            qDebug() << "Failed to create zip file for:" << targetPath;
            continue;
        }

        // Temizlik
        setProgress(baseProgress + progressPerPlatform * 0.9); // %90
        if (!removeDir(targetPath)) {
            setLogMessages(QString("Warning: Failed to remove temporary folder for %1").arg(platformName));
            qDebug() << "Warning: Failed to remove temporary folder:" << targetPath;
        }

        // Platform tamamlandı
        setProgress(baseProgress + progressPerPlatform);
        setLogMessages(QString("✅ Completed packaging for %1").arg(platformName));
    }

    // Tüm işlem tamamlandı
    setProgress(100);
    setLogMessages("✨ Packaging process completed!");
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

    if (!process->waitForFinished(60000)) { // 30 second timeout
        qDebug() << "Zip process timed out";
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

    QString capturedOutput;

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            [this, process, outputPath, &capturedOutput](int exitCode, QProcess::ExitStatus exitStatus) {
                QByteArray remaining = process->readAllStandardOutput();
                QString output = QString::fromUtf8(remaining).trimmed();
                qDebug() << "Crop script output:" << output;

                if (exitStatus == QProcess::NormalExit && exitCode == 0 && output.contains("OK")) {
                    qDebug() << "Crop completed successfully:" << outputPath;
                    emit cropCompleted(true, outputPath);
                } else {
                    qDebug() << "Crop failed with exit code:" << exitCode;
                    emit cropCompleted(false, outputPath);
                }
                process->deleteLater();
            });

    connect(process, &QProcess::errorOccurred, [this, process, outputPath](QProcess::ProcessError error) {
        qDebug() << "Crop process error:" << error << process->errorString();
        emit cropCompleted(false, outputPath);
        process->deleteLater();
    });

    QString appDir = QGuiApplication::applicationDirPath();
#ifdef Q_OS_MAC
    appDir += "/../../..";
#else
    appDir += "/";
#endif
    QString scriptPath = appDir + "/scripts/crop_section.py";

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

    process->start("/Library/Frameworks/Python.framework/Versions/3.12/bin/python3", arguments);
    qDebug() << "Crop process started";
}

bool PdfProcess::packageForPlatforms(const QStringList &platforms, const QString &currentBookName) {
    //QtConcurrent::run(this, &PdfProcess::package,platforms, currentBookName);

    QThread* thread = QThread::create([=]() {
        this->package(platforms, currentBookName);  // sınıf metodu
    });
    qDebug() << "stack size " << thread->stackSize();
    connect(thread, &QThread::finished, thread, &QThread::deleteLater);

    //thread->setStackSize(8 * 1024 * 1024);
    thread->start();
    return true;
}
