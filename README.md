# Plume PDF

English | [中文](./README_CN.md)

Plume PDF is a cross-platform PDF reader built with Flutter + PDFium (`pdfrx`) with DeepSeek AI-assisted reading. The same reading state/controller layer is shared by desktop and mobile, while desktop and mobile use platform-specific shells.

## Features

### Reading

- Open local PDFs and keep recent files / reading progress
- Table of contents navigation
- Previous / next page and page number jump
- Zoom in / out / fit width / reset to `100%`
- Single-page / dual-page reading mode
- Reading background themes: `Default` / `Cloudy` / `Parchment` / `Eye Green`
- PDF pages are rendered continuously without vertical page gaps

### AI reading

- Configure a DeepSeek API Key and use streaming multi-turn chat
- Area selection actions: `Translate`, `Explain`, `Deep Understand`
- A selection belongs to the whole PDF viewer rather than one page, so one selection can span multiple consecutive pages
- Only one selection rectangle and one action toolbar can exist globally at a time
- Selection action toolbar placement is based on real screen space, not page coordinates; when both sides have less than 20% screen height available it falls back to the vertical center of the selection, while staying horizontally centered in the viewport
- Cross-page text extraction is merged in page order; screenshot/OCR fallback crops each selected page region and combines them into one AI context
- Vision-capable models prefer screenshot understanding and fall back to local OCR / PDF text extraction
- AI responses use streaming-aware rebuild suppression while the user is reading history, and same-frame follow-tail correction avoids bottom flicker
- Markdown rendering uses the local `gpt_markdown` fork; code blocks use syntax highlighting

### Desktop

- macOS: Finder / Dock / window-drop PDF opening, native Vision OCR
- Windows: `.pdf` file association, native OCR, keyboard shortcuts and Inno Setup installer
- Linux: `.deb` and `.rpm` release packages

### Mobile

- Native Flutter Android and iOS projects
- Android supports ARMv8-A / `arm64-v8a` only
- Dedicated mobile reader shell; desktop `HomeView` remains unchanged
- Safe-area-aware reader layout and fixed mobile toolbar
- Outline and AI use full-screen mobile routes while reusing the same `HomeController`, `PdfReaderState` and `PdfViewerController`
- Mobile AI input keeps the system bottom safe area plus an additional 20 px gap
- WiFi transfer: while the transfer page is open, a temporary local HTTP endpoint accepts PDF uploads from a computer on the same trusted LAN and opens the uploaded PDF on the phone

## Platform Status

| Platform | Status | Notes |
|---|---|---|
| macOS | Available | Native Vision OCR, PDF opener integration, DMG release packaging |
| Windows | Available | Native OCR, `.pdf` association, EXE installer packaging |
| Linux | Available | DEB + RPM release packaging |
| Android | Available | `arm64-v8a` only; CI builds arm64 debug APKs and releases produce arm64 APKs |
| iOS | Available | Simulator build verified; production signing/distribution is not configured yet |

> Android release-mode APKs currently use the repository's debug signing configuration. They are suitable for self-hosted testing, but a production keystore must be configured before Play Store or production distribution.

## Development

The project uses [FVM](https://fvm.app/) and locks Flutter in `.fvmrc`.

```bash
fvm install
fvm flutter pub get
fvm flutter test
fvm flutter analyze --no-fatal-infos

# Desktop
fvm flutter run -d windows
fvm flutter run -d macos
fvm flutter run -d linux

# Mobile
fvm flutter run -d android
fvm flutter run -d ios
fvm flutter build apk --debug --target-platform android-arm64
fvm flutter build ios --simulator
```

## CI and Releases

Two workflows protect the project:

- `Mobile CI`: runs tests, static analysis, an Android arm64 debug APK build, and an iOS simulator build.
- `Build Packages`: normal `main` pushes build/upload Linux DEB+RPM, Windows EXE, and macOS DMG artifacts.

Explicit releases additionally build an Android arm64 release APK and publish a GitHub Release. Android files are named like:

```text
plume-pdf-android-arm64-v8a-v0.0.21.apk
```

## Distribution Docs

- [Windows installer distribution](./docs/windows-installer-distribution.md)
- [Linux Debian package distribution](./docs/linux-deb-distribution.md)
- [Linux RPM package distribution](./docs/linux-rpm-distribution.md)

## Architecture Notes

- PDF rendering: `pdfrx` / PDFium
- Routing/state: GetX
- Shared reader orchestration: `HomeController` + `PdfReaderState` + `PdfViewerController`
- Desktop shell: `HomeView`
- Mobile shell: `MobileHomeView`, with full-screen Outline / AI / WiFi transfer routes
- AI orchestration: `HomeControllerAiSession`
- AI session/history/stream aggregation: `AiAgentSession`
- PDF text/image/OCR context: `PdfAiContextService`
- AI transport: `DeepSeekService` via Genkit
- Streaming UI optimization: `StreamingAiSidebarController` + `FollowTailScrollController`
- Viewer-level multi-page AI selection: `PdfViewerAreaSelectionOverlay`
- Local network PDF transfer: `WifiTransferService`

For a deeper source map, see [docs/source_code_report.md](./docs/source_code_report.md).

## Key Dependencies

- `get` — routing and state management
- `pdfrx` — PDF rendering and reader control
- `gpt_markdown` — Markdown rendering (local fork)
- `flutter_highlight` + `highlight` — code syntax highlighting
- `file_selector` — native file picker
- `desktop_drop` — desktop drag-and-drop opening
- `http` — HTTP utilities
- `genkit` + `genkit_openai` — DeepSeek streaming calls
- `shared_preferences` — recent files / reader settings persistence
- `path_provider` — application directories, including mobile WiFi transfers
