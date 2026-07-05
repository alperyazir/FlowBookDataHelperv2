# Remote update — design & operations

How the FlowBook Helper editor and its bundled reader builds update themselves
from the FlowSpy backend, with no manual file copying on each machine.

## Overview

Two artifacts update independently, each with its own version:

- **Editor** (this app). A running `.exe` is file-locked on Windows, so it is
  swapped by a tiny `updater.exe` after the editor quits, then relaunched.
- **Reader** (FlowBook builds under `package/<platform>/<version>/`). These are
  *not* running on the editor machine — they are bundled to end users at
  packaging time — so they update silently: download and extract a new version
  folder. Every target platform (win, win7-8, linux, mac) is kept fresh.

There is **no separate polling endpoint**: the existing `/api/helpers` heartbeat
(every 5s) carries an `update` manifest on its response.

```
FlowSpy  backend/updates/manifest.json ──(heartbeat res.update)──► editor: updater.applyManifest()
         backend/updates/*.zip  ◄── GET /dl/<file> ── download + SHA-256 ─┬─► package/<pf>/<ver>/   (reader, silent)
                                                                          └─► editorUpdateAvailable
                                                                                │  (UpdateBanner prompt)
                                                                                ▼
                                                              updater.applyEditorUpdate()
                                                                → download/verify/extract → temp updater.exe
                                                                → editor quits → files copied → editor relaunched
```

## Filesystem model (Windows)

Program files and user data are split so updates never touch the user's books:

- **Program root** = `%LOCALAPPDATA%\FlowBookHelper\` (per-user, no admin, so the
  updater can overwrite it). Holds the editor exe + Qt DLLs, `updater.exe`,
  `package/`, bundled `python/`, `scripts/`, and `workspace.txt`.
- **Workspace root** = user-chosen (e.g. `Documents\Helper-Workspace\`). Holds
  only `books/`, `release/`, and a `Helper.lnk` shortcut to the exe.

In code these are `ConfigParser::programRoot()` and `ConfigParser::workspaceRoot()`.
The workspace path is persisted in the encrypted identity file; if unset it
falls back to programRoot() (the classic dev layout, unchanged). First run reads
`workspace.txt` (written by the installer) via `adoptWorkspaceFromInstallerIfUnset()`.

## Components

| Piece | Where |
|-------|-------|
| Path split, workspace persistence | `config/configparser.{h,cpp}`, `main.cpp` |
| Update engine (manifest compare, download, SHA-256, extract, editor hand-off) | `update/updater.{h,cpp}` |
| Heartbeat → `updater.applyManifest(res.update)` | `qml/main.qml` |
| UI toast (progress + "update & restart" prompt) | `qml/UpdateBanner.qml` |
| Standalone swap helper (`updater.exe`) | `updaterhelper/` |
| Backend manifest + `/dl` static route | FlowSpy `backend/src/updates.ts`, `index.ts` |
| Installer | `installer/FlowBookHelper.iss` |

## Building a deployable release

Build both binaries (the umbrella project does both at once):

```
qmake FlowBookHelper-all.pro && make      # editor + updater.exe
```

Then assemble one folder for the installer's `SourceDir`, shaped like the
installed `{app}` tree (the app takes programRoot as the exe's **parent**, so the
exe must sit in a `bin\` subfolder):

```
SourceDir\
  bin\        FlowBookDataHelper2.exe + Qt DLLs (windeployqt) + updater.exe
  package\    reader builds: package\<platform>\<version>\
  python\     bundled interpreter
  scripts\    bundled scripts
```

At runtime this becomes `{app}\bin\...exe` with `programRoot() = {app}\`, so
`package\`, `python\`, `scripts\`, and `workspace.txt` all sit under `{app}`.
Editor self-update overwrites only `{app}\bin`; readers update `{app}\package`.

Compile `installer/FlowBookHelper.iss` with Inno Setup 6 (`iscc`). Set its
`SourceDir` to that assembled folder and `MyAppVersion` to the app version.

> The app version has a single source: `APP_VERSION` in `FlowBookDataHelper2.pro`
> (feeds `setApplicationVersion`, the heartbeat, and the updater's comparison).
> Bump it there and in the .iss when releasing the editor.

## Publishing an update (operator)

On the FlowSpy host, in `backend/updates/`:

1. Drop the artifact zip (see conventions below).
2. `shasum -a 256 <file>` → copy the hex.
3. Edit `manifest.json` (template: `manifest.example.json`): bump `version`, set
   `file`, paste `sha256`. Omit an artifact to leave it untouched.

The next heartbeat advertises it. `backend/updates/` is bind-mounted, so files
persist across container restarts.

**Zip conventions** (files at the zip *root*, no wrapping folder):
- Reader zip → extracted straight into `package/<platform>/<version>/`.
- Editor zip → the full editor install (exe + Qt DLLs) copied over program root.

## Security

Internal/team use: **HTTPS (Cloudflare) + SHA-256** verification before install.
No code signing / staged rollout (can be added later per-host via the `helpers`
table if needed).

## Remaining / to verify on Windows

- End-to-end reader download + extract (needs 7-Zip at `C:\Program Files\7-Zip`).
- `updater.exe` hand-off: quit → overwrite locked exe → relaunch.
- Installer run: LocalAppData program files, workspace with books/release/.lnk,
  `workspace.txt` hand-off adopted on first launch.
- Redeploy FlowSpy so `/api/helpers` returns `update` and `/dl` serves files.
```
