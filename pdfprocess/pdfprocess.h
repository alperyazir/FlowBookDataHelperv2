#pragma once

#include <QObject>
#include <QString>
#include <QStringList>


class PdfProcess: public QObject {
    Q_OBJECT
public:
    Q_INVOKABLE void startProcessing(const QString &pdfConfig);
    Q_INVOKABLE void startAIAnalysis(const QString &configPath, const QString &settingsPath);
    Q_INVOKABLE QStringList getTestVersions() const;
    Q_INVOKABLE void copyBookToTestVersion(const QString &testVersion, const QString &currentBookName);
    Q_INVOKABLE bool launchTestFlowBook(const QString &testVersion);
    Q_INVOKABLE bool packageForPlatforms(const QStringList &platforms, const QString &currentBookName);
    Q_INVOKABLE void copyAdditionalFiles(const QStringList &filePaths);
    Q_INVOKABLE void cropSectionFromPdf(const QString &pdfPath, int pageIndex,
                                         double x, double y, double w, double h,
                                         double pngWidth, double pngHeight,
                                         const QString &outputPath);

    int _progress;
    QString _logMessages;

    int progress() const;
    void setProgress(int newProgress);
    QString logMessages() const;
    void setLogMessages(const QString &newLogMessages);
    bool removeDir(const QString &dirPath);
    bool copyDir(const QString &srcPath, const QString &dstPath);
    bool zipFolder(const QString &sourceDir, const QString &zipFilePath);

signals:
    void progressChanged();
    void logMessagesChanged();
    void copyCompleted(bool success);
    void aiAnalysisCompleted(bool success);
    void cropCompleted(bool success, const QString &outputPath);

private:
    Q_PROPERTY(int progress READ progress WRITE setProgress NOTIFY progressChanged FINAL)
    Q_PROPERTY(QString logMessages READ logMessages WRITE setLogMessages NOTIFY logMessagesChanged FINAL)
    
    QString getPlatformFolderName(const QString &platform) const;
    QString getLatestFlowBookVersion(const QString &platformPath) const;

    bool package(const QStringList &platforms, const QString &currentBookName);

};
