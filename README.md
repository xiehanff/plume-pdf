# Plume PDF

English | [中文](./README_CN.md)

A high-performance desktop PDF reader built with Flutter + PDFium, featuring DeepSeek AI assistance.

## Features

- Open local PDFs with recent file history (grid layout)
- macOS: open via Finder double-click, Dock icon drag, or window drop
- Windows: open via "Open with" / double-click `.pdf` to launch and load
- Linux: release `.rpm` and `.deb` packages available for Fedora/Debian/Ubuntu-based systems
- Table of contents sidebar with chapter navigation (preserves manual selection within multi-level TOC on the same page)
- Previous / next page and page number jump
- Zoom in / out / fit width / reset to `100%`
- Single-page / dual-page reading mode
- AI selection mode
- Quick actions on selected area: `Translate`, `Explain`, `Deep Understand` (with full-page context)
- AI sidebar: configure a DeepSeek API Key and continue streaming multi-turn conversations
- AI-generated, context-aware follow-up suggestion chips shown after model replies
- Markdown rendering (gpt_markdown) + code syntax highlighting (atom-one-dark)
- Unified `OPPO Sans` font for body / Markdown text; code blocks use `JetBrainsMono`
- Vision-capable models: AI selection prioritizes screenshot-based cloud understanding; falls back to local OCR / text extraction
- Non-vision models skip screenshot path entirely, avoiding unnecessary rendering
- Reading background themes: `Default` / `Cloudy` / `Parchment` / `Eye Green`

## Platform Status

| Platform | Status | Notes |
|---|---|---|
| macOS | Available | Native Vision OCR, PDF default opener registration, Dock/Finder open and window drop |
| Windows | Available | Native OCR, keyboard shortcuts, window title, rounded icon, `.pdf` file association |
| Linux | Available | Release `.rpm` package for Fedora-based systems, native title bar/icon handling |

## Development

This project uses [fvm](https://fvm.app/) to manage the Flutter SDK version. All `flutter` / `dart` commands must be prefixed with `fvm`.

```bash
# After first clone
fvm install                       # Install Flutter version locked in .fvmrc
fvm flutter pub get               # Install dependencies

# Daily development
fvm dart analyze lib/             # Static analysis
fvm flutter run -d windows         # Run on Windows
fvm flutter run -d macos           # Run on macOS
fvm flutter run -d linux           # Run on Linux
fvm flutter build windows          # Build Windows
fvm flutter build macos            # Build macOS
fvm flutter build linux            # Build Linux
powershell -File .\make.ps1 build-msix-windows  # Build Windows MSIX
.\make.cmd package-windows         # Build Windows release + setup installer
fvm flutter build linux --release --verbose  # Build Linux release bundle
fvm flutter clean                  # Clean build artifacts
fvm flutter pub upgrade            # Upgrade dependencies
```

## Windows Distribution

- MSIX package: `powershell -File .\make.ps1 build-msix-windows`
- Inno Setup installer: `.\make.cmd package-windows`
- Windows installer for `v0.0.16`: `PlumePDF_Setup_0.0.16.exe`
- GitHub release assets are attached to the `v0.0.16` release

Related document:

- [Windows installer distribution](./docs/windows-installer-distribution.md)

## Linux Distribution

- RPM package: `plume-pdf-0.0.16-17.fc44.x86_64.rpm`
- Suitable for Fedora-based systems
- DEB package: `plume-pdf_0.0.16+17_amd64.deb`
- GitHub release assets: download the attached packages from the `v0.0.16` release
- Build RPM: `make package-rpm`
- Build DEB: `make package-deb`
- How to package: [Linux RPM package distribution](./docs/linux-rpm-distribution.md)
- Debian/Ubuntu package distribution: [Linux Debian package distribution](./docs/linux-deb-distribution.md)

## Technical Notes

- PDF rendering and interaction powered by `pdfrx` (backed by PDFium)
- Image-based PDF text recognition uses native OCR: macOS via Vision, Windows via `Windows.Media.Ocr`
- AI requests routed through Google Genkit: DeepSeek streaming chat completions
- Model capabilities configured via `assets/config/ai_models.json`; `supportsVision` flag controls screenshot understanding pipeline
- Markdown rendering uses gpt_markdown (local fork at `packages/gpt_markdown`)
- App bundle embeds `OPPO Sans` font assets; code blocks use `JetBrainsMono`
- Code highlighting uses flutter_highlight (atom-one-dark theme)
- macOS file opening integrates native `openFiles` callback for receiving PDF paths from Finder / Dock
- Windows builds use [`Directory.Build.props`](./Directory.Build.props) to disable `TrackFileAccess`, preventing `MSBuild/Tracker.exe` from hanging
- Windows release script at [`scripts/build_windows_msix.ps1`](./scripts/build_windows_msix.ps1) generates rounded Windows icons and packages as `msix`
- Windows installer script at [`windows/installer/build_installer.ps1`](./windows/installer/build_installer.ps1) packages the Release folder with Inno Setup and creates desktop/start-menu shortcuts

## Key Dependencies

- `desktop_drop` — Desktop window drag-and-drop file opening
- `get` — Routing and state management
- `pdfrx` — PDF rendering and reader control
- `gpt_markdown` — Markdown rendering (local fork)
- `flutter_highlight` + `highlight` — Code syntax highlighting
- `file_selector` — Native file picker dialog
- `hugeicons` — Toolbar and status icons
- `http` — HTTP client used by the DeepSeek service
- `genkit` + `genkit_openai` — DeepSeek streaming chat completions
- `loading_indicator` — Loading animations (ballPulse etc.)
- `shared_preferences` — Recent file persistence
