# Self-updates for MacYT

MacYT now follows the same general update model as CodexAccounts:

- GitHub Actions builds the DMG
- GitHub Releases hosts the DMG
- the app checks GitHub Releases directly
- the app downloads the DMG, swaps the `.app`, then relaunches

## What this is called

This is a custom GitHub Releases self-updater.

It is not Sparkle-based.

## How it works

### Stable releases

- Push a tag like `v1.2.0`
- Publish the GitHub Release
- Actions builds `MacYT-v1.2.0.dmg`
- MacYT compares the newest stable release tag against its current version

### Rolling latest builds

- Every push to `main` rebuilds the app
- Actions refreshes a pre-release tag named `latest`
- The app compares the release `published_at` timestamp against its stamped build timestamp
- If newer, it offers to install automatically

## App-side behavior

- MacYT checks for updates on launch
- MacYT also exposes `Check for Updates…` in the app menu
- If an update is found, MacYT can install it directly from GitHub and relaunch

## Files involved

- [MacYT/Services/UpdateChecker.swift](MacYT/Services/UpdateChecker.swift)
- [MacYT/Services/SelfUpdater.swift](MacYT/Services/SelfUpdater.swift)
- [MacYT/Services/UpdaterController.swift](MacYT/Services/UpdaterController.swift)
- [.github/workflows/release.yml](.github/workflows/release.yml)
- [scripts/create_dmg.sh](scripts/create_dmg.sh)

## Important note

For rolling updates to work correctly, CI stamps `CFBundleVersion` with a Unix timestamp. That timestamp is what the app compares against GitHub's `published_at` value for the `latest` pre-release.
