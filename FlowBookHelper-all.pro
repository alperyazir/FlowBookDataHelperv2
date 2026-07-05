# Convenience umbrella project: builds BOTH the editor app and the standalone
# update helper (updater.exe) in one shot. The existing single-target
# FlowBookDataHelper2.pro still works on its own for day-to-day development —
# use this one when producing a deployable build so updater.exe is included.
TEMPLATE = subdirs

SUBDIRS = app updater

app.file = FlowBookDataHelper2.pro
updater.file = updaterhelper/updaterhelper.pro
