# QuickLate Redesign Design Spec

**Date:** 2026-05-14
**Source baseline:** cloned from `https://github.com/himomohi/AirTranslate`
**Product name:** QuickLate
**Status:** Design approved for planning; production implementation has not started.

## 1. Objective

Rebuild the cloned AirTranslate baseline into **QuickLate**, a menu-bar-first macOS live transcription and translation app. The redesign prioritizes a fast live translation workspace, Apple language-pack download recovery, and floating captions that remain visible while the main app is not frontmost.

## 2. Approved Product Direction

### Primary workflow

The first-priority surface is the live caption/translation workspace:

1. User opens QuickLate from the macOS menu bar.
2. User chooses source/target language and Apple/GPT mode.
3. Before live capture starts, QuickLate checks Apple Speech and Translation asset availability.
4. If a required Apple translation language pack is missing, QuickLate offers **Download & Start** in-place.
5. When running, source and translated text remain side by side, and floating captions can stay above other apps.

### Scope level

The user selected **scope C**: internal structure may be redesigned aggressively when it supports the new UI, language-pack download recovery, menu-bar behavior, and floating captions.

## 3. Branding

### Name

Use **QuickLate** everywhere in user-facing UI, menus, windows, documentation, and release surfaces.

The upstream repository and current code still contain `AirTranslate` identifiers. During implementation, rename user-facing strings first, then decide whether deeper module/package renames are necessary and safe.

### Assets

Use the user-provided assets:

- **Logo / wordmark:** `/var/folders/n7/yq_fmcms2dd91_6h3nycfzm40000gn/T/pi-clipboard-beeb7f4f-7716-4995-9de7-4c1bc7f7bbbd.png`
  - Verified PNG, 1536×1024.
  - Visual content: QuickLate wordmark with blue Q mark.
- **Main app icon:** `/var/folders/n7/yq_fmcms2dd91_6h3nycfzm40000gn/T/pi-clipboard-46e7f0bf-72fa-46e5-9f50-11dbd3647451.png`
  - Verified PNG, 436×432.
  - Visual content: blue Q-like icon.

Implementation must copy these files into durable project resources, because `/var/folders` clipboard paths are temporary.

## 4. Visual Design Principles

The design follows Apple Human Interface Guidelines patterns observed for layout, color, materials, toolbars, sidebars, and buttons:

- Keep the main task visible and stable.
- Use sidebars/toolbars only for frequent commands or navigation.
- Use materials and layering to communicate hierarchy.
- Use color sparingly for status, feedback, and primary action.
- Prefer direct actions over deep settings sheets.

Leading productivity-app patterns considered: Linear-style command density, Raycast-style fast access, Notion/Figma-style calm workspace framing, and Slack-style persistent-but-compact utility surfaces.

## 5. Command Workspace UI

### Shell

QuickLate uses a **Command Workspace** structure:

- **Menu bar entry point:** primary app presence.
- **Central workspace:** source and translation panes in a balanced two-column layout.
- **Top action strip:** language summary, status, floating captions action, and Start/Download & Start.
- **Collapsed setup rail:** small icon-only rail at the right edge.
- **Floating caption window:** always-on-top caption surface for watching content in other apps.

### Central panes

Source pane:

- Shows original live transcript.
- Actions: copy, focus, pin/show in floating caption.

Translation pane:

- Shows translated output as the primary result.
- Actions: copy, show in floating caption, keep on top.
- **No Speak button.** Voice/speech output is not part of the core translation pane UI.

### Floating captions

Floating captions are a core feature, not a secondary add-on:

- Captions remain visible when QuickLate is not frontmost.
- Existing non-activating floating panel behavior should be preserved and strengthened.
- Caption window position, size, and display preferences should persist.
- The main window and menu bar popover should expose a clear Show Captions action.

Current code fact: `FloatingCaptionWindowController` already uses an `NSPanel` with non-activating/floating behavior, `canJoinAllSpaces`, `fullScreenAuxiliary`, and `hidesOnDeactivate = false`. Preserve this direction.

