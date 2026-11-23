#pragma once

#include <QJsonObject>
#include <QVariantMap>
#include <algorithm>

namespace DisplayDurations {
struct Duration {
    const char *key;
    int initial;
    int maximum;
};
inline constexpr int minimum = 100;
inline constexpr Duration settings[] = {
    {"edgeHandleDurationMs", 2000, 60000},
    {"islandAutoHideDelayMs", 2000, 10000},
    {"transientCapsuleDurationMs", 1250, 60000},
    {"notificationDurationMs", 6000, 60000},
    {"workingForegroundDurationMs", 6000, 60000},
    {"trackChangeDurationMs", 5000, 60000},
    {"bluetoothDetailDurationMs", 2500, 60000},
};

inline QVariantMap normalized(const QJsonObject &config)
{
    QVariantMap result;
    for (const auto &setting : settings) {
        const auto key = QLatin1String(setting.key);
        result.insert(key, std::clamp(config.value(key).toInt(setting.initial), minimum, setting.maximum));
    }
    return result;
}

inline QVariantMap limits()
{
    QVariantMap result;
    for (const auto &setting : settings)
        result.insert(QLatin1String(setting.key), setting.maximum);
    return result;
}
}
