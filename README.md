# MacYT

A macOS app for downloading YouTube videos and audio. Paste a link, pick a format, export.

## What it does

MacYT wraps yt-dlp in a native macOS interface. It fetches video metadata, lets you pick a stream quality or audio-only export, and saves the file to a folder you choose. FFmpeg handles post-processing when needed — merging separate video and audio streams, or converting to MP3/M4A.

The app has two sections:

- **Studio** — paste a link, inspect the video, select a format
- **Downloads** — track progress, view exported files

## Requirements

- macOS (Apple Silicon or Intel)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — required
- [FFmpeg](https://ffmpeg.org/) — optional, but needed for best video quality and audio conversion

Install both with Homebrew:

```bash
brew install yt-dlp ffmpeg
```

## Install

Download the latest release from the [Releases](https://github.com/sameerbajaj/MacYT/releases) page, unzip, and drag MacYT.app to your Applications folder.

On first launch, macOS may block the app. Go to **System Settings → Privacy & Security** and click **Open Anyway**.

## How to use

1. Open MacYT
2. Paste a YouTube URL and press Return
3. Wait for the video info to load
4. Pick a quality, or switch to Audio mode
5. Click **Download**

Files go to the folder shown in the sidebar. You can change the destination in the options panel.

## Build from source

```bash
git clone https://github.com/sameerbajaj/MacYT.git
cd MacYT
open MacYT.xcodeproj
```

Build and run the `MacYT` scheme in Xcode. No package manager or extra setup needed.

## License

MIT
