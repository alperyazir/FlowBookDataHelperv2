#pragma once

#include <QObject>
#include <QString>
#include <QStringList>


class PdfProcess: public QObject {
    Q_OBJECT
public:
    Q_INVOKABLE void startProcessing(const QString &pdfConfig);
    Q_INVOKABLE void startAIAnalysis(const QString &configPath, const QString &settingsPath);
    // Locate audio/video icons by template-matching user-supplied crops
    // (scripts/proto_icon_match.py) and write the sections into config.json.
    // Either icon path may be empty. Reuses the aiAnalysisCompleted signal so
    // the editor reloads config the same way it does after Analyze.
    Q_INVOKABLE void matchIcons(const QString &configPath,
                                const QString &audioIconPath,
                                const QString &videoIconPath);
    // Lowest page number among the book's audio/video files (page-encoded
    // names like "...Pg-12-..." or "4.mp3"); -1 if none. Used to jump to a
    // media page before cropping an icon template.
    Q_INVOKABLE int firstMediaPage(const QString &bookDir, const QString &kind);
    Q_INVOKABLE QStringList getTestVersions() const;
    Q_INVOKABLE void copyBookToTestVersion(const QString &testVersion, const QString &currentBookName);
    Q_INVOKABLE bool launchTestFlowBook(const QString &testVersion);
    Q_INVOKABLE bool packageForPlatforms(const QStringList &platforms, const QStringList &bookNames);
    Q_INVOKABLE void copyAdditionalFiles(const QStringList &filePaths);
    Q_INVOKABLE void cropSectionFromPdf(const QString &pdfPath, int pageIndex,
                                         double x, double y, double w, double h,
                                         double pngWidth, double pngHeight,
                                         const QString &outputPath);
    Q_INVOKABLE void redetectCircleOptions(const QString &rawDir, int pageNumber,
                                           double x, double y, double w, double h,
                                           double pngWidth, double pngHeight,
                                           const QString &outputPath,
                                           const QString &kind = "circle");
    Q_INVOKABLE void detectHeaderText(const QString &rawDir, int pageNumber,
                                      double x, double y, double w, double h,
                                      double pngWidth, double pngHeight);

    int _progress;
    QString _logMessages;
    bool _aiAnalyzing = false;

    int progress() const;
    void setProgress(int newProgress);
    bool aiAnalyzing() const;
    QString logMessages() const;
    void setLogMessages(const QString &newLogMessages);
    bool removeDir(const QString &dirPath);
    bool copyDir(const QString &srcPath, const QString &dstPath, bool filterBookData = false);
    bool zipFolder(const QString &sourceDir, const QString &zipFilePath);

signals:
    void progressChanged();
    void logMessagesChanged();
    // Carries the exact log line as a parameter. setLogMessages() is often
    // called from the packaging worker thread, so a slot that re-reads the
    // logMessages property races the writer and sees the latest value N times
    // (duplicate lines, lost lines). Connect to THIS for logging instead.
    void logMessage(const QString &message);
    void aiAnalyzingChanged();
    void copyCompleted(bool success);
    void aiAnalysisCompleted(bool success);
    void cropCompleted(bool success, const QString &outputPath);
    void circleRedetectCompleted(bool success, const QString &resultJson,
                                 const QString &outputPath);
    void headerTextDetected(bool success, const QString &text);
    // A Python helper script failed — carries a short, user-readable reason
    // (the script's "ERROR: ..." line) for the editor to show as a warning.
    void scriptError(const QString &message);

private:
    Q_PROPERTY(int progress READ progress WRITE setProgress NOTIFY progressChanged FINAL)
    Q_PROPERTY(QString logMessages READ logMessages WRITE setLogMessages NOTIFY logMessagesChanged FINAL)
    Q_PROPERTY(bool aiAnalyzing READ aiAnalyzing NOTIFY aiAnalyzingChanged FINAL)
    
    QString getPlatformFolderName(const QString &platform) const;
    QString getLatestFlowBookVersion(const QString &platformPath) const;
    static QString pythonExecutable();
    // Pull a short, user-readable reason out of a failed script's merged
    // stdout/stderr (prefers its "ERROR: ..." line).
    static QString extractScriptError(const QString &output, int exitCode);
    // Python scripts ship inside the binary (scripts.qrc) and are
    // extracted to a writable dir once per run; returns that dir.
    static QString scriptsDir();

    bool package(const QStringList &platforms, const QStringList &bookNames);
    // The original (non-answered) PDF in a book's raw/ dir, or "" if none.
    // Prefers an 'original'/'soru' name, skips answer keys and obvious covers.
    QString findOriginalPdf(const QString &rawDir) const;

    QAtomicInt _isPackaging = 0;   // guards against overlapping package runs

};
