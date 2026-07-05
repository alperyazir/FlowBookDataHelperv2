; ============================================================================
;  FlowBook Helper — Inno Setup installer
; ----------------------------------------------------------------------------
;  Design (see the remote-update plan):
;   * PROGRAM FILES go to %LOCALAPPDATA%\FlowBookHelper — per-user, NO admin/UAC,
;     so the self-updater can overwrite them without elevation.
;   * The user is asked for a WORKSPACE folder. That folder gets only their
;     mutable data: empty books\ and release\, plus a Helper shortcut (.lnk) to
;     the exe. The app reads the workspace path back from workspace.txt (written
;     next to the exe), which is the installer -> app hand-off.
;
;  Build two binaries first, then assemble them into one folder = {#SourceDir}:
;    1. FlowBookDataHelper2.exe + run windeployqt on it (pulls in Qt DLLs)
;    2. updater.exe  (from updaterhelper/updaterhelper.pro) — place NEXT TO the
;       editor exe.
;    3. Copy in the shipped runtime this build expects beside the exe:
;         package\<platform>\<version>\ ,  the bundled python\ ,  scripts\ ...
;  Point SourceDir at that assembled folder and compile this script with Inno
;  Setup 6 (iscc FlowBookHelper.iss).
; ============================================================================

#define MyAppName "FlowBook Helper"
#define MyAppVersion "3.0.2"
#define MyAppExe "FlowBookDataHelper2.exe"
; Assembled program folder. IMPORTANT layout — it must be shaped exactly like the
; installed {app} tree, because the app derives programRoot() as the exe's PARENT
; folder (applicationDirPath + "\..\"):
;     {#SourceDir}\bin\      -> editor exe + Qt DLLs + updater.exe   (this is applicationDirPath)
;     {#SourceDir}\package\  -> reader builds  package\<platform>\<version>\
;     {#SourceDir}\python\   -> bundled interpreter
;     {#SourceDir}\scripts\  -> bundled scripts
; So programRoot() = {app}\ and package\/python\/scripts\/workspace.txt all sit
; directly under {app}, while the exe (and self-updated files) live in {app}\bin.
#define SourceDir "..\deploy\win"

[Setup]
AppId={{9D2F7A61-3C4B-4E9A-9C2D-FB0000000001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
; Program files: fixed, per-user LocalAppData (no admin needed, updater-friendly).
DefaultDirName={localappdata}\FlowBookHelper
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputBaseFilename=FlowBookHelper-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "tr"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Files]
; The whole assembled program tree → {app} (LocalAppData), preserving the
; bin\ + package\ + python\ + scripts\ layout described above.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Dirs]
; The user's workspace: only empty data folders live here.
Name: "{code:GetWorkspaceDir}\books"
Name: "{code:GetWorkspaceDir}\release"

[Icons]
; The launch shortcut lives IN the workspace (a .lnk, never a copy of the exe —
; a copied exe would be file-locked and unupdatable).
Name: "{code:GetWorkspaceDir}\Helper"; Filename: "{app}\bin\{#MyAppExe}"; WorkingDir: "{app}\bin"
; Start-menu shortcut too.
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\bin\{#MyAppExe}"; WorkingDir: "{app}\bin"

[Run]
Filename: "{app}\bin\{#MyAppExe}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
var
  WorkspacePage: TInputDirWizardPage;

procedure InitializeWizard;
begin
  { Ask where the user's workspace (books/release/shortcut) should live. }
  WorkspacePage := CreateInputDirPage(wpSelectDir,
    'Choose your workspace folder',
    'Where should your books and packaged output be kept?',
    'The app itself is installed automatically. This folder will hold your ' +
    'books, packaged releases, and the launch shortcut.' + #13#10 +
    'Select a folder, then click Next.',
    False, 'Helper-Workspace');
  WorkspacePage.Add('');
  WorkspacePage.Values[0] := ExpandConstant('{userdocs}\Helper-Workspace');
end;

function GetWorkspaceDir(Param: string): string;
begin
  Result := WorkspacePage.Values[0];
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  wsFile: string;
begin
  if CurStep = ssPostInstall then
  begin
    { Hand off the chosen workspace path to the app: it reads workspace.txt on
      first run (adoptWorkspaceFromInstallerIfUnset) and persists it. }
    wsFile := ExpandConstant('{app}\workspace.txt');
    SaveStringToFile(wsFile, GetWorkspaceDir(''), False);
  end;
end;
