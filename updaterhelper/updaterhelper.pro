# Standalone update helper — builds a tiny `updater` executable that the editor
# launches to swap itself while it is closed. Build/deploy it alongside the
# editor (it must sit next to the editor exe as updater[.exe]).
# Windows-subsystem (no console): the swap runs silently with no black console
# window popping up during the update.
QT = core
CONFIG += c++17
CONFIG -= app_bundle
CONFIG -= console
TEMPLATE = app
TARGET = updater
win32: CONFIG += windows

SOURCES += main.cpp
