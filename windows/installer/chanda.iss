; Chanda for Windows: Inno Setup script. The release workflow builds the app
; (flutter build windows) and compiles this with
;   iscc /DAppVersion=0.1.0 windows\installer\chanda.iss
; Installs for the current user by default (no admin prompt). Uninstalling
; leaves the encrypted data in %APPDATA%\Chanda alone.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define Release "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{B375CD29-44BF-4CC1-9123-C8C91E38993E}
AppName=Chanda
AppVersion={#AppVersion}
AppVerName=Chanda {#AppVersion}
AppPublisher=Brahma
DefaultDirName={autopf}\Chanda
DefaultGroupName=Chanda
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=Chanda-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\chanda.exe
UninstallDisplayName=Chanda
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes
; Windows 10 1809 or later (and Windows 11)
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#Release}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Chanda"; Filename: "{app}\chanda.exe"; Comment: "Shopping assistant"
Name: "{autodesktop}\Chanda"; Filename: "{app}\chanda.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\chanda.exe"; Description: "{cm:LaunchProgram,Chanda}"; Flags: nowait postinstall skipifsilent
