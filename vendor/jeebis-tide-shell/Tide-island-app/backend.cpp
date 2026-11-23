#include "backend.hpp"
#include "../common/DisplayDurations.h"
#include "../common/JsonComments.h"
#include "../common/LockScreenConfig.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QLockFile>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>

Backend::Backend(QObject *parent) : QObject(parent),
    m_path(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
           + QStringLiteral("/tide-island/userconfig.json"))
{
    read(m_config);
}

QVariantMap Backend::durations() const
{
    return DisplayDurations::normalized(QJsonObject::fromVariantMap(m_config));
}

QVariantMap Backend::durationLimits() const { return DisplayDurations::limits(); }
int Backend::minimumDuration() const { return DisplayDurations::minimum; }

QString Backend::themeLockWallpaper() const
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation)
        + QStringLiteral("/jeebis-theme/current/lock-wallpaper");
}

QVariantMap Backend::lockScreenSettings() const
{
    return LockScreenConfig::normalized(QJsonObject::fromVariantMap(m_config.value("lockScreen").toMap()));
}

void Backend::lockScreen()
{
    if (!QProcess::startDetached(QStringLiteral("jeebis-desktop"), {QStringLiteral("lock")}))
        error(tr("Could not start the desktop lock command."));
}

void Backend::error(const QString &message)
{
    if (message != m_error) {
        m_error = message;
        emit errorChanged();
    }
}

bool Backend::read(QVariantMap &result)
{
    QFile file(m_path);
    if (!file.exists()) return true;
    if (!file.open(QIODevice::ReadOnly)) {
        error(file.errorString());
        return false;
    }
    QJsonParseError parse;
    const auto doc = QJsonDocument::fromJson(JsonComments::strip(file.readAll()), &parse);
    if (!doc.isObject()) {
        error(tr("Could not read settings from %1 (%2)").arg(m_path, parse.errorString()));
        return false;
    }
    result = doc.object().toVariantMap();
    return true;
}

bool Backend::save(const QVariantMap &changes, const QVariantMap &lockChanges)
{
    if (!QDir().mkpath(QFileInfo(m_path).absolutePath())) {
        error(tr("Could not create the settings directory."));
        return false;
    }
    QLockFile lock(m_path + ".lock");
    if (!lock.tryLock(500)) {
        error(tr("Another settings window is saving. Try again."));
        return false;
    }
    QVariantMap latest;
    if (!read(latest)) return false;
    latest.insert(changes);
    if (!lockChanges.isEmpty()) {
        auto values = latest.value("lockScreen").toMap();
        values.insert(lockChanges);
        latest.insert("lockScreen", values);
    }
    QSaveFile file(m_path);
    const auto bytes = QJsonDocument(QJsonObject::fromVariantMap(latest)).toJson();
    if (!file.open(QIODevice::WriteOnly) || file.write(bytes) != bytes.size() || !file.commit()) {
        error(file.errorString());
        return false;
    }
    m_config = latest;
    error({});
    emit configChanged();
    return true;
}
