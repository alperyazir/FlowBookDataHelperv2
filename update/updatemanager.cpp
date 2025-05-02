#include "updatemanager.h"
#include <QCoreApplication>
#include <QStandardPaths>
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDir>
#include <QTimer>

UpdateManager::UpdateManager(QObject *parent)
    : QObject(parent),
      m_updateAvailable(false),
      m_updateMessage(""),
      m_updateInProgress(false)
{
    m_process = new QProcess(this);
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), 
            this, &UpdateManager::handleCheckFinished);
    connect(m_process, &QProcess::errorOccurred, this, &UpdateManager::handleProcessError);
    connect(m_process, &QProcess::readyReadStandardOutput, this, &UpdateManager::readProcessOutput);
    connect(m_process, &QProcess::readyReadStandardError, this, &UpdateManager::readProcessError);
    
    setupPaths();
    
    // Load configuration when application starts
    loadConfiguration();
}

bool UpdateManager::updateAvailable() const
{
    return m_updateAvailable;
}

QString UpdateManager::updateMessage() const
{
    return m_updateMessage;
}

bool UpdateManager::updateInProgress() const
{
    return m_updateInProgress;
}

QStringList UpdateManager::logMessages() const
{
    return m_logMessages;
}

QVariantList UpdateManager::components() const
{
    return m_components;
}

void UpdateManager::setupPaths()
{
    m_pythonPath = getPythonExecutablePath();
    
    // Script path
    QString appDir = QCoreApplication::applicationDirPath();

#ifdef Q_OS_MAC
    appDir += "/../../..";
#else
    appDir += "/";
#endif
    
    m_scriptPath = appDir + "/scripts/update_manager.py";
    
    qDebug() << "Python path:" << m_pythonPath;
    qDebug() << "Script path:" << m_scriptPath;
}

QString UpdateManager::getPythonExecutablePath() const
{
    // First try to search for Python in system path
    QString pythonPath = "python3";
    
    // Different default path for Windows
    #ifdef Q_OS_WIN
    QStringList possiblePaths = {
        "C:/Python39/python.exe",
        "C:/Python38/python.exe",
        "C:/Python37/python.exe",
        "C:/Python310/python.exe",
        "C:/Python311/python.exe",
        "C:/Program Files/Python39/python.exe",
        "C:/Program Files/Python38/python.exe",
        "C:/Program Files/Python37/python.exe",
        "C:/Program Files/Python310/python.exe",
        "C:/Program Files/Python311/python.exe"
    };
    
    for (const QString &path : possiblePaths) {
        if (QFile::exists(path)) {
            pythonPath = path;
            break;
        }
    }
    
    // If still not found, try "python"
    if (!QFile::exists(pythonPath)) {
        pythonPath = "python";
    }
    #endif
    
    return pythonPath;
}

void UpdateManager::loadConfiguration()
{
    m_components.clear();
    
    // Read local configuration
    QString configPath = getConfigPath();
    readConfig(configPath, m_localConfig);
    
    if (m_localConfig.isEmpty()) {
        addLogMessage("Could not read local configuration file: " + configPath);
        return;
    }
    
    // Load temporary remote config if it exists
    QString appDir = QCoreApplication::applicationDirPath();
    QStringList possiblePaths = {
        appDir + "/temp_config.json",
        QCoreApplication::applicationDirPath() + "/../../temp_config.json",
        QCoreApplication::applicationDirPath() + "/../../../temp_config.json",
        QDir::currentPath() + "/temp_config.json"
    };
    
    bool foundRemoteConfig = false;
    for (const QString &path : possiblePaths) {
        if (QFile::exists(path)) {
            addLogMessage("Found remote configuration at: " + path);
            readConfig(path, m_remoteConfig);
            foundRemoteConfig = true;
            break;
        }
    }
    
    if (!foundRemoteConfig) {
        addLogMessage("Could not find any remote configuration file. Checking for updates might not work correctly.");
    }
    
    // Analyze components and send to QML
    analyzeComponents();
}

