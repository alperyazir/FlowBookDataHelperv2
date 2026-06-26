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
#include "activity/activitytracker.h"
#include "logger.h"



int main(int argc, char *argv[])
{
    // Use FFmpeg media backend so MediaPlayer can read qrc:/ resources
    // (the default AVFoundation backend on macOS cannot).
    qputenv("QT_MEDIA_BACKEND", "ffmpeg");

    QGuiApplication app(argc, argv);

    app.setApplicationName("FlowBookDataHelper");
    app.setApplicationVersion("3.0.2");

    // Route all log output to a rotating per-launch file next to the exe
    // (keeps the last 5 sessions) so crashes / config tampering can be
    // analysed after the fact. Must run after QGuiApplication exists.
    Logger::init(5);

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



    ActivityTracker *activityTracker = new ActivityTracker(&app);
    app.installEventFilter(activityTracker);

    QQmlContext *rootContext = engine.rootContext();
    rootContext->setContextProperty("config", config);
    rootContext->setContextProperty("appPath", appPath);
    rootContext->setContextProperty("pdfProcess", pdfProcess);
    rootContext->setContextProperty("clipboardHelper", &clipboardHelper);
    rootContext->setContextProperty("gamesParser", new GamesParser());
    rootContext->setContextProperty("activityTracker", activityTracker);

    const QUrl url(u"qrc:/qml/main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
                         if (!obj && url == objUrl)
                             QCoreApplication::exit(-1);
                     }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
