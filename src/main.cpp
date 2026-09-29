#include "controller.h"
#include <QFile>
#include <QGuiApplication>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSettings>
#include <QStandardPaths>
#include <QStyleHints>
#include <QTemporaryDir>
#include <QTimer>
#include <cstdio>
int main(int argc, char** argv) {
#ifdef Q_OS_MACOS
    QQuickStyle::setStyle("macOS");
#endif
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
        QString appliedTheme;
        auto applyTheme = [&] {
            const auto theme = controller.settings().value("pageTheme", "system").toString();
            if (theme == appliedTheme)
                return;
            appliedTheme = theme;
            app.styleHints()->setColorScheme(theme == "night" ? Qt::ColorScheme::Dark
                                             : theme == "day" ? Qt::ColorScheme::Light
                                                              : Qt::ColorScheme::Unknown);
        };
        QObject::connect(&controller, &Controller::libraryChanged, &app, applyTheme);
        applyTheme();
        QQmlApplicationEngine engine;
        engine.setInitialProperties({{"backend", QVariant::fromValue(&controller)}});
        QObject::connect(
            &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
            [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
        engine.loadFromModule("Neon", "Main");
        if (smoke) {
            QFile sample(temporary.filePath("The Quiet Sea.md"));
            if (!sample.open(QIODevice::WriteOnly))
                return 2;
            sample.write(
                "## The arrival\n\nThe sea was quiet that morning. Mara stood at the end of the "
                "pier, holding a letter she had promised never to open.\n\nBeyond the harbor, a "
                "single light moved through the fog. It had been there yesterday, too, and the day "
                "before.\n\nShe tucked the envelope into her coat and began to walk.\n\n## Low "
                "tide\n\nBy noon the water had drawn back from the old stone steps.\n");
            sample.close();
            controller.importFile(QUrl::fromLocalFile(sample.fileName()));
            controller.updateBook({{"author", "A. Writer"}, {"wordGoal", 50000}});
            QString demoId = controller.book().value("id").toString();
            controller.createBook("The Orchard at Dusk", "A. Writer", "");
            controller.createBook("Letters from Elsewhere", "A. Writer", "");
            controller.closeBook();
            controller.updateSetting("pageTheme", "day");
            QTimer::singleShot(6500, &app, [&, demoId] {
                if (engine.rootObjects().isEmpty())
                    return app.exit(1);
                auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
                if (!window || !window->grabWindow().save("bookshelf.png"))
                    return app.exit(2);
#ifdef Q_OS_MACOS
                QProcess::execute("/usr/sbin/screencapture", {"-x", "bookshelf-desktop.png"});
#endif
                controller.openBook(demoId);
                QTimer::singleShot(1000, &app, [&] {
                    auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
                    if (!controller.save() || controller.wordCount() < 30 ||
                        controller.chapters().size() != 2 ||
                        !window->grabWindow().save("editor.png"))
                        return app.exit(3);
#ifdef Q_OS_MACOS
                    QProcess::execute("/usr/sbin/screencapture", {"-x", "editor-desktop.png"});
#endif
                    controller.updateSetting("pageTheme", "night");
                    QTimer::singleShot(800, &app, [&] {
                        auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
                        if (!window->grabWindow().save("editor-dark.png"))
                            return app.exit(4);
                        app.quit();
                    });
                });
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