QString UpdateManager::getConfigPath() const
{
    QString appDir = QCoreApplication::applicationDirPath();
    
#ifdef Q_OS_MAC
    appDir += "/../../..";
#else
    appDir += "/";
#endif
    
    return appDir + "/configuration.json";
}

void UpdateManager::readConfig(const QString &path, QJsonObject &config)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        addLogMessage("Could not open configuration file: " + path);
        return;
    }
    
    QByteArray data = file.readAll();
    file.close();
    
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (doc.isNull() || !doc.isObject()) {
        addLogMessage("Configuration file is not a valid JSON: " + path);
        return;
    }
    
    config = doc.object();
}

void UpdateManager::analyzeComponents()
{
    QVariantList components;
    
    // Main application info
    if (m_localConfig.contains("application")) {
        QJsonObject appObj = m_localConfig["application"].toObject();
        
        QVariantMap app;
        app["name"] = appObj["name"].toString();
        app["version"] = appObj["version"].toString();
        app["releaseNotes"] = appObj["releaseNotes"].toString();
        app["downloadUrl"] = appObj["downloadUrl"].toString();
        app["hasUpdate"] = false;
        
        // If remote config exists, check for updates for the main app
        if (!m_remoteConfig.isEmpty() && m_remoteConfig.contains("application")) {
            QJsonObject remoteAppObj = m_remoteConfig["application"].toObject();
            QString remoteVersion = remoteAppObj["version"].toString();
            
            if (compareVersions(appObj["version"].toString(), remoteVersion)) {
                app["hasUpdate"] = true;
                app["newVersion"] = remoteVersion;
                app["newReleaseNotes"] = remoteAppObj["releaseNotes"].toString();
            }
        }
        
        components.append(app);
    }
    
    // Components
    if (m_localConfig.contains("components") && m_localConfig["components"].isArray()) {
        QJsonArray comps = m_localConfig["components"].toArray();
        
        for (const QJsonValue &value : comps) {
            if (value.isObject()) {
                QJsonObject compObj = value.toObject();
                
                QVariantMap comp;
                comp["name"] = compObj["name"].toString();
                comp["version"] = compObj["version"].toString();
                comp["releaseNotes"] = compObj["releaseNotes"].toString();
                comp["downloadUrl"] = compObj["downloadUrl"].toString();
                comp["fileName"] = compObj["fileName"].toString();
                comp["targetPath"] = compObj["targetPath"].toString();
                comp["hasUpdate"] = false;
                
                // If remote config exists, check if this component has updates
                if (!m_remoteConfig.isEmpty() && m_remoteConfig.contains("components")) {
                    QJsonArray remoteComps = m_remoteConfig["components"].toArray();
                    
                    for (const QJsonValue &remoteValue : remoteComps) {
                        if (remoteValue.isObject()) {
                            QJsonObject remoteCompObj = remoteValue.toObject();
                            
                            if (remoteCompObj["name"].toString() == compObj["name"].toString()) {
                                QString remoteVersion = remoteCompObj["version"].toString();
                                
                                if (compareVersions(compObj["version"].toString(), remoteVersion)) {
                                    comp["hasUpdate"] = true;
                                    comp["newVersion"] = remoteVersion;
                                    comp["newReleaseNotes"] = remoteCompObj["releaseNotes"].toString();
                                }
                                break;
                            }
                        }
                    }
                }
                
                components.append(comp);
            }
        }
    }
    
    m_components = components;
    emit componentsChanged();

    // Check if any component has an update
    bool hasUpdates = false;
    for (const QVariant &component : m_components) {
        QVariantMap comp = component.toMap();
        if (comp["hasUpdate"].toBool()) {
            hasUpdates = true;
            break;
        }
    }
    
    if (hasUpdates && !m_updateAvailable) {
        m_updateAvailable = true;
        m_updateMessage = "Updates available for components.";
        emit updateAvailableChanged();
        emit updateMessageChanged();
        addLogMessage("Updates available for components.");
    }
}

