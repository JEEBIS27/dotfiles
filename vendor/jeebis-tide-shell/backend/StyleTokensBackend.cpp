#include "StyleTokensBackend.h"

#include <Qt>
#include <QFile>
#include <QJsonDocument>
#include <QTimer>
#include <QStandardPaths>

namespace {
QColor hex(const char *value)
{
    return QColor(QString::fromLatin1(value));
}
}

#define STYLE_COLOR(name, fallback) \
    QColor StyleTokensBackend::name() const \
    { \
        const QColor color(m_colors.value(QStringLiteral(#name)).toString(QString::fromLatin1(fallback))); \
        return color; \
    }

#define STYLE_GLOBAL_COLOR(name, value) \
    QColor StyleTokensBackend::name() const \
    { \
        return value; \
    }

StyleTokensBackend::StyleTokensBackend(QObject *parent)
    : QObject(parent)
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
}

STYLE_GLOBAL_COLOR(transparent, Qt::transparent)
STYLE_GLOBAL_COLOR(black, Qt::black)
STYLE_GLOBAL_COLOR(white, Qt::white)
QColor StyleTokensBackend::clearBlack() const { return QColor(0, 0, 0, 0); }
STYLE_COLOR(panel, "#202125")
STYLE_COLOR(surfaceBorder, "#26ffffff")
STYLE_COLOR(surfaceHighlight, "#0cffffff")
STYLE_COLOR(module, "#303136")
STYLE_COLOR(moduleHover, "#3a3b40")
STYLE_COLOR(track, "#242529")
STYLE_COLOR(cardFillActive, "#26272b")
STYLE_COLOR(cardFillHover, "#222327")
STYLE_COLOR(connectivityCard, "#343437")
STYLE_COLOR(connectivityCardHover, "#3a3a3d")
STYLE_COLOR(prompt, "#323236")
STYLE_COLOR(input, "#212226")
STYLE_COLOR(inputBorder, "#3f4046")
STYLE_COLOR(secondaryButton, "#4a4b50")
STYLE_COLOR(textPrimary, "#f5f5f7")
STYLE_COLOR(textPrimaryBright, "#f7f8fb")
STYLE_COLOR(textSecondary, "#b6b6bf")
STYLE_COLOR(textMuted, "#acadb6")
STYLE_COLOR(textSoft, "#9da0a8")
STYLE_COLOR(textTertiary, "#7f828a")
STYLE_COLOR(textDisabled, "#878a92")
STYLE_COLOR(textSubtle, "#8f9198")
STYLE_COLOR(textDim, "#b5b7bf")
STYLE_COLOR(accent, "#0a84ff")
STYLE_COLOR(accentPressed, "#0066d6")
STYLE_COLOR(accentSoft, "#6ea8ff")
STYLE_COLOR(success, "#34c759")
STYLE_COLOR(warning, "#ffcc00")
STYLE_COLOR(danger, "#ff3b30")
STYLE_COLOR(error, "#ff7c72")
STYLE_COLOR(disabledControl, "#868991")
STYLE_COLOR(switchOff, "#63656c")
STYLE_COLOR(buttonFill, "#f5f5f7")
STYLE_GLOBAL_COLOR(buttonFillHover, Qt::white)
STYLE_COLOR(buttonFillPressed, "#e9e9ec")
STYLE_COLOR(overviewCard, "#ee17181b")
STYLE_COLOR(overviewBorder, "#33ffffff")
STYLE_COLOR(overviewInnerBorder, "#12ffffff")
STYLE_COLOR(workspaceCell, "#ff202226")
STYLE_COLOR(workspaceCellHover, "#ff2b2d34")
STYLE_COLOR(workspaceCellBorder, "#1effffff")
STYLE_COLOR(workspaceCellBorderHover, "#66d9f6ff")
STYLE_COLOR(workspaceOverlay, "#42070b10")
STYLE_COLOR(workspaceOverlayHover, "#280d131a")
STYLE_COLOR(workspaceActiveBorder, "#73d4ff")

int StyleTokensBackend::radiusPanel() const { return 28; }
int StyleTokensBackend::radiusModule() const { return 20; }
int StyleTokensBackend::radiusPrompt() const { return 16; }
int StyleTokensBackend::radiusButton() const { return 12; }
int StyleTokensBackend::durationFast() const { return 120; }
int StyleTokensBackend::durationControl() const { return 130; }
int StyleTokensBackend::durationQuick() const { return 140; }
int StyleTokensBackend::durationStandard() const { return 240; }

#undef STYLE_COLOR
#undef STYLE_GLOBAL_COLOR
