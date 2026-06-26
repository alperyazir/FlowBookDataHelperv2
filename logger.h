#ifndef LOGGER_H
#define LOGGER_H

#include <QString>

// Lightweight file logger that lives next to the executable.
//
// Why: in the field we occasionally get crashes or a config.json that has been
// tampered with from outside the app. There is no console attached to a
// deployed build, so those clues are lost. This routes every qDebug/qWarning/
// qCritical/qFatal message (plus a crash backtrace on hard signals) into a
// per-launch log file under "<exe dir>/logs", keeping only the most recent
// few sessions so the folder never grows without bound.
namespace Logger {

// Install the message handler + crash handlers and open this session's log
// file. Call once, right after the QGuiApplication is constructed (it needs
// applicationDirPath()). Safe to call even if the log dir can't be created -
// it just falls back to console-only.
//
// keepSessions: how many launches to retain (this one included).
void init(int keepSessions = 5);

// Absolute path of the current session's log file ("" if logging is disabled).
QString currentLogPath();

} // namespace Logger

#endif // LOGGER_H
