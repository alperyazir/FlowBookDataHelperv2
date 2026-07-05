// Standalone update helper ("updater.exe").
//
// The editor cannot overwrite its own running .exe (Windows keeps it locked),
// so it stages the new build in a temp dir, launches this helper, and quits.
// This helper then:
//   1. waits for the editor process to exit,
//   2. copies the staged files over the install dir (retrying while locked),
//   3. relaunches the editor,
//   4. cleans up and exits.
//
// It is deliberately tiny and dependency-free (QtCore only) and never updates
// itself — the editor runs it from a temp copy so the installed helper can also
// be replaced by the new build.
//
// Usage: updater <srcDir> <installDir> <exePath> <pid>

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QThread>
#include <QDebug>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

static bool copyRecursively(const QString &src, const QString &dst) {
    QFileInfo si(src);
    if (si.isDir()) {
        if (!QDir().mkpath(dst))
            return false;
        const QDir sd(src);
        const QFileInfoList entries = sd.entryInfoList(
            QDir::NoDotAndDotDot | QDir::AllEntries | QDir::Hidden | QDir::System);
        for (const QFileInfo &fi : entries) {
            if (!copyRecursively(fi.absoluteFilePath(), dst + "/" + fi.fileName()))
                return false;
        }
        return true;
    }
    QFile::remove(dst); // QFile::copy won't overwrite
    return QFile::copy(src, dst);
}

static void waitForProcessExit(qint64 pid) {
#ifdef Q_OS_WIN
    HANDLE h = OpenProcess(SYNCHRONIZE, FALSE, static_cast<DWORD>(pid));
    if (h) {
        WaitForSingleObject(h, 60000); // up to 60s for the editor to close
        CloseHandle(h);
    }
#else
    Q_UNUSED(pid);
#endif
    QThread::msleep(500); // small grace period for file handles to release
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    const QStringList a = app.arguments();
    if (a.size() < 5) {
        qWarning("usage: updater <srcDir> <installDir> <exePath> <pid>");
        return 2;
    }
    const QString srcDir = a.at(1);
    const QString installDir = a.at(2);
    const QString exePath = a.at(3);
    const qint64 pid = a.at(4).toLongLong();

    waitForProcessExit(pid);

    // Copy the staged build over the install dir, retrying while the exe may
    // still be briefly locked.
    bool ok = false;
    for (int attempt = 0; attempt < 15 && !ok; ++attempt) {
        ok = copyRecursively(srcDir, installDir);
        if (!ok)
            QThread::msleep(1000);
    }

    // Relaunch the editor (best effort) and remove the staging dir.
    QProcess::startDetached(exePath, QStringList());
    QDir(srcDir).removeRecursively();
    return ok ? 0 : 1;
}
