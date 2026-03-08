# Self-updates for MacYT

MacYT now has app-side integration for Sparkle, which is the standard macOS in-app auto-update framework.

## What this is called

This update model is usually called an in-app auto-updater or Sparkle-based self-updating.

## What is already wired in

- Sparkle is linked into the app.
- The app includes a `Check for Updates…` menu command.
- Automatic update checks are enabled through Info.plist build settings.
- The feed URL is set to:
  - `https://raw.githubusercontent.com/sameerbajaj/MacYT/main/appcast.xml`

## What still needs one-time setup

### 1. Add the Sparkle public key

Replace `TODO_SET_SPARKLE_PUBLIC_KEY` in the target build settings with your Sparkle `SUPublicEDKey`.

### 2. Create signing keys

Use Sparkle's `generate_keys` tool once on your release machine.

### 3. Publish signed release archives

Each release needs a signed archive, typically a zip created from `MacYT.app`.

### 4. Generate and publish `appcast.xml`

Use Sparkle's `generate_appcast` tool so the app can discover the latest signed release.

## Important note

A normal Git push by itself is not enough for macOS self-updates. The updater needs:

1. A built app archive
2. A Sparkle signature
3. An updated `appcast.xml`
4. A reachable download URL for the archive

If you want fully automated releases, the next step is adding a GitHub Actions workflow that builds the app, signs the archive, updates `appcast.xml`, and pushes or publishes the result on release/tag creation.
