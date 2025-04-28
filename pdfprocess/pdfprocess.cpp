#include "pdfprocess.h"
#include <QDebug>
#include <QProcess>
#include <QTemporaryFile>
#include <QDir>
#include <QTextStream>
#include <QFile>
#include <QGuiApplication>

void PdfProcess::startProcessing(const QString &pdfConfig)
{
    qDebug() << "Starting PDF processing with config:" << pdfConfig;
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
    out << pdfConfig;
    out.flush();

    // Keep the temp file open but detach it so it doesn't get deleted when tempFile goes out of scope
    QString tempPath = tempFile.fileName();
    tempFile.setAutoRemove(false);
    tempFile.close();

    // Setup the process to run the Python script
    QProcess *process = new QProcess(this);
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
    appDir += "/../../../";
#else
    appDir += "/";
#endif
    QString scriptPath = appDir + "/scripts/smartdatahelper.py";

    // Set up the process arguments
    QStringList arguments;
    arguments << "-u" << scriptPath << tempPath;

    // Start the process with python3 command
    process->start("python3", arguments);

    // Don't wait here - the process will emit signals as it proceeds
    qDebug() << "Python process started";
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