## 6. Collapsible Icon-only Setup Rail

### Default state

The Setup Rail is **collapsed by default**. It should not occupy a large persistent panel after initial configuration.

Collapsed rail behavior:

- Width target: small right-edge rail, roughly 56–72 px.
- Uses icon-only controls.
- Does not show visible `Setup` text in the rail.
- Does not use a gear as the setup/status icon, because gear conflicts with Settings.
- Uses a neutral slider/status-style icon for setup state.
- Uses a subtle attention dot only when user action is required.

### Peek and expansion

The rail can reveal a small peek panel when needed:

- Apple language pack missing.
- Download failed.
- Permission issue blocks capture or transcription.
- Unsupported language pair.

Peek panel behavior:

- Shows concise cause and one primary CTA.
- Auto-collapses after the blocking state resolves.
- Offers Collapse and Pin Open controls.
- Pin Open is user-controlled, not the default.

### Accessibility

Because the collapsed rail is icon-only, implementation must provide:

- Accessibility labels for each rail button.
- Tooltips/help text.
- Keyboard focus order.
- VoiceOver announcements for attention-dot state changes.

## 7. Apple Language-pack Download Flow

The requested download restoration means **Apple translation language-pack/model asset download**, not transcript export and not release ZIP download.

### Preflight states

QuickLate should model Apple asset state explicitly:

- `checking`
- `installed`
- `downloadRequired`
- `downloading`
- `failed`
- `unsupported`
- `unavailable`

Speech and Translation asset states should be shown separately, because users need to know whether speech recognition or translation is blocking Start.

### Start gating

Start button behavior:

- If all required assets are installed: show **Start**.
- If translation pack is missing: show **Download & Start**.
- If checking: disable duplicate Start and show checking state.
- If downloading: prevent duplicate downloads and show indeterminate progress unless Apple APIs expose real progress.
- If failed: show Retry.
- If unsupported: prompt language-pair change.
- If unavailable: offer System Settings or GPT mode where appropriate.

### Download & Start

When the user chooses Download & Start:

1. Store a start intent.
2. Begin Apple language-pack download through the asset coordinator.
3. Re-check availability after download completes.
4. If assets are installed, automatically continue into capture start.
5. If download fails, clear the start intent and show Retry.

## 8. Menu-bar-first App Presence

QuickLate is menu-bar-first by default.

### Default behavior

- Dock icon hidden by default.
- Menu bar/status item visible by default.
- User opens the main window or popover from the menu bar item.

Current code fact: the cloned baseline already has `MenuBarPanelController` creating an `NSStatusItem`, but `AppDelegate` currently calls `NSApp.setActivationPolicy(.regular)`, so the Dock icon is visible. Implementation must change this default.

### User setting

Settings must include a user-facing control:

- Label: **Show Dock icon**
- Default: off
- Off behavior: `NSApp.setActivationPolicy(.accessory)` or equivalent menu-bar-first behavior.
- On behavior: `NSApp.setActivationPolicy(.regular)` and allow normal Dock presence.

If macOS requires relaunch for a reliable transition, show a clear relaunch message. Prefer immediate switching if stable.

## 9. Internal Architecture

### Design goal

Split the current large session store into small, testable orchestration units while preserving working services.

### Proposed units

#### `WorkspaceViewModel`

Owns UI-facing state and user intents:

- Workspace layout state.
- Selected language pair.
- Start/stop/pause intents.
- Setup rail collapsed/pinned/attention state.
- Floating caption visibility state.

#### `AssetDownloadCoordinator`

Owns Apple asset availability and download flow:

- Availability refresh.
- Speech vs Translation asset separation.
- Download & Start intent.
- Duplicate-download prevention.
- Error mapping.
- Retry flow.

#### `LiveSessionCoordinator`

Owns live capture lifecycle:

- Permission checks.
- Speech captioner start/stop.
- System audio capture start/stop.
- Translation warming.
- Pause/resume.

#### `AppPresenceController`

