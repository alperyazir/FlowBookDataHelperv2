#ifndef UPDATEMANAGER_H
#define UPDATEMANAGER_H

#include <QObject>
#include <QString>
#include <QProcess>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDir>
#include <QFile>
#include <QStringList>
#include <QVariantList>
#include <QJsonValue>

class UpdateManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY updateAvailableChanged)
    Q_PROPERTY(QString updateMessage READ updateMessage NOTIFY updateMessageChanged)
    Q_PROPERTY(bool updateInProgress READ updateInProgress NOTIFY updateInProgressChanged)
    Q_PROPERTY(QStringList logMessages READ logMessages NOTIFY logMessagesChanged)
    Q_PROPERTY(QVariantList components READ components NOTIFY componentsChanged)

public:
    explicit UpdateManager(QObject *parent = nullptr);
    
    bool updateAvailable() const;
    QString updateMessage() const;
    bool updateInProgress() const;
    QStringList logMessages() const;
    QVariantList components() const;

public slots:
    void checkForUpdates();
    void applyUpdates();
    void restartApplication();
    void clearLogs();
    void loadConfiguration();

signals:
    void updateAvailableChanged();
    void updateMessageChanged();
    void updateInProgressChanged();
    void logMessagesChanged();
    void componentsChanged();
    void updateCompleted(bool success, QString message);
    void restartRequired();
    void newLogMessage(QString message);

private slots:
    void handleCheckFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void handleUpdateFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void handleProcessError(QProcess::ProcessError error);
    void readProcessOutput();
    void readProcessError();

private:
    QProcess *m_process;
    bool m_updateAvailable;
    QString m_updateMessage;
    bool m_updateInProgress;
    QString m_pythonPath;
    QString m_scriptPath;
    QStringList m_logMessages;
    QVariantList m_components;
    QJsonObject m_localConfig;
    QJsonObject m_remoteConfig;
    
    void setupPaths();
    QString getPythonExecutablePath() const;
    QString getConfigPath() const;
    QString getTempConfigPath() const;
    void readConfig(const QString &path, QJsonObject &config);
    void addLogMessage(const QString &message);
    bool compareVersions(const QString &localVersion, const QString &remoteVersion);
    void analyzeComponents();
};

#endif // UPDATEMANAGER_H 