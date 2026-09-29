#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QTimer>
#include <QQuickWindow>
int main(int argc,char **argv){QGuiApplication app(argc,argv);app.setOrganizationName("Neon");app.setApplicationName("Neon");QQmlApplicationEngine engine;QObject::connect(&engine,&QQmlApplicationEngine::objectCreationFailed,&app,[]{QCoreApplication::exit(1);},Qt::QueuedConnection);engine.loadFromModule("Neon","Main");if(app.arguments().contains("--smoke-test")){QTimer::singleShot(1500,&app,[&]{if(engine.rootObjects().isEmpty())return app.exit(1);auto *w=qobject_cast<QQuickWindow*>(engine.rootObjects().first());if(!w || !w->grabWindow().save("smoke.png"))return app.exit(2);app.quit();});}return app.exec();}
