# Plume PDF

English | [中文](./README_CN.md)

**Current release: v0.1.0**

Plume PDF is a cross-platform PDF reader built with Flutter + PDFium (`pdfrx`) with DeepSeek-assisted reading. Desktop and mobile share the same reader/controller layer, while platform-specific shells keep desktop and mobile interaction patterns separate.

## v0.1.0 Highlights

- Android/iOS mobile shell with safe-area-aware reader layout, full-screen Outline/AI routes, and WiFi PDF transfer
- Viewer-level AI area selection that can span consecutive PDF pages
- Streaming multi-turn AI chat with reasoning display, follow-tail scrolling, and rebuild suppression while reading history
- Reader state cleanup: page/zoom sources are separated by semantics, stale document callbacks are rejected, and recent-file progress saves use immutable snapshots
- AI sidebar lifecycle unified under `HomeController`; the former standalone streaming controller has been removed
- DeepSeek transport simplified to one OpenAI-compatible HTTP/SSE implementation; Genkit runtime dependencies were removed
- Vision fallback now retries as text only when the server explicitly rejects image/multimodal input; authentication, rate-limit, and network errors are not duplicated
- Production Dart code was reduced by 392 lines during the cleanup while regression-test code increased
- Mobile CI now runs on Ubuntu and validates tests, analysis, Android arm64 build, and APK ABI only; iOS is intentionally not built in CI for now

See [CHANGELOG.md](./CHANGELOG.md) for the full v0.1.0 release notes.

## Features

### Reading

- Open local PDFs and keep recent files / reading progress
- Table of contents navigation
- Previous / next page and page number jump
- Zoom in / out / fit width / reset to `100%`
- Single-page / dual-page reading mode
- Reading background themes: `Default` / `Cloudy` / `Parchment` / `Eye Green`
- Continuous PDF layout with no vertical page gap

### AI reading

- Configure a DeepSeek API Key and use streaming multi-turn chat
- Area-selection actions: `Translate`, `Explain`, `Deep Understand`
- A selection belongs to the whole PDF viewer rather than one page, so one selection can span multiple consecutive pages
- Only one selection rectangle and one action toolbar can exist globally at a time
- Cross-page text extraction is merged in page order; screenshot/OCR fallback crops selected regions per page and combines them into one AI context
- Vision-capable requests prefer screenshot understanding; local OCR / PDF text extraction remains the fallback context path
- PDF-derived context is treated as untrusted content, and local file directory / file-size metadata is not sent to the model
- Streaming responses keep reasoning and answer text separate
- Follow-tail scrolling uses same-frame viewport correction to avoid bottom flicker
- Expensive AI-sidebar rebuilds are deferred while the user scrolls away from the bottom and flushed when following resumes or the request reaches a terminal state
- Markdown rendering uses the local `gpt_markdown` fork; code blocks use syntax highlighting

### Desktop

- macOS: Finder / Dock / window-drop PDF opening, native Vision OCR
- Windows: `.pdf` file association, native OCR, keyboard shortcuts, and Inno Setup installer
- Linux: `.deb` and `.rpm` packages

### Mobile

- Native Flutter Android and iOS projects
- Android supports ARMv8-A / `arm64-v8a` only
- Dedicated mobile reader shell; desktop `HomeView` stays desktop-specific
- Safe-area-aware PDF layout and fixed mobile toolbar
- Outline and AI use full-screen mobile routes while reusing `HomeController`, `PdfReaderState`, and `PdfViewerController`
- Mobile AI input keeps the system bottom safe area plus an additional 20 px gap
- WiFi transfer: while the transfer page is open, a temporary local HTTP endpoint accepts validated PDF uploads from a computer on the same trusted LAN and opens the uploaded document on the phone

## Platform Status

| Platform | Status | Release path |
|---|---|---|
| macOS | Available | DMG package; native Vision OCR |
| Windows | Available | Inno Setup EXE; native OCR and `.pdf` association |
| Linux | Available | DEB + RPM |
| Android | Available | `arm64-v8a` release APK |
| iOS | Source supported / not released | iOS project remains in the repository, but current CI and GitHub Releases intentionally do not build or publish an iOS app |

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

# Android
fvm flutter run -d android
fvm flutter build apk --debug --target-platform android-arm64

# iOS remains available for local development when needed
fvm flutter run -d ios
```

## CI and Releases

### Mobile CI

Runs on Ubuntu and protects relevant PRs / `main` changes with:

```text
flutter pub get
flutter test
flutter analyze --no-fatal-infos
flutter build apk --debug --target-platform android-arm64
verify APK native libraries == arm64-v8a
```

The workflow intentionally does **not** build iOS at the moment.

### Build Packages

Normal `main` pushes build and upload desktop Actions artifacts:

- Linux: DEB + RPM
- Windows: EXE installer
- macOS: DMG

A release commit whose message is exactly `release: v<version>` is recognized automatically. The workflow creates/verifies the matching tag, additionally builds the Android arm64 release APK, waits for all release jobs, then creates the GitHub Release and uploads all packages.

For v0.1.0 the release assets are expected to include:

```text
Linux   .deb + .rpm
Windows .exe
macOS   .dmg
Android plume-pdf-android-arm64-v8a-v0.1.0.apk
```

Release notes are extracted from the matching version section in `CHANGELOG.md`.

## Distribution Docs

- [Windows installer distribution](./docs/windows-installer-distribution.md)
- [Linux Debian package distribution](./docs/linux-deb-distribution.md)
- [Linux RPM package distribution](./docs/linux-rpm-distribution.md)

## Architecture Notes

```text
HomeController
├─ reader/file/navigation orchestration
├─ HomeControllerAiSession
│    ├─ AiAgentSession
│    └─ PdfAiContextService
└─ AiSidebarController
     └─ FollowTailScrollController

AiAgentSession
    ↓
DeepSeekService
    ↓
OpenAI-compatible HTTP/SSE
```

Key points:

- PDF rendering: `pdfrx` / PDFium
- Routing/state: GetX
- Shared reader state: `HomeController` + `PdfReaderState` + `PdfViewerController`
- Page state source: `PdfViewerParams.onPageChanged`; controller listener is used for zoom synchronization
- Desktop shell: `HomeView`
- Mobile shell: `MobileHomeView`, with full-screen Outline / AI / WiFi transfer routes
- AI sidebar lifecycle: one `AiSidebarController` owned by `HomeController`
- AI session/history/stream aggregation: `AiAgentSession`
- PDF text/image/OCR context: `PdfAiContextService`
- Active AI transport: `DeepSeekService` via direct HTTP/SSE
- Future multi-model metadata is retained in `AiModelRegistry` / `AiModelConfig`
- Viewer-level multi-page AI selection: `PdfViewerAreaSelectionOverlay`
- Local-network PDF transfer: `WifiTransferService`

For a deeper source map, see [docs/source_code_report.md](./docs/source_code_report.md).

## Key Dependencies

- `get` — routing and state management
- `pdfrx` — PDF rendering and reader control
- `gpt_markdown` — Markdown rendering (local fork)
- `flutter_highlight` + `highlight` — code syntax highlighting
- `file_selector` — native file picker
- `desktop_drop` — desktop drag-and-drop opening
- `http` — DeepSeek HTTP/SSE transport and HTTP utilities
- `shared_preferences` — recent files / reader settings persistence
- `path_provider` — application directories, including mobile WiFi-transfer storage
