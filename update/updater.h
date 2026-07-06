#ifndef UPDATER_H
#define UPDATER_H

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
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
    // Unified "something newer is out there" flag: true if either a newer editor
    // or a newer content (reader) build was detected. Nothing is downloaded until
    // the user explicitly calls applyUpdate(); the UI surfaces this on the version
    // badge. availableVersion is the version string to show (editor version when
    // an editor update is pending, else the highest pending content version).
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY updateAvailableChanged)
    Q_PROPERTY(QString availableVersion READ availableVersion NOTIFY updateAvailableChanged)
    // List of what is pending, for the menu: each entry is a map { label, version }.
    Q_PROPERTY(QVariantList pendingUpdates READ pendingUpdates NOTIFY updateAvailableChanged)
    // Currently installed components (Helper + each bundled platform build), each
    // a map { label, version }, for the "Installed" section of the menu.
    Q_PROPERTY(QVariantList installedComponents READ installedComponents NOTIFY installedComponentsChanged)

public:
    explicit Updater(QObject *parent = nullptr);

    // Detect what the manifest advertises WITHOUT downloading anything: compare
    // the editor version and every reader build against what is installed and
    // record which are newer. Cheap (disk-only) and safe to call on every
    // heartbeat; it is a no-op while an apply pass is running. The actual
    // download/extract happens only when the user calls applyUpdate().
    Q_INVOKABLE void applyManifest(const QVariantMap &manifest);

    // Apply everything detected as pending: download + verify + extract every
    // newer content (reader) build, then, if a newer editor is pending, download
    // it and hand off to the standalone `updater` helper (which waits for this
    // process to exit, overwrites the install dir, and relaunches the editor —
    // this quits the app). No-op unless updateAvailable is true. Non-blocking
    // (runs on a worker thread).
    Q_INVOKABLE void applyUpdate();

    // Apply the pending editor update only. Kept for completeness; the UI drives
    // applyUpdate() instead. Quits the app on success.
    Q_INVOKABLE void applyEditorUpdate();

    bool busy() const { return m_busy; }
    int progress() const { return m_progress; }
    QString statusMessage() const { return m_statusMessage; }
    bool editorUpdateAvailable() const { return m_editorUpdateAvailable; }
    QString editorUpdateVersion() const { return m_editorUpdateVersion; }
    bool updateAvailable() const { return m_editorUpdateAvailable || m_contentUpdateAvailable; }
    QString availableVersion() const { return m_availableVersion; }
    QVariantList pendingUpdates() const { return m_pendingUpdates; }
    QVariantList installedComponents() const { return m_installedComponents; }

signals:
    void busyChanged();
    void progressChanged();
    void statusMessageChanged();
    void editorUpdateAvailableChanged();
    // The unified updateAvailable / availableVersion pair changed.
    void updateAvailableChanged();
    // The list of currently installed components changed.
    void installedComponentsChanged();
    // A reader build was downloaded and installed into package/<platform>/.
    void readerUpdated(const QString &platform, const QString &version);
    // One applyManifest() pass finished (whether or not anything changed).
    void finished();
    void error(const QString &message);
    // The editor update was staged and the helper launched; the app is quitting.
    void editorUpdateStarted();

private:
    // Detection (main thread, disk-only, no network): fills m_pending* / editor
    // fields and updates the availability flags from a manifest.
    void detect(const QVariantMap &manifest);
    // Recompute m_availableVersion from the current pending editor/content state.
    void recomputeAvailableVersion();
    // Rebuild m_installedComponents (Helper + each installed platform build).
    void refreshInstalled();
    // Mirror a win reader's data/ subtree into test/FlowBookTestVersion v<ver>/
    // (the real reader, without the root starter exe or the data/ wrapper).
    // force=true replaces an existing folder; false skips if already present.
    void mirrorDataToTest(const QString &dataDir, const QString &versionLabel, bool force);
    // Ensure the latest installed win build is mirrored into test/ (startup path).
    void mirrorWinToTest();
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
    // Content (reader) builds detected as newer than what is installed, awaiting
    // an explicit applyUpdate(). Each entry is a map: folder, url, sha256, version.
    bool m_contentUpdateAvailable = false;
    QVariantList m_pendingReaders;
    // Version string surfaced to the UI ("New version available: <availableVersion>").
    QString m_availableVersion;
    // { label, version } entries for the update menu (editor + each content build).
    QVariantList m_pendingUpdates;
    // { label, version } for what is currently installed (Helper + platforms).
    QVariantList m_installedComponents;
};

#endif // UPDATER_H
