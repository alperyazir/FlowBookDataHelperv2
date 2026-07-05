# Standalone update helper — builds a tiny console `updater` executable that the
# editor launches to swap itself while it is closed. Build/deploy it alongside
# the editor (it must sit next to the editor exe as updater[.exe]).
QT = core
CONFIG += console c++17
CONFIG -= app_bundle
TEMPLATE = app
TARGET = updater

SOURCES += main.cpp
