#include "logger.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QMutex>
#include <QTextStream>

#include <csignal>
#include <cstdio>
#include <cstring>

#ifdef Q_OS_WIN
#include <io.h>
#include <fcntl.h>
#include <sys/stat.h>
#else
#include <fcntl.h>
#include <unistd.h>
#include <execinfo.h>
#endif

namespace {

QMutex g_mutex;
QFile *g_logFile = nullptr;   // buffered, used by the message handler
QString g_logPath;
int g_crashFd = -1;           // raw fd reused inside the (async) crash handler

const char *levelTag(QtMsgType type)
{
    switch (type) {
    case QtDebugMsg:    return "D";
    case QtInfoMsg:     return "I";
    case QtWarningMsg:  return "W";
    case QtCriticalMsg: return "C";
    case QtFatalMsg:    return "F";
    }
    return "?";
}

// --- low-level write used both by init banner and the crash handler ---
void writeRaw(int fd, const char *buf, int len)
{
    if (fd < 0 || len <= 0)
        return;
#ifdef Q_OS_WIN
    _write(fd, buf, static_cast<unsigned int>(len));
#else
    ssize_t r = ::write(fd, buf, static_cast<size_t>(len));
    (void)r;
#endif
}

const char *signalName(int sig)
{
    switch (sig) {
    case SIGSEGV: return "SIGSEGV (invalid memory access)";
    case SIGABRT: return "SIGABRT (abort)";
    case SIGFPE:  return "SIGFPE (arithmetic error)";
    case SIGILL:  return "SIGILL (illegal instruction)";
#ifdef SIGBUS
    case SIGBUS:  return "SIGBUS (bus error)";
#endif
    default:      return "unknown signal";
    }
}

// Hard-crash handler. Must stay minimal and avoid heap/locks where possible:
// the process is already on its way down. We append a marker + a native
// backtrace straight to a raw fd, then restore the default handler and
// re-raise so the OS still produces its own crash report / core dump.
extern "C" void crashHandler(int sig)
{
    if (g_crashFd >= 0) {
        char head[160];
        int n = std::snprintf(head, sizeof(head),
                              "\n==== CRASH: signal %d %s ====\n",
                              sig, signalName(sig));
        if (n > 0)
            writeRaw(g_crashFd, head, n);

#ifndef Q_OS_WIN
        void *frames[64];
        int count = backtrace(frames, 64);
        backtrace_symbols_fd(frames, count, g_crashFd);
#endif
        const char tail[] = "==== end crash ====\n";
        writeRaw(g_crashFd, tail, int(sizeof(tail)) - 1);
    }

    std::signal(sig, SIG_DFL);
    std::raise(sig);
}

void messageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    const QString ts = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz");

    QString line = QString("[%1] [%2] %3").arg(ts, levelTag(type), msg);
    if (context.file && type != QtDebugMsg && type != QtInfoMsg) {
        // Attach origin for the messages most likely to matter post-mortem.
        line += QString(" (%1:%2)").arg(context.file).arg(context.line);
    }

    {
        QMutexLocker locker(&g_mutex);
        if (g_logFile && g_logFile->isOpen()) {
            QTextStream out(g_logFile);
            out << line << '\n';
            out.flush();
            g_logFile->flush();
        }
    }

    // Keep console output too (useful when run from a terminal / Qt Creator).
    fprintf(stderr, "%s\n", qPrintable(line));
    fflush(stderr);

    if (type == QtFatalMsg)
        abort();
}

// Keep only the most recent `keep` session logs (this run's file included).
void pruneOldLogs(const QString &dir, int keep)
{
    QDir d(dir);
    const QStringList files =
        d.entryList(QStringList() << "session_*.log", QDir::Files, QDir::Name);
    // entryList is sorted ascending by name; timestamped names sort oldest-first.
    int removable = files.size() - (keep - 1); // leave room for the new file
    for (int i = 0; i < removable; ++i)
        d.remove(files.at(i));
}

} // namespace

namespace Logger {

void init(int keepSessions)
{
    if (keepSessions < 1)
        keepSessions = 1;

    const QString dir = QCoreApplication::applicationDirPath() + "/logs";
    if (!QDir().mkpath(dir)) {
        fprintf(stderr, "Logger: could not create log dir %s\n", qPrintable(dir));
        // Still install the handler so console logging stays consistent.
        qInstallMessageHandler(messageHandler);
        return;
    }

    pruneOldLogs(dir, keepSessions);

    const QString stamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz");
    g_logPath = dir + "/session_" + stamp + ".log";

    g_logFile = new QFile(g_logPath);
    if (!g_logFile->open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Append)) {
        fprintf(stderr, "Logger: could not open log file %s\n", qPrintable(g_logPath));
        delete g_logFile;
        g_logFile = nullptr;
        g_logPath.clear();
        qInstallMessageHandler(messageHandler);
        return;
    }

    // Independent raw fd for the crash handler (kept open for the process life).
    const QByteArray nativePath = QFile::encodeName(g_logPath);
#ifdef Q_OS_WIN
    g_crashFd = _open(nativePath.constData(),
                      _O_WRONLY | _O_APPEND | _O_CREAT, _S_IREAD | _S_IWRITE);
#else
    g_crashFd = ::open(nativePath.constData(),
                       O_WRONLY | O_APPEND | O_CREAT, 0644);
#endif

    // Session banner.
    const QString banner =
        QString("==== session start %1 | %2 | pid %3 ====")
            .arg(QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss"),
                 QCoreApplication::applicationFilePath())
            .arg(QCoreApplication::applicationPid());
    {
        QTextStream out(g_logFile);
        out << banner << '\n';
        out.flush();
        g_logFile->flush();
    }

    qInstallMessageHandler(messageHandler);

    // Catch hard crashes so we at least record that one happened + a backtrace.
    std::signal(SIGSEGV, crashHandler);
    std::signal(SIGABRT, crashHandler);
    std::signal(SIGFPE, crashHandler);
    std::signal(SIGILL, crashHandler);
#ifdef SIGBUS
    std::signal(SIGBUS, crashHandler);
#endif
}

QString currentLogPath()
{
    return g_logPath;
}

} // namespace Logger
