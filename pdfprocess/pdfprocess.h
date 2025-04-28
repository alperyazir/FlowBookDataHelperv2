
#pragma once

#include <QObject>
#include <QString>


class PdfProcess: public QObject {
    Q_OBJECT
public:
    Q_INVOKABLE void startProcessing(const QString &pdfConfig);
    int _progress;
    QString _logMessages;

    int progress() const;
    void setProgress(int newProgress);
    QString logMessages() const;
    void setLogMessages(const QString &newLogMessages);

signals:
    void progressChanged();
    void logMessagesChanged();

private:
    Q_PROPERTY(int progress READ progress WRITE setProgress NOTIFY progressChanged FINAL)
    Q_PROPERTY(QString logMessages READ logMessages WRITE setLogMessages NOTIFY logMessagesChanged FINAL)
};