bool UpdateManager::compareVersions(const QString &localVersion, const QString &remoteVersion)
{
    // If versions are the same, no update needed
    if (localVersion == remoteVersion) {
        return false;
    }
    
    // Simple version comparison
    QStringList localParts = localVersion.split('.');
    QStringList remoteParts = remoteVersion.split('.');
    
    int minSize = qMin(localParts.size(), remoteParts.size());
    
    for (int i = 0; i < minSize; ++i) {
        int localPart = localParts[i].toInt();
        int remotePart = remoteParts[i].toInt();
        
        if (remotePart > localPart) {
            // Remote version is higher, update needed
            return true;
        } else if (remotePart < localPart) {
            // Local version is higher, no update needed
            return false;
        }
    }
    
    // If we're here, the common parts are the same
    // The version with more parts is considered higher
    return remoteParts.size() > localParts.size();
}

void UpdateManager::checkForUpdates()
{
    if (m_updateInProgress) {
        qWarning() << "Update check already in progress";
        addLogMessage("Update check already in progress.");
        return;
    }
    
    // Clear status before starting the process
    m_updateAvailable = false;
    m_updateMessage = "";
    emit updateAvailableChanged();
    emit updateMessageChanged();
    
    m_updateInProgress = true;
    emit updateInProgressChanged();
    
    addLogMessage("Starting update check...");
    qDebug() << "Starting update check...";
    
    // Run Python script with "check" parameter to only check for updates without applying them
    m_process->start(m_pythonPath, QStringList() << m_scriptPath << "check");
}

void UpdateManager::applyUpdates()
{
    if (m_updateInProgress) {
        qWarning() << "Update already in progress";
        addLogMessage("Update already in progress.");
        return;
    }
    
    m_updateInProgress = true;
    emit updateInProgressChanged();
    
    addLogMessage("Applying updates...");
    qDebug() << "Applying updates...";
    
    // Start the update process
    m_process->start(m_pythonPath, QStringList() << m_scriptPath << "apply");
    
    // Change process connection
    disconnect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), 
               this, &UpdateManager::handleCheckFinished);
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), 
            this, &UpdateManager::handleUpdateFinished);
}

void UpdateManager::restartApplication()
{
    addLogMessage("Restarting application...");
    qDebug() << "Restarting application...";
    QCoreApplication::quit();
    QProcess::startDetached(QCoreApplication::applicationFilePath(), QStringList());
}

void UpdateManager::clearLogs()
{
    m_logMessages.clear();
    emit logMessagesChanged();
}

void UpdateManager::handleCheckFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    if (exitStatus == QProcess::NormalExit) {
        qDebug() << "Update check finished with exit code:" << exitCode;
        addLogMessage(QString("Update check completed. Exit code: %1").arg(exitCode));
        
        // Reload local configuration
        QString configPath = getConfigPath();
        readConfig(configPath, m_localConfig);
        
        // Read temporary configuration file (remote config)
        QString appDir = QCoreApplication::applicationDirPath();
        QStringList possiblePaths = {
            appDir + "/temp_config.json",
            QCoreApplication::applicationDirPath() + "/../../temp_config.json",
            QCoreApplication::applicationDirPath() + "/../../../temp_config.json",
            QDir::currentPath() + "/temp_config.json"
        };
        
        bool foundRemoteConfig = false;
        for (const QString &path : possiblePaths) {
            if (QFile::exists(path)) {
                addLogMessage("Found remote configuration at: " + path);
                readConfig(path, m_remoteConfig);
                foundRemoteConfig = true;
                break;
            }
        }
        
        if (!foundRemoteConfig) {
            addLogMessage("Could not find any remote configuration file after check.");
        }
        
        // Analyze components
        analyzeComponents();
        
        if (exitCode == 10) {
            // Update requires restart
            m_updateAvailable = true;
            m_updateMessage = "Update available. Application restart will be required.";
            emit updateAvailableChanged();
            emit updateMessageChanged();
            addLogMessage("Update available requiring restart.");
        } 
        else if (exitCode == 0) {
            // No update or successfully applied
            
            // Check if any updates are available
            bool hasUpdates = false;
            for (const QVariant &component : m_components) {
                QVariantMap comp = component.toMap();
                if (comp["hasUpdate"].toBool()) {
                    hasUpdates = true;
                    break;
                }
            }
            
            if (hasUpdates) {
                m_updateAvailable = true;
                m_updateMessage = "Updates available.";
                emit updateAvailableChanged();
                emit updateMessageChanged();
                addLogMessage("Updates available.");
            } else {
                m_updateAvailable = false;
                m_updateMessage = "System is up to date.";
                emit updateAvailableChanged();
                emit updateMessageChanged();
                addLogMessage("System is up to date.");
            }
        } 
        else {
            // Error
            m_updateAvailable = false;
            m_updateMessage = "An error occurred during update check.";
            emit updateAvailableChanged();
            emit updateMessageChanged();
            addLogMessage("An error occurred during update check.");
        }
    } 
    else {
        qWarning() << "Update check process crashed";
        m_updateMessage = "Update check failed.";
        emit updateMessageChanged();
        addLogMessage("Update check process crashed.");
    }
    
    m_updateInProgress = false;
    emit updateInProgressChanged();
    
    // Reset process connection
    disconnect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), 
               this, &UpdateManager::handleUpdateFinished);
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), 
            this, &UpdateManager::handleCheckFinished);
}

