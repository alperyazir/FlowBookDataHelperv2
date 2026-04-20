#include "activitytracker.h"

#include "config/configparser.h"

#include <QDateTime>
#include <QDebug>
#include <QEvent>
#include <QFile>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

namespace {
constexpr const char *kUploadUrl = "https://flowbook.uk/api/helpersDetail";
constexpr const char *kFileName  = ".system";
}

ActivityTracker::ActivityTracker(QObject *parent)
    : QObject(parent)
    , _lastActivityMs(QDateTime::currentMSecsSinceEpoch())
    , _active(false)
    , _nam(new QNetworkAccessManager(this))
{
    _evalTimer.setInterval(EVAL_INTERVAL_MS);
    connect(&_evalTimer, &QTimer::timeout, this, &ActivityTracker::evaluateActive);
    _evalTimer.start();

    _tickTimer.setInterval(TICK_INTERVAL_MS);
    connect(&_tickTimer, &QTimer::timeout, this, &ActivityTracker::tick);
    _tickTimer.start();

    _flushTimer.setInterval(FLUSH_INTERVAL_MS);
    connect(&_flushTimer, &QTimer::timeout, this, &ActivityTracker::flushToDisk);
    _flushTimer.start();

    loadFromDisk();
    _currentDate = QDate::currentDate();
    scanAndUpload();
}

bool ActivityTracker::active() const
{
    return _active;
}

void ActivityTracker::setCurrentBook(const QString &book)
{
    if (_currentBook == book)
        return;
    _currentBook = book;
}

bool ActivityTracker::eventFilter(QObject *watched, QEvent *event)
{
    switch (event->type()) {
    case QEvent::MouseMove:
    case QEvent::MouseButtonPress:
    case QEvent::MouseButtonRelease:
    case QEvent::KeyPress:
    case QEvent::Wheel:
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::HoverMove:
        _lastActivityMs = QDateTime::currentMSecsSinceEpoch();
        break;
    default:
        break;
    }
    return QObject::eventFilter(watched, event);
}

void ActivityTracker::evaluateActive()
{
    const bool focused =
        QGuiApplication::applicationState() == Qt::ApplicationActive;
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const bool recentInput = (now - _lastActivityMs) < IDLE_THRESHOLD_MS;
    const bool next = focused && recentInput;

    if (next != _active) {
        _active = next;
        emit activeChanged();
    }
}

void ActivityTracker::tick()
{
    rolloverIfNeeded();

    if (!_active || _currentBook.isEmpty())
        return;

    const QDate today = QDate::currentDate();
    const int hour = QTime::currentTime().hour();
    _days[today][hour][_currentBook] += TICK_INTERVAL_MS / 1000;
}

void ActivityTracker::flushToDisk()
{
    saveToDisk();
}

void ActivityTracker::rolloverIfNeeded()
{
    const QDate today = QDate::currentDate();
    if (!_currentDate.isValid()) {
        _currentDate = today;
        return;
    }
    if (_currentDate != today) {
        saveToDisk();
        _currentDate = today;
        scanAndUpload();
    }
}

QString ActivityTracker::storagePath() const
{
#ifdef Q_OS_MAC
    // next to the .app bundle
    return QGuiApplication::applicationDirPath() + "/../../../"
           + QString::fromLatin1(kFileName);
#else
    // next to the exe
    return QGuiApplication::applicationDirPath() + "/"
           + QString::fromLatin1(kFileName);
#endif
}

QJsonObject ActivityTracker::serializeDay(const HourBuckets &hours) const
{
    QJsonObject hoursObj;
    for (auto it = hours.constBegin(); it != hours.constEnd(); ++it) {
        QJsonObject books;
        const auto &bookMap = it.value();
        for (auto b = bookMap.constBegin(); b != bookMap.constEnd(); ++b) {
            books.insert(b.key(), b.value());
        }
        const QString hourKey = QString("%1").arg(it.key(), 2, 10, QChar('0'));
        hoursObj.insert(hourKey, books);
    }
    QJsonObject dayObj;
    dayObj.insert("hours", hoursObj);
    return dayObj;
}

