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

public:
    explicit ActivityTracker(QObject *parent = nullptr);

    bool active() const;

    Q_INVOKABLE void setCurrentBook(const QString &book);

    bool eventFilter(QObject *watched, QEvent *event) override;

signals:
    void activeChanged();

private slots:
    void evaluateActive();
    void tick();
    void flushToDisk();
    void scanAndUpload();

private:
    static constexpr int IDLE_THRESHOLD_MS = 60 * 1000;
    static constexpr int EVAL_INTERVAL_MS  = 5 * 1000;
    static constexpr int TICK_INTERVAL_MS  = 10 * 1000;
    static constexpr int FLUSH_INTERVAL_MS = 60 * 1000;

    using HourBuckets = QMap<int, QMap<QString, int>>; // hour -> book -> seconds

    void rolloverIfNeeded();
    void loadFromDisk();
    void saveToDisk();
    QJsonObject serializeDay(const HourBuckets &hours) const;

    QString storagePath() const;

    void removeDaysAndSave(const QList<QDate> &uploaded);

    qint64 _lastActivityMs;
    bool _active;

    QString _currentBook;
    QDate _currentDate;
    QMap<QDate, HourBuckets> _days;

    QTimer _evalTimer;
    QTimer _tickTimer;
    QTimer _flushTimer;

    QNetworkAccessManager *_nam;
};

#endif
