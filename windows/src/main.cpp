#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QFontDatabase>
#include <QIcon>
#include <QDebug>
#include "qml_shims.hpp"
#include "lenovo_hal.hpp"

int main(int argc, char *argv[]) {
    // Configure environment
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    qputenv("QT_QUICK_FLICKABLE_WHEEL_DECELERATION", "10000");
    qputenv("QS_NO_RELOAD_POPUP", "1");

    QGuiApplication app(argc, argv);
    app.setApplicationName("LOQer");
    app.setOrganizationName("lavan8t");
    app.setApplicationVersion("1.1.0");

    // Load Google Sans Flex font
    int fontId = QFontDatabase::addApplicationFont(":/fonts/GoogleSansFlex.ttf");
    if (fontId != -1) {
        QStringList families = QFontDatabase::applicationFontFamilies(fontId);
        if (!families.isEmpty()) {
            qDebug() << "Loaded application font:" << families.first();
            QFont font(families.first(), 10);
            app.setFont(font);
        }
    } else {
        qWarning() << "Failed to load bundled GoogleSansFlex.ttf";
    }

    // Register Quickshell and Quickshell.Io shims for 100% 1:1 QML compatibility
    qmlRegisterSingletonType<QuickshellShim>("Quickshell", 1, 0, "Quickshell",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new QuickshellShim();
        });

    qmlRegisterType<QObject>("Quickshell", 1, 0, "Singleton");
    qmlRegisterType<ProcessShim>("Quickshell.Io", 1, 0, "Process");
    qmlRegisterType<StdioCollectorShim>("Quickshell.Io", 1, 0, "StdioCollector");
    qmlRegisterType<FileViewShim>("Quickshell.Io", 1, 0, "FileView");
    qmlRegisterType<IconImageShim>("Quickshell.Widgets", 1, 0, "IconImage");

    // Pre-initialize Lenovo Hardware Layer
    LenovoHal::instance();

    QQmlApplicationEngine engine;
    engine.addImportPath("qrc:/");

    const QUrl url(QStringLiteral("qrc:/loqControl.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
