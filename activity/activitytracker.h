#ifndef ACTIVITYTRACKER_H
#define ACTIVITYTRACKER_H

#include <QDate>
#include <QJsonObject>
#include <QMap>
#include <QObject>
#include <QString>
#include <QTimer>

class QNetworkAccessManager;
class QNetworkReply;

class ActivityTracker : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    // Session counters (since app launch), surfaced in the heartbeat so the
    // server can see how long this helper has been open vs. sitting idle.
    Q_PROPERTY(int openSeconds READ openSeconds NOTIFY statsChanged)
    Q_PROPERTY(int idleSeconds READ idleSeconds NOTIFY statsChanged)

public:
    explicit ActivityTracker(QObject *parent = nullptr);

    bool active() const;
    int openSeconds() const { return _openSeconds; }
    int idleSeconds() const { return _idleSeconds; }

    Q_INVOKABLE void setCurrentBook(const QString &book);

    bool eventFilter(QObject *watched, QEvent *event) override;

signals:
    void activeChanged();
    void statsChanged();

private slots:
    void evaluateActive();
    void tick();
    void flushToDisk();
    void scanAndUpload();

private:
    static constexpr int IDLE_THRESHOLD_MS = 5 * 60 * 1000; // 5 min of no input => idle
    static constexpr int EVAL_INTERVAL_MS  = 5 * 1000;
    static constexpr int TICK_INTERVAL_MS  = 10 * 1000;
    static constexpr int FLUSH_INTERVAL_MS = 60 * 1000;
    static constexpr int RETRY_INTERVAL_MS = 10 * 60 * 1000; // 10 min

    using HourBuckets = QMap<int, QMap<QString, int>>; // hour -> book -> seconds

    void rolloverIfNeeded();
    void loadFromDisk();
    void saveToDisk();
    QJsonObject serializeDay(const HourBuckets &hours) const;

    QString storagePath() const;

    void removeDaysAndSave(const QList<QDate> &uploaded);

    qint64 _lastActivityMs;
    bool _active;

    // Cumulative session time, advanced once per tick (TICK_INTERVAL_MS).
    int _openSeconds = 0;   // total time the app has been open this session
    int _idleSeconds = 0;   // subset of the above spent not active (idle)

    QString _currentBook;
    QDate _currentDate;
    QMap<QDate, HourBuckets> _days;

    QTimer _evalTimer;
    QTimer _tickTimer;
    QTimer _flushTimer;
    QTimer _retryTimer;

    QNetworkAccessManager *_nam;
    bool _uploadInFlight = false;
};

#endif