void ActivityTracker::saveToDisk()
{
    QJsonObject daysObj;
    for (auto it = _days.constBegin(); it != _days.constEnd(); ++it) {
        daysObj.insert(it.key().toString("yyyy-MM-dd"), serializeDay(it.value()));
    }

    QJsonObject root;
    root.insert("hostname",
                ConfigParser::instance()->property("hostname").toString());
    root.insert("timezone_offset_min",
                QDateTime::currentDateTime().offsetFromUtc() / 60);
    root.insert("days", daysObj);

    const QString finalPath = storagePath();
    const QString tmpPath = finalPath + ".tmp";

    QFile f(tmpPath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "[ActivityTracker] cannot open tmp file:" << tmpPath
                   << f.errorString();
        return;
    }
    f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    f.close();

    QFile::remove(finalPath);
    if (!QFile::rename(tmpPath, finalPath)) {
        qWarning() << "[ActivityTracker] rename failed:" << tmpPath
                   << "->" << finalPath;
        return;
    }
}

void ActivityTracker::loadFromDisk()
{
    _days.clear();
    const QString path = storagePath();
    QFile f(path);
    if (!f.exists()) {
        return;
    }
    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "[ActivityTracker] cannot read" << path << f.errorString();
        return;
    }
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    if (!doc.isObject())
        return;

    const QJsonObject days = doc.object().value("days").toObject();
    for (auto dIt = days.constBegin(); dIt != days.constEnd(); ++dIt) {
        const QDate date = QDate::fromString(dIt.key(), "yyyy-MM-dd");
        if (!date.isValid())
            continue;
        HourBuckets hours;
        const QJsonObject hoursObj = dIt.value().toObject().value("hours").toObject();
        for (auto hIt = hoursObj.constBegin(); hIt != hoursObj.constEnd(); ++hIt) {
            bool ok = false;
            const int hour = hIt.key().toInt(&ok);
            if (!ok)
                continue;
            QMap<QString, int> books;
            const QJsonObject booksObj = hIt.value().toObject();
            for (auto bIt = booksObj.constBegin(); bIt != booksObj.constEnd(); ++bIt) {
                books.insert(bIt.key(), bIt.value().toInt());
            }
            hours.insert(hour, books);
        }
        _days.insert(date, hours);
    }
}

void ActivityTracker::scanAndUpload()
{
    const QDate today = QDate::currentDate();

    QList<QDate> pastDays;
    for (auto it = _days.constBegin(); it != _days.constEnd(); ++it) {
        if (it.key() < today)
            pastDays.append(it.key());
    }
    if (pastDays.isEmpty())
        return;

    QJsonObject daysObj;
    for (const QDate &d : pastDays) {
        daysObj.insert(d.toString("yyyy-MM-dd"), serializeDay(_days.value(d)));
    }

    QJsonObject payload;
    payload.insert("hostname",
                   ConfigParser::instance()->property("hostname").toString());
    payload.insert("timezone_offset_min",
                   QDateTime::currentDateTime().offsetFromUtc() / 60);
    payload.insert("days", daysObj);

    const QByteArray body = QJsonDocument(payload).toJson(QJsonDocument::Compact);

    QNetworkRequest req{QUrl(QString::fromLatin1(kUploadUrl))};
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QNetworkReply *reply = _nam->post(req, body);
    connect(reply, &QNetworkReply::finished, this, [this, reply, pastDays]() {
        const int status =
            reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() == QNetworkReply::NoError
            && status >= 200 && status < 300) {
            removeDaysAndSave(pastDays);
        } else {
            qWarning() << "[ActivityTracker] upload FAIL status=" << status
                       << "err=" << reply->errorString();
        }
        reply->deleteLater();
    });
}

void ActivityTracker::removeDaysAndSave(const QList<QDate> &uploaded)
{
    for (const QDate &d : uploaded)
        _days.remove(d);
    saveToDisk();
}
