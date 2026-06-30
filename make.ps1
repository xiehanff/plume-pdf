param(
    [Parameter(Position=0)]
    [ValidateSet("get","upgrade","clean","analyze","run","run-windows","run-macos","build-windows","build-macos","build-msix-windows","build-installer-windows","package-windows")]
    [string]$Command = "run"
)

$Flutter = "fvm flutter"
$Dart = "fvm dart"

switch ($Command) {
    "get"            { & fvm flutter pub get }
    "upgrade"         { & fvm flutter pub upgrade }
    "clean"           { & fvm flutter clean }
    "analyze"         { & fvm dart analyze lib/ }
    "run"             { & fvm flutter run -d windows }
    "run-windows"     { & fvm flutter run -d windows }
    "run-macos"       { & fvm flutter run -d macos }
    "build-windows"   { & fvm flutter build windows }
    "build-macos"     { & fvm flutter build macos }
    "build-msix-windows" { & powershell -ExecutionPolicy Bypass -File .\scripts\build_windows_msix.ps1 }
    "build-installer-windows" { & powershell -ExecutionPolicy Bypass -File .\windows\installer\build_installer.ps1 }
    "package-windows" { & powershell -ExecutionPolicy Bypass -File .\windows\installer\build_installer.ps1 }
}
