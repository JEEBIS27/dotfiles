#pragma once

#include <QColor>
#include <QObject>
#include <QJsonObject>
#include <QtQml/qqml.h>

class StyleTokensBackend final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(StyleTokens)
    QML_SINGLETON

    Q_PROPERTY(QColor transparent READ transparent NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor black READ black NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor white READ white NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor clearBlack READ clearBlack NOTIFY themeChanged FINAL)

    Q_PROPERTY(QColor panel READ panel NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor surfaceBorder READ surfaceBorder NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor surfaceHighlight READ surfaceHighlight NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor module READ module NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor moduleHover READ moduleHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor track READ track NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor cardFillActive READ cardFillActive NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor cardFillHover READ cardFillHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor connectivityCard READ connectivityCard NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor connectivityCardHover READ connectivityCardHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor prompt READ prompt NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor input READ input NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor inputBorder READ inputBorder NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor secondaryButton READ secondaryButton NOTIFY themeChanged FINAL)

    Q_PROPERTY(QColor textPrimary READ textPrimary NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textPrimaryBright READ textPrimaryBright NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textSecondary READ textSecondary NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textMuted READ textMuted NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textSoft READ textSoft NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textTertiary READ textTertiary NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textDisabled READ textDisabled NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textSubtle READ textSubtle NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor textDim READ textDim NOTIFY themeChanged FINAL)

    Q_PROPERTY(QColor accent READ accent NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor accentPressed READ accentPressed NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor accentSoft READ accentSoft NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor success READ success NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor warning READ warning NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor danger READ danger NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor error READ error NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor disabledControl READ disabledControl NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor switchOff READ switchOff NOTIFY themeChanged FINAL)

    Q_PROPERTY(QColor buttonFill READ buttonFill NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor buttonFillHover READ buttonFillHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor buttonFillPressed READ buttonFillPressed NOTIFY themeChanged FINAL)

    Q_PROPERTY(QColor overviewCard READ overviewCard NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor overviewBorder READ overviewBorder NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor overviewInnerBorder READ overviewInnerBorder NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceCell READ workspaceCell NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceCellHover READ workspaceCellHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceCellBorder READ workspaceCellBorder NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceCellBorderHover READ workspaceCellBorderHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceOverlay READ workspaceOverlay NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceOverlayHover READ workspaceOverlayHover NOTIFY themeChanged FINAL)
    Q_PROPERTY(QColor workspaceActiveBorder READ workspaceActiveBorder NOTIFY themeChanged FINAL)

    Q_PROPERTY(int radiusPanel READ radiusPanel CONSTANT FINAL)
    Q_PROPERTY(int radiusModule READ radiusModule CONSTANT FINAL)
    Q_PROPERTY(int radiusPrompt READ radiusPrompt CONSTANT FINAL)
    Q_PROPERTY(int radiusButton READ radiusButton CONSTANT FINAL)
    Q_PROPERTY(int durationFast READ durationFast CONSTANT FINAL)
    Q_PROPERTY(int durationControl READ durationControl CONSTANT FINAL)
    Q_PROPERTY(int durationQuick READ durationQuick CONSTANT FINAL)
    Q_PROPERTY(int durationStandard READ durationStandard CONSTANT FINAL)

signals:
    void themeChanged();
private:
    QJsonObject m_colors;
    QByteArray m_themeBytes;
    void reloadTheme();
public:
    explicit StyleTokensBackend(QObject *parent = nullptr);

    QColor transparent() const;
    QColor black() const;
    QColor white() const;
    QColor clearBlack() const;
    QColor panel() const;
    QColor surfaceBorder() const;
    QColor surfaceHighlight() const;
    QColor module() const;
    QColor moduleHover() const;
    QColor track() const;
    QColor cardFillActive() const;
    QColor cardFillHover() const;
    QColor connectivityCard() const;
    QColor connectivityCardHover() const;
    QColor prompt() const;
    QColor input() const;
    QColor inputBorder() const;
    QColor secondaryButton() const;
    QColor textPrimary() const;
    QColor textPrimaryBright() const;
    QColor textSecondary() const;
    QColor textMuted() const;
    QColor textSoft() const;
    QColor textTertiary() const;
    QColor textDisabled() const;
    QColor textSubtle() const;
    QColor textDim() const;
    QColor accent() const;
    QColor accentPressed() const;
    QColor accentSoft() const;
    QColor success() const;
    QColor warning() const;
    QColor danger() const;
    QColor error() const;
    QColor disabledControl() const;
    QColor switchOff() const;
    QColor buttonFill() const;
    QColor buttonFillHover() const;
    QColor buttonFillPressed() const;
    QColor overviewCard() const;
    QColor overviewBorder() const;
    QColor overviewInnerBorder() const;
    QColor workspaceCell() const;
    QColor workspaceCellHover() const;
    QColor workspaceCellBorder() const;
    QColor workspaceCellBorderHover() const;
    QColor workspaceOverlay() const;
    QColor workspaceOverlayHover() const;
    QColor workspaceActiveBorder() const;

    int radiusPanel() const;
    int radiusModule() const;
    int radiusPrompt() const;
    int radiusButton() const;
    int durationFast() const;
    int durationControl() const;
    int durationQuick() const;
    int durationStandard() const;
};
