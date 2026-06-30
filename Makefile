.PHONY: get upgrade clean analyze run run-windows build-windows build-macos build-msix-windows build-installer-windows package-windows

FLUTTER := fvm flutter
DART     := fvm dart

get:
	$(FLUTTER) pub get

upgrade:
	$(FLUTTER) pub upgrade

clean:
	$(FLUTTER) clean

analyze:
	$(DART) analyze lib/

run:
	$(FLUTTER) run -d windows

run-windows:
	$(FLUTTER) run -d windows

run-macos:
	$(FLUTTER) run -d macos

build-windows:
	$(FLUTTER) build windows

build-macos:
	$(FLUTTER) build macos

build-msix-windows:
	powershell -ExecutionPolicy Bypass -File .\scripts\build_windows_msix.ps1

build-installer-windows:
	powershell -ExecutionPolicy Bypass -File .\windows\installer\build_installer.ps1

package-windows:
	powershell -ExecutionPolicy Bypass -File .\windows\installer\build_installer.ps1
