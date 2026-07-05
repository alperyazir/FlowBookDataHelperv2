#ifndef UPDATER_H
#define UPDATER_H

#include <QObject>
#include <QVariantMap>
#include <QString>

// Editor-side remote update engine.
//
// Model: the running editor bundles per-platform FlowBook *reader* builds under
// programRoot()/package/<platform>/<version>/ and ships them to end users at
// packaging time. So "updating the reader" means keeping *every* platform's
// reader build fresh here, not updating a locally running reader. The editor
// itself is a separate artifact that can only be swapped by a helper exe after
// the editor quits (a running .exe is file-locked on Windows).
//
// Input is a manifest object, delivered piggy-backed on the /api/helpers
// heartbeat response (no separate endpoint). Shape:
//   {
//     "editor":       { "version": "3.1.0", "url": "...zip", "sha256": "..." },
//     "reader-win":   { "version": "3.2.0", "url": "...zip", "sha256": "..." },
//     "reader-win7-8":{ ... }, "reader-linux": { ... }, "reader-mac": { ... }
//   }
// Every field is optional; a missing artifact is simply not touched.
//
// Reader zips must contain the build files at their root (they are extracted
// straight into package/<platform>/<version>/).
class Updater : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    // Set when the manifest advertises a newer editor than APP_VERSION. Applying
    // it (the updater.exe hand-off) is a separate, explicit step.
    Q_PROPERTY(bool editorUpdateAvailable READ editorUpdateAvailable NOTIFY editorUpdateAvailableChanged)
    Q_PROPERTY(QString editorUpdateVersion READ editorUpdateVersion NOTIFY editorUpdateAvailableChanged)

public:
    explicit Updater(QObject *parent = nullptr);

    // Compare the manifest against what is installed and pull down every reader
    // build that is newer. Safe to call on every heartbeat: it is a no-op while
    // already running, and skips artifacts already up to date. Non-blocking
    // (runs on a worker thread).
    Q_INVOKABLE void applyManifest(const QVariantMap &manifest);

    // Apply the pending editor update: download + verify the editor zip, extract
    // it, then hand off to the standalone `updater` helper (which waits for this
    // process to exit, overwrites the install dir, and relaunches the editor).
    // No-op unless a newer editor was seen in a prior applyManifest(). This
    // quits the app on success.
    Q_INVOKABLE void applyEditorUpdate();

    bool busy() const { return m_busy; }
    int progress() const { return m_progress; }
    QString statusMessage() const { return m_statusMessage; }
    bool editorUpdateAvailable() const { return m_editorUpdateAvailable; }
    QString editorUpdateVersion() const { return m_editorUpdateVersion; }

signals:
    void busyChanged();
    void progressChanged();
    void statusMessageChanged();
    void editorUpdateAvailableChanged();
    // A reader build was downloaded and installed into package/<platform>/.
    void readerUpdated(const QString &platform, const QString &version);
    // One applyManifest() pass finished (whether or not anything changed).
    void finished();
    void error(const QString &message);
    // The editor update was staged and the helper launched; the app is quitting.
    void editorUpdateStarted();

private:
    // Worker-thread helpers.
    void runManifest(const QVariantMap &manifest);
    // Download url → verify sha256 → extract into package/<platformFolder>/<version>/.
    // Returns true on success (or if already current). platformFolder is the
    // on-disk folder name: "win", "win7-8", "linux", "mac".
    bool syncReader(const QString &platformFolder,
                    const QString &url,
                    const QString &sha256,
                    const QString &version);

    // Highest installed reader version folder under package/<platformFolder>/,
    // or empty if none.
    QString installedReaderVersion(const QString &platformFolder) const;
    // Download url to a temp file; empty string on failure. Verifies sha256 if
    // non-empty. Blocking (call from the worker thread only).
    QString downloadToTemp(const QString &url, const QString &sha256);
    // Extract a zip into destDir (created fresh). Uses 7-Zip on Windows, unzip
    // elsewhere. Blocking.
    bool extractZip(const QString &zipPath, const QString &destDir);

    // Main-thread tail of applyEditorUpdate(): copy the helper to a temp path,
    // launch it with (srcDir, installDir, exePath, pid), then quit the app.
    void launchUpdaterAndQuit(const QString &srcDir);

    // Thread-safe property mutators (marshal onto the object's thread).
    void setBusy(bool v);
    void setProgress(int v);
    void setStatusMessage(const QString &v);

    bool m_busy = false;
    int m_progress = 0;
    QString m_statusMessage;
    bool m_editorUpdateAvailable = false;
    QString m_editorUpdateVersion;
    // Kept from the last manifest so applyEditorUpdate() can fetch the payload.
    QString m_editorUrl;
    QString m_editorSha;
};

#endif // UPDATER_H
