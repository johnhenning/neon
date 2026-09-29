#include "controller.h"
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QSettings>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTimer>
#include <cstdio>
int main(int argc, char** argv) {
    QGuiApplication app(argc, argv);
    app.setOrganizationName("Neon");
    app.setApplicationName("Neon");
    app.setApplicationVersion("0.1.0");
    bool smoke = app.arguments().contains("--smoke-test");
    QTemporaryDir temporary;
    QString root = smoke ? temporary.path()
                         : QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
                               "/Neon Library";
    int arg = app.arguments().indexOf("--library");
    if (arg >= 0 && arg + 1 < app.arguments().size())
        root = app.arguments()[arg + 1];
    try {
        Controller controller(root);
        QQmlApplicationEngine engine;
        engine.setInitialProperties({{"backend", QVariant::fromValue(&controller)}});
        QObject::connect(
            &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
            [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
        engine.loadFromModule("Neon", "Main");
        if (smoke) {
            controller.createBook("The Quiet Sea", "A. Writer", "");
            QTimer::singleShot(1500, &app, [&] {
                if (engine.rootObjects().isEmpty())
                    return app.exit(1);
                auto* w = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
                if (!controller.save() || !w || !w->grabWindow().save("smoke.png"))
                    return app.exit(2);
                app.quit();
            });
        }
        QObject::connect(&app, &QGuiApplication::applicationStateChanged, &controller,
                         [&](Qt::ApplicationState state) {
                             if (state != Qt::ApplicationActive)
                                 controller.save();
                         });
        return app.exec();
    } catch (const std::exception& e) {
        fprintf(stderr, "Neon: %s\n", e.what());
        return 1;
    }
}
