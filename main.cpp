#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QDebug>
#include <QQmlContext>
#include <QDir>
#include <QIcon>
#include <QTranslator>
#include <QQuickStyle>

#include "config/configparser.h"
#include "pdfprocess/pdfprocess.h"
#include "clipboardhelper.h"
#include "games/gamesparser.h"



int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle("Fusion");

    app.setWindowIcon(QIcon(":/logo/logo.png"));

    qDebug("Application has just started :)");

    // // Config
    //ConfigParser *config = new ConfigParser;
    // if (!config->initialize()) {
    //     qDebug() << "config has errors. Exiting...";
    //     exit(1);
    // }

    auto config = ConfigParser::instance();
    PdfProcess *pdfProcess = new PdfProcess;

    QQmlApplicationEngine engine;
    config->setEngine(&engine);


    ClipboardHelper clipboardHelper;


    QString appPath;



#ifdef Q_OS_MAC // MacOS için özel kod
    appPath = QGuiApplication::applicationDirPath() + "/../../../";
#else
    appPath = QGuiApplication::applicationDirPath() + "/../";
#endif



    QQmlContext *rootContext = engine.rootContext();
    rootContext->setContextProperty("config", config);
    rootContext->setContextProperty("appPath", appPath);
    rootContext->setContextProperty("pdfProcess", pdfProcess);
    rootContext->setContextProperty("clipboardHelper", &clipboardHelper);
    rootContext->setContextProperty("gamesParser", new GamesParser());

    const QUrl url(u"qrc:/qml/main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
                         if (!obj && url == objUrl)
                             QCoreApplication::exit(-1);
                     }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
