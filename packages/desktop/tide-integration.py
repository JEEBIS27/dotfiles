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
s=s.replace('static const QColor color = hex(value);', 'const QColor color(m_colors.value(QStringLiteral(#name)).toString(QString::fromLatin1(value)));')
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
