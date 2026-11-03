# MacYT

[![Canonical Site](https://img.shields.io/badge/Canonical%20Site-sameerbajaj.com%2Ftools%2Fmacyt-blue.svg)](https://sameerbajaj.com/tools/macyt/)
[![Swift Package Index](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsameerbajaj%2FMacYT%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/sameerbajaj/MacYT)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/sameerbajaj/MacYT/blob/main/LICENSE)

A native macOS SwiftUI graphical interface and desktop wrapper for [yt-dlp](https://github.com/yt-dlp/yt-dlp) and [FFmpeg](https://ffmpeg.org/), built by [Sameer Bajaj](https://sameerbajaj.com).

Official canonical documentation and project hub:  
**[https://sameerbajaj.com/tools/macyt/](https://sameerbajaj.com/tools/macyt/)**

---

## Overview

MacYT brings the full streaming download and muxing capabilities of `yt-dlp` into a responsive, modern macOS desktop application:

- **Studio Workspace**: Inspect video metadata, extract full thumbnail art, preview resolutions up to 8K, and select specific video/audio streams.
- **Audio Extraction Mode**: Automatically extract high-fidelity audio streams and convert them directly to MP3, M4A, FLAC, AAC, or WAV via FFmpeg.
- **Download Management**: Track real-time progress, download velocity, ETA, and inspect exported files with Finder reveal actions.
- **Subtitles & SponsorBlock**: Download embedded subtitles and automatically detect and skip sponsored segments.
- **Native Swift Architecture**: Designed in SwiftUI with zero third-party framework dependencies, supporting both Apple Silicon and Intel Macs running macOS 14+.

---

## Installation

### Precompiled DMG

Download the signed disk image from the [GitHub Releases](https://github.com/sameerbajaj/MacYT/releases) page and drag `MacYT.app` to your `/Applications` directory.

### Homebrew Dependencies

MacYT leverages your local installation of `yt-dlp` and `ffmpeg`:

```bash
brew install yt-dlp ffmpeg
```

---

## Building from Source

### Using Swift Package Manager

```bash
git clone https://github.com/sameerbajaj/MacYT.git
cd MacYT
swift build -c release
```

### Using Xcode

```bash
open MacYT.xcodeproj
```

Select the `MacYT` scheme and build (`Cmd + B`).

---

## Canonical Hub & Inquiries

For documentation, release notes, and updates, visit the canonical site:  
[https://sameerbajaj.com/tools/macyt/](https://sameerbajaj.com/tools/macyt/)
