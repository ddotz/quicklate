![QuickLate logo](docs/assets/quicklate-logo.png)

# QuickLate

QuickLate is a menu-bar-first macOS app for live system-audio transcription, translation, and floating captions.

**Languages:** English | [한국어](README.ko.md)

## What QuickLate Does

- Captures Mac system audio directly with ScreenCaptureKit.
- Turns playback audio into live captions with Apple Speech.
- Translates captions with Apple Translation by default.
- Helps download required Apple translation language packs in the live workspace.
- Shows floating captions above other apps while QuickLate stays out of the way.
- Supports optional GPT realtime transcription/translation when the user provides an OpenAI API key.
- Stores saved transcripts as plain text files on the Mac.

## Product Direction

QuickLate is being rebuilt from the AirTranslate open-source baseline as a new service and product identity.

The target experience is:

1. Open QuickLate from the macOS menu bar.
2. Choose source and target languages.
3. Press **Start** or **Download & Start** when an Apple language pack is missing.
4. Watch live source/translation text in the workspace or as floating captions over another app.

## Requirements

- macOS 26.0 or later
- Swift 6.2 or later
- A Mac that supports system-audio capture
- Apple Speech and Apple Translation framework availability
- Optional: OpenAI API key for GPT mode

## Build From Source

Run the app bundle:

```bash
./script/build_and_run.sh
```

Build and verify launch:

```bash
./script/build_and_run.sh --verify
```

SwiftPM checks:

```bash
swift build
swift test
```

## Saved Transcripts

Saved transcripts are plain text files under:

```text
~/Library/Application Support/QuickLate/Transcripts/*.txt
```

## Project Map

```text
Package.swift
Resources/
  AppIcon.png
  AppIcon.icns
  QuickLateLogo.png
Sources/QuickLate/
Sources/QuickLateCore/
Tests/QuickLateCoreTests/
docs/superpowers/specs/
```

## License And Attribution

QuickLate is derived from the Apache-2.0 AirTranslate baseline by himomohi. See `LICENSE` and `NOTICE`.
