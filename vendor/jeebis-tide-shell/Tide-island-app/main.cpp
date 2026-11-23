#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "backend.hpp"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationDisplayName(QStringLiteral("Jeebis Island Settings"));
    Backend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.setInitialProperties({{"showLockSettings", app.arguments().contains("--lock-screen")}});
    engine.loadFromModule(QStringLiteral("TideIsland"), QStringLiteral("Main"));
    if (engine.rootObjects().isEmpty()) return 1;
    if (app.arguments().contains("--validate-qml")) return 0;
    return app.exec();
}
