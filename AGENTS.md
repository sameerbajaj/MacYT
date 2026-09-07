# AGENTS.md — MacYT Architecture & Engineering Context

This document captures key architectural patterns, layout constraints, resolved UI/state bugs, and engineering workflows for MacYT.

## Architecture Overview

MacYT is a native macOS Swift/SwiftUI wrapper around `yt-dlp` and `ffmpeg`.

- **Target OS**: macOS 13+ (Apple Silicon & Intel)
- **Xcode Project**: `MacYT.xcodeproj`, Scheme: `MacYT`
- **Core Dependencies**: `yt-dlp` (required binary), `ffmpeg` (optional binary for muxing/audio transcoding). Binaries are located via `Process` lookup in `/opt/homebrew/bin`, `/usr/local/bin`, etc.
- **Key Models & Services**:
  - `AppViewModel`: Main orchestrator for URL loading, format inspection, download triggering, and view state transitions (`appState`).
  - `DownloadManager`: Manages active `yt-dlp` process lifecycle, standard output/error parsing, cancellation, and download state.
  - `DownloadHistoryStore`: Persists downloaded items into JSON in the user's Application Support directory.
  - `DownloadOptions`: Stores user options (output directory, format, audio extraction, subtitles, SponsorBlock). Persisted via `UserDefaults` (`MacYT_outputDirectoryPath`).
  - `VideoFormat`: Represents media formats returned by `yt-dlp -J`, categorizes resolutions up to 8K, and calculates estimated file sizes.

## UI Layout & Geometry Rules

1. **Window Boundaries**:
   - Minimum supported window size: `800 x 600`.
   - Primary split layout: Sidebar width is set to `260pt` (outer padding `24pt`), leaving ample responsive width for the main studio workspace.
   - Do not apply whole-screen linear gradient masks (like fading masks) on `ScrollView` as they cause header blurriness and visual artifacts.

2. **Narrow Viewport Handling (`ViewThatFits`)**:
   - Headers with titles and chips (e.g., `URLInputBar`) must use `ViewThatFits(in: .horizontal)` or flexible horizontal stacks so elements never collide or clip at 800pt width.
   - Multi-option pickers with 4+ options (such as audio target formats) must wrap gracefully using `ViewThatFits` rather than fixed-width segmented pickers.

3. **Table & Row Columns (`FormatSelectionView`)**:
   - Format rows must avoid large fixed-width trailing columns that force the leading title column into negative width.
   - Trailing badges and size columns use `minWidth` with trailing alignment, leaving the resolution and badges to expand flexibly.

4. **Scrollability**:
   - Diagnostic screens and settings dialogs (e.g., `DependencyStatusView`) must be wrapped in `ScrollView` to prevent button clipping on 600pt-height screens or scaled external displays.

## Download & UI State Lifecycle

- **Download Card Mounting**:
  - In `ContentView.swift`, the Studio card is presented when status is `.idle`.
  - `DownloadProgressView` remains mounted for `.downloading`, `.failed`, and `.completed` states.
  - `.completed` and `.failed` cards must include clear Dismiss options (`dismissStatus`) so users can return to their staged media without resetting their URL or session.
- **Interactive Controls During Download**:
  - URL text inputs, clipboard paste buttons, and format toggles are disabled while `viewModel.isDownloadActive` is true to prevent race conditions.

## Build & Test Commands

```bash
# Build MacYT for macOS
xcodebuild -project MacYT.xcodeproj -scheme MacYT -destination 'platform=macOS' build

# Run automated tests (Unit + UI + Launch Snapshots)
xcodebuild -project MacYT.xcodeproj -scheme MacYT -destination 'platform=macOS' test
```
