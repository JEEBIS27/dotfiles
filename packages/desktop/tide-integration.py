"""Small source adapter: live personal palette and a dedicated PAM lock service."""
from pathlib import Path
import sys
r=Path(sys.argv[1])
p=r/'CMakeLists.txt'
s=p.read_text();a=s.index('add_executable(tlp_password_tests');b=s.index('# Installation Rules',a);p.write_text(s[:a]+s[b:])
p=r/'backend/StyleTokensBackend.h';s=p.read_text().replace('#include <QObject>','#include <QObject>\n#include <QJsonObject>')
# Color tokens become reactive; geometry and duration tokens remain constant.
import re
s=re.sub(r'(Q_PROPERTY\(QColor .*?) CONSTANT FINAL',r'\1 NOTIFY themeChanged FINAL',s)
s=s.replace('public:\n','signals:\n    void themeChanged();\nprivate:\n    QJsonObject m_colors;\n    QByteArray m_themeBytes;\n    void reloadTheme();\npublic:\n',1);p.write_text(s)
p=r/'backend/StyleTokensBackend.cpp';s=p.read_text().replace('#include <Qt>','#include <Qt>\n#include <QFile>\n#include <QJsonDocument>\n#include <QTimer>\n#include <QStandardPaths>')
# Avoid macro substitution of the QJsonObject member function named value.
s=s.replace('#define STYLE_COLOR(name, value)', '#define STYLE_COLOR(name, fallback)')
s=s.replace('static const QColor color = hex(value);', 'const QColor color(m_colors.value(QStringLiteral(#name)).toString(QString::fromLatin1(fallback)));')
s=s.replace(': QObject(parent)\n{\n}', ''': QObject(parent)
{
    reloadTheme();
    auto *timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &StyleTokensBackend::reloadTheme);
    timer->start(1000);
}

void StyleTokensBackend::reloadTheme()
{
    const auto path = QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation)
        + QStringLiteral("/jeebis-theme/current/tide-colors.json");
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return;
    const auto bytes = file.readAll();
    if (bytes == m_themeBytes) return;
    const auto document = QJsonDocument::fromJson(bytes);
    if (!document.isObject()) return;
    m_themeBytes = bytes;
    m_colors = document.object();
    emit themeChanged();
}''');p.write_text(s)
p=r/'qml/lockscreen/LockScreenController.qml';s=p.read_text().replace('config: "login"','config: "tide-island"').replace('wallpaperPath: UserConfig.wallpaperPath','wallpaperPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/jeebis-theme/current/lock-wallpaper"');p.write_text(s)
# Acknowledge actual lock acquisition before swayidle releases its delay inhibitor.
p=r/'shell.qml';s=p.read_text();at=s.index('        function lockScreen() {',s.index('target: "tide"'))
s=s[:at]+'''        function lockStatus(): bool { return lockScreenController.secure; }

'''+s[at:];p.write_text(s)

p=r/'qml/lockscreen/LockScreenView.qml'
s=p.read_text().replace('objectName: "lockWallpaper"', 'objectName: "lockWallpaper"\n            cache: false')
p.write_text(s)

# PulseAudio localizes `pactl subscribe` output. Treat every non-empty event as
# a reason to re-read the default sink instead of guessing the event type from
# translated words such as "sink". The existing debounce keeps event bursts
# cheap, and `wpctl get-volume` remains the source of truth for both volume and
# mute state.
p=r/'backend/SysBackend.cpp'
s=p.read_text()
old='''void SysBackend::handleVolumeEvent() {
    QByteArray output = m_paSubscriber->readAllStandardOutput();

    if (output.contains("sink") || output.contains("card") || output.contains("server")) {
        if (m_audioDebounceTimer) m_audioDebounceTimer->start();
    }
}'''
new='''void SysBackend::handleVolumeEvent() {
    const QByteArray output = m_paSubscriber->readAllStandardOutput();
    if (!output.trimmed().isEmpty() && m_audioDebounceTimer)
        m_audioDebounceTimer->start();
}'''
if old not in s:
    raise RuntimeError('upstream SysBackend::handleVolumeEvent changed')
p.write_text(s.replace(old,new))


# Carry the observed mute state into the control center as well as the transient
# island OSD. Muting intentionally keeps the stored volume/slider position; the
# icon is the mute indicator.
p=r/'qml/controlcenter/ControlCenterLayer.qml'
s=p.read_text()
replacements={
    '    property real volumeLevel: -1\n    property real brightnessLevel: -1':
        '    property real volumeLevel: -1\n    property bool volumeMuted: false\n    property real brightnessLevel: -1',
    '    readonly property string volumeIconGlyph: "\\u{F057E}"':
        '    readonly property string volumeIconGlyph: volumeMuted ? "\\u{F075F}" : "\\u{F057E}"',
    '        function onVolumeSnapshotReady(value, muted, errorString) {\n            if (errorString === "")\n                controlCenter.applyVolumeSnapshot(value);\n        }':
        '        function onVolumeSnapshotReady(value, muted, errorString) {\n            if (errorString === "") {\n                controlCenter.volumeMuted = muted;\n                controlCenter.applyVolumeSnapshot(value);\n            }\n        }'
}
for old,new in replacements.items():
    if old not in s:
        raise RuntimeError(f'upstream ControlCenterLayer changed: {old!r}')
    s=s.replace(old,new)
p.write_text(s)

p=r/'DynamicIslandWindow.qml'
s=p.read_text()
old='''                        volumeLevel: islandContainer.currentVolume
                        brightnessLevel: islandContainer.currentBrightness'''
new='''                        volumeLevel: islandContainer.currentVolume
                        volumeMuted: islandContainer.isMuted
                        brightnessLevel: islandContainer.currentBrightness'''
if old not in s:
    raise RuntimeError('upstream ControlCenterLayer property wiring changed')
p.write_text(s.replace(old,new))


def replace_once(path, before, after):
    source = path.read_text()
    if source.count(before) != 1:
        raise RuntimeError(f"upstream {path.name} changed: {before!r}")
    path.write_text(source.replace(before, after))


# Keep keyboard peeking independent of the pointer and persistent visibility.
replace_once(
    p,
    '''    readonly property bool autoHideTargetVisible: autoHideMustShow
        || (!autoHideForcedHidden && (!autoHideEnabled || autoHideVisible))''',
    '''    readonly property bool islandNormallyVisible: autoHideMustShow
        || (!autoHideForcedHidden && (!autoHideEnabled || autoHideVisible))
    readonly property bool autoHideTargetVisible: islandNormallyVisible || islandPeekTimer.running''',
)
replace_once(
    p,
    '(!autoHideEnabled && autoHideTargetVisible)',
    '(!autoHideEnabled && islandNormallyVisible)',
)
replace_once(
    p,
    '''    function showIslandWindow() {
        showAutoHiddenIsland("manual");
    }

    function hideIslandWindow() {''',
    '''    Timer {
        id: islandPeekTimer
        interval: Math.max(100, Math.min(10000, userConfig.islandAutoHideDelayMs))
    }

    function peekIslandWindow() {
        islandPeekTimer.restart();
    }

    function showIslandWindow() {
        islandPeekTimer.stop();
        showAutoHiddenIsland("manual");
    }

    function hideIslandWindow() {
        islandPeekTimer.stop();''',
)
replace_once(
    r / 'shell.qml',
    '''        target: "island"
''',
    '''        target: "island"

        function peek() {
            shellRoot.forEachWindow((window) => window.peekIslandWindow());
        }
''',
)
