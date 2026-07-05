QT += quick concurrent quickcontrols2 network

# Single source of truth for the app version. main.cpp feeds it to
# setApplicationVersion(); the heartbeat and the updater both read it back.
APP_VERSION = 3.0.2
DEFINES += APP_VERSION=\\\"$${APP_VERSION}\\\"

# You can make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

HEADERS += \
    clipboardhelper.h \
    config/configparser.h \
    logger.h \
    pdfprocess/pdfprocess.h \
    games/gamesparser.h \
    activity/activitytracker.h \
    update/updater.h

SOURCES += \
    clipboardhelper.cpp \
    config/configparser.cpp \
    logger.cpp \
    main.cpp \
    pdfprocess/pdfprocess.cpp \
    games/gamesparser.cpp \
    activity/activitytracker.cpp \
    update/updater.cpp

RESOURCES += qml.qrc
RESOURCES += scripts.qrc

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH =

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH =

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

RC_FILE += app.rc


CONFIG(debug, debug|release) {
    DESTDIR = build/debug
} else {
    DESTDIR = build/release
}