void UpdateManager::handleUpdateFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    bool success = false;
    QString message;
    bool needsRestart = false;
    
    if (exitStatus == QProcess::NormalExit) {
        qDebug() << "Update process finished with exit code:" << exitCode;
        addLogMessage(QString("Update process completed. Exit code: %1").arg(exitCode));
        
        // Reload local configuration
        loadConfiguration();
        
        if (exitCode == 10) {
            // Restart required
            message = "Update successful. Restart required.";
            success = true;
            needsRestart = true;
            addLogMessage("Restart required.");
        } 
        else if (exitCode == 0) {
            // Successful update
            message = "Update completed successfully.";
            success = true;
            addLogMessage("Update completed successfully.");
        } 
        else {
            // Error
            message = "An error occurred during update.";
            addLogMessage("An error occurred during update.");
        }
    } 
    else {
        qWarning() << "Update process crashed";
        message = "Update process failed.";
        addLogMessage("Update process crashed.");
    }
    
    m_updateInProgress = false;
    emit updateInProgressChanged();
    
    m_updateMessage = message;
    emit updateMessageChanged();
    
    emit updateCompleted(success, message);
    
    // Reset process connection
    disconnect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), 
               this, &UpdateManager::handleUpdateFinished);
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), 
            this, &UpdateManager::handleCheckFinished);
    
    // If restart is needed, automatically restart the application after a short delay
    if (needsRestart) {
        QTimer::singleShot(3000, this, &UpdateManager::restartApplication);
    }
}

void UpdateManager::handleProcessError(QProcess::ProcessError error)
{
    qWarning() << "Process error occurred:" << error;
    
    QString errorMessage;
    if (error == QProcess::FailedToStart) {
        errorMessage = "Could not start update check. Python or script not found.";
    } else {
        errorMessage = "An error occurred during the update process.";
    }
    
    m_updateMessage = errorMessage;
    emit updateMessageChanged();
    addLogMessage(errorMessage);
    
    m_updateInProgress = false;
    emit updateInProgressChanged();
}

void UpdateManager::readProcessOutput()
{
    QByteArray output = m_process->readAllStandardOutput();
    QString outputStr = QString::fromUtf8(output).trimmed();
    
    if (!outputStr.isEmpty()) {
        qDebug() << "Update process output:" << outputStr;
        addLogMessage("Output: " + outputStr);
    }
}

void UpdateManager::readProcessError()
{
    QByteArray output = m_process->readAllStandardError();
    QString outputStr = QString::fromUtf8(output).trimmed();
    
    if (!outputStr.isEmpty()) {
        qWarning() << "Update process error output:" << outputStr;
        addLogMessage("Error: " + outputStr);
    }
}

void UpdateManager::addLogMessage(const QString &message)
{
    if (!message.isEmpty()) {
        m_logMessages.append(message);
        qDebug() << message;
        // Limit log messages (last 100 lines)
        if (m_logMessages.size() > 100) {
            m_logMessages.removeFirst();
        }
        emit logMessagesChanged();
        emit newLogMessage(message);
    }
} 
