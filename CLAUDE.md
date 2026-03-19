# MacYT — Claude Code Init

## Project overview

MacYT is a macOS SwiftUI app for downloading YouTube videos and audio using **yt-dlp** and **FFmpeg**. It has a two-room workflow: **Studio** (inspect links, pick format) and **Downloads** (track export progress, view exported files).

## Architecture

```
MacYT/
├── MacYTApp.swift              # App entry point
├── ContentView.swift           # Root view + workspace layout (Studio / Downloads)
├── ViewModels/
│   └── AppViewModel.swift      # Central state machine (AppState enum)
├── Services/
│   ├── YTDLPService.swift      # yt-dlp process wrapper (fetch info, formats)
│   ├── DownloadManager.swift   # Download orchestration + progress parsing
│   ├── DependencyChecker.swift # Checks yt-dlp / FFmpeg installation
│   ├── SelfUpdater.swift       # In-app update logic
│   └── UpdaterController.swift # Sparkle updater integration
├── Models/
│   ├── VideoInfo.swift         # Parsed video metadata
│   ├── VideoFormat.swift       # Stream format descriptor
│   └── DownloadOptions.swift   # User-chosen export settings
├── Views/
│   ├── URLInputBar.swift
│   ├── VideoInfoCard.swift
│   ├── FormatSelectionView.swift
│   ├── DownloadProgressView.swift
│   ├── AudioExtractionView.swift
│   ├── AudioExportSummaryView.swift
│   ├── SimpleAdvancedOptionsView.swift
│   ├── DownloadOptionsPanel.swift
│   ├── ExportedFilesView.swift
│   ├── DependencyStatusView.swift
│   ├── UpdaterCommands.swift
│   └── Components/
│       ├── GradientButton.swift
│       ├── StatusBadge.swift
│       └── ShimmerView.swift
└── Theme/
    └── DesignTokens.swift      # Colors, spacing, corner radius constants
```

## Key conventions

- **Dark-only UI** — `.preferredColorScheme(.dark)` is set at the root; all colors come from `MacYTColors` / `MacYTSpacing` / `MacYTCornerRadius` in `DesignTokens.swift`.
- **AppState machine** — `AppViewModel.appState` drives what the UI shows (`.checkingDeps`, `.idle`, `.fetchingInfo`, `.showingFormats`, `.downloading`, `.completed`, `.checkingError`).
- **DownloadManager.status** — separate status enum drives the download progress UI (`.idle`, `.fetching`, `.downloading(percent, speed, eta)`, `.postProcessing`, `.completed`, `.failed`).
- **No storyboards** — pure SwiftUI, window configured in `MacYTApp.swift`.
- **Dependencies**: yt-dlp (required), FFmpeg (optional, needed for merging/conversion). Checked at launch via `DependencyChecker`.

## External tools

- `yt-dlp` — installed via Homebrew or bundled binary; invoked as a subprocess
- `ffmpeg` — optional but required for best quality video (muxing separate video+audio streams)
- Sparkle — used for in-app updates (`UpdaterController`)

## Build

Open `MacYT.xcodeproj` in Xcode and build the `MacYT` scheme. No special setup required beyond having Xcode installed.