Owns app-level presence:

- Dock hidden default.
- Menu bar item visibility.
- Settings toggle for Dock icon.
- Window activation behavior.

#### `FloatingCaptionCoordinator`

Owns floating caption window behavior:

- Open/close/toggle.
- Always-on-top behavior.
- Placement persistence.
- Size and line-count persistence.
- Visibility notifications.

#### `TranscriptRepository`

Owns saved transcript file operations:

- Load saved transcripts.
- Save session output.
- Edit saved transcript.
- Delete one/all.
- Open transcripts folder.

#### `UserSettingsStore`

Owns persisted preferences:

- Language pair.
- Caption preferences.
- Dock visibility.
- Setup rail pinned/collapsed state.
- Session duration.

### Existing code to preserve

- `ModelAvailabilityChecker` as the Apple Speech/Translation API wrapper.
- `SystemAudioCapture` for ScreenCaptureKit audio capture.
- Existing floating `NSPanel` approach.
- `TranscriptTextProcessor` pure-core testing pattern.
- Existing plain-text transcript storage model unless implementation reveals a blocking issue.

### Existing code to split

`TranslationSessionStore` currently owns live capture, model availability, downloads, settings persistence, OpenAI keys, transcript library, floating text derivation, and session state. Implementation should split responsibilities gradually behind tests rather than rewrite everything at once.

## 10. Error and Empty States

### No captions yet

Show a calm empty state in the central workspace with:

- Short explanation.
- Start or Download & Start action depending on preflight.
- Floating captions action if available.

### Missing language pack

Show:

- Attention dot on collapsed Setup Rail.
- Top strip state: Pack needed.
- Primary CTA: Download & Start.
- Peek panel with reason and Download Translation Pack.

### Downloading

Show:

- Indeterminate progress unless real progress is available.
- Disabled duplicate download CTA.
- Keep central workspace visible.

### Failed download

Show:

- Retry.
- Short technical error detail.
- Optional System Settings action if the error indicates macOS-level setup.

### Unsupported language pair

Show:

- Language-pair change suggestion.
- Do not offer a download button for unsupported pairs.

## 11. Implementation Test Strategy

Implementation must use TDD for behavior changes.

### RED tests to write first

1. Asset preflight returns `downloadRequired` when Translation is missing and Speech is installed.
2. Download & Start stores a start intent and starts capture only after availability becomes installed.
3. Download failure clears the start intent and exposes Retry.
4. Unsupported language pair does not offer download.
5. Dock visibility default is false in settings state.
6. App presence maps `showDockIcon = false` to accessory/menu-bar-first behavior and `true` to regular Dock behavior.
7. Setup Rail is collapsed by default and attention state appears only for blocking setup states.
8. Translation pane action model does not include Speak.

### Verification commands

Expected implementation verification:

```bash
swift test
swift build
./script/build_and_run.sh --verify
```

`./script/build_and_run.sh --verify` may require local macOS permissions and a GUI-capable environment. If unavailable, report the concrete blocker and keep unit/build verification separate from runtime guarantees.

## 12. Non-goals for the First Implementation Pass

- Do not add a new backend service.
- Do not add account/login features.
- Do not make transcript export/download the primary download feature.
- Do not add Speak/voice playback to the core Translation pane.
- Do not over-expand the Setup Rail into a permanent settings panel.
- Do not replace Apple Translation with GPT as the default path.

## 13. Current Approval Summary

Approved or accepted by the user:

- Product name: QuickLate.
- Primary screen: live caption/translation workspace.
- Scope C: internal structure redesign allowed.
- Apple language-pack download restoration target.
- Command Workspace direction.
- Translation pane excludes Speak.
- Floating captions must work while app is not frontmost.
- Right-side setup surface should be small, collapsible, and normally collapsed.
- Setup Rail should be simple, neutral, and icon-only.
- Dock hidden by default; menu bar only by default.
- Settings must allow showing Dock icon again.
- Section 3 architecture direction.
- Logo and app icon asset mapping as listed in this spec.
