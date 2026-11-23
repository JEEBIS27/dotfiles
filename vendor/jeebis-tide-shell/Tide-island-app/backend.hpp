#pragma once

#include <QObject>
#include <QVariantMap>

class Backend final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap userConfig READ userConfig NOTIFY configChanged)
    Q_PROPERTY(QVariantMap durations READ durations NOTIFY configChanged)
    Q_PROPERTY(QVariantMap durationLimits READ durationLimits CONSTANT)
    Q_PROPERTY(int minimumDuration READ minimumDuration CONSTANT)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorChanged)
    Q_PROPERTY(QString themeLockWallpaper READ themeLockWallpaper CONSTANT)

public:
    explicit Backend(QObject *parent = nullptr);
    QVariantMap userConfig() const { return m_config; }
    QVariantMap durations() const;
    QVariantMap durationLimits() const;
    int minimumDuration() const;
    QString errorString() const { return m_error; }
    QString themeLockWallpaper() const;
    Q_INVOKABLE QVariantMap lockScreenSettings() const;
    Q_INVOKABLE bool save(const QVariantMap &changes, const QVariantMap &lockChanges);
    Q_INVOKABLE void lockScreen();

signals:
    void configChanged();
    void errorChanged();

private:
    bool read(QVariantMap &result);
    void error(const QString &message);

    QString m_path;
    QString m_error;
    QVariantMap m_config;
};
