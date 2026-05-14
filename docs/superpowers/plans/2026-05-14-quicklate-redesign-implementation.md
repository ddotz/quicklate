# QuickLate Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved QuickLate bootstrap into the first functional redesign pass: menu-bar-first app presence, Apple language-pack Download & Start gating, icon-only collapsible setup rail, and a QuickLate command workspace.

**Architecture:** Add small tested core state machines in `QuickLateCore`, then wire them into focused app-target coordinators and SwiftUI views. Keep current capture/translation services working while moving UI orchestration out of the old monolithic store step by step.

**Tech Stack:** Swift 6.2, SwiftPM, Swift Testing, SwiftUI, AppKit, ScreenCaptureKit, Speech, Translation.

---

## File Structure

- `Sources/QuickLateCore/AppPresenceState.swift` — pure Dock/menu-bar preference mapping.
- `Sources/QuickLateCore/AssetPreflightState.swift` — pure Apple asset state, start-gating, retry, and Download & Start decisions.
- `Sources/QuickLateCore/SetupRailState.swift` — pure collapsed/pinned/attention state for the icon-only setup rail.
- `Tests/QuickLateCoreTests/AppPresenceStateTests.swift` — RED/GREEN tests for Dock-hidden default and policy intent.
- `Tests/QuickLateCoreTests/AssetPreflightStateTests.swift` — RED/GREEN tests for Apple language-pack gating.
- `Tests/QuickLateCoreTests/SetupRailStateTests.swift` — RED/GREEN tests for collapsed rail defaults and attention state.
- `Sources/QuickLate/Support/AppPresenceController.swift` — AppKit bridge applying `.accessory` or `.regular`.
- `Sources/QuickLate/Services/AssetDownloadCoordinator.swift` — app-target adapter around `ModelAvailabilityChecker.downloadAssets`.
- `Sources/QuickLate/Services/WorkspaceViewModel.swift` — observable UI-facing state and intents.
- `Sources/QuickLate/Views/CommandWorkspaceView.swift` — new central workspace shell.
- `Sources/QuickLate/Views/CollapsibleSetupRailView.swift` — icon-only setup rail and peek panel.
- `Sources/QuickLate/Views/TranscriptPaneView.swift` — reusable source/translation pane with no Speak action.
- Modify `Sources/QuickLate/App/QuickLateApp.swift` — install app presence controller and use QuickLate identity.
- Modify `Sources/QuickLate/Models/AppText.swift` — add QuickLate strings for setup rail, Dock setting, and Download & Start.
- Modify `Sources/QuickLate/Services/TranslationSessionStore.swift` — expose minimal hooks needed by `WorkspaceViewModel` while preserving capture logic.
- Modify `Sources/QuickLate/Views/ContentView.swift` — host `CommandWorkspaceView`.
- Modify `Sources/QuickLate/Views/SettingsView.swift` — add Show Dock icon toggle.
- Modify `Sources/QuickLate/Support/FloatingCaptionWindowController.swift` — persist panel frame.

---

### Task 1: App Presence Core State

**Files:**
- Create: `Sources/QuickLateCore/AppPresenceState.swift`
- Create: `Tests/QuickLateCoreTests/AppPresenceStateTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/QuickLateCoreTests/AppPresenceStateTests.swift`:

```swift
import Testing
@testable import QuickLateCore

@Suite
struct AppPresenceStateTests {
    @Test
    func dockIconIsHiddenByDefault() {
        let settings = AppPresenceSettings.default

        #expect(settings.showDockIcon == false)
        #expect(settings.activationPolicyIntent == .accessory)
    }

    @Test
    func showingDockIconUsesRegularActivationPolicy() {
        let settings = AppPresenceSettings(showDockIcon: true)

        #expect(settings.activationPolicyIntent == .regular)
    }

    @Test
    func hidingDockIconUsesAccessoryActivationPolicy() {
        let settings = AppPresenceSettings(showDockIcon: false)

        #expect(settings.activationPolicyIntent == .accessory)
    }
}
```

- [ ] **Step 2: Run RED**

Run:

```bash
swift test --filter AppPresenceStateTests
```

Expected: FAIL because `AppPresenceSettings` is not defined.

- [ ] **Step 3: Add minimal core implementation**

Create `Sources/QuickLateCore/AppPresenceState.swift`:

```swift
public enum AppActivationPolicyIntent: Equatable {
    case accessory
    case regular
}

public struct AppPresenceSettings: Equatable {
    public var showDockIcon: Bool

    public init(showDockIcon: Bool) {
        self.showDockIcon = showDockIcon
    }

    public static let `default` = AppPresenceSettings(showDockIcon: false)

    public var activationPolicyIntent: AppActivationPolicyIntent {
        showDockIcon ? .regular : .accessory
    }
}
```

- [ ] **Step 4: Run GREEN**

Run:

```bash
swift test --filter AppPresenceStateTests
```

Expected: PASS with 3 tests.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/QuickLateCore/AppPresenceState.swift Tests/QuickLateCoreTests/AppPresenceStateTests.swift
git commit -m "test: add app presence state"
```

---

### Task 2: AppKit App Presence Controller and Settings Toggle

**Files:**
- Create: `Sources/QuickLate/Support/AppPresenceController.swift`
- Modify: `Sources/QuickLate/App/QuickLateApp.swift`
- Modify: `Sources/QuickLate/Views/SettingsView.swift`
- Modify: `Sources/QuickLate/Models/AppText.swift`

- [ ] **Step 1: Add AppText strings**

Add these strings near the Settings-related strings in `Sources/QuickLate/Models/AppText.swift`:

```swift
static let appPresence = localized(english: "App Presence", korean: "앱 표시")
static let showDockIcon = localized(english: "Show Dock icon", korean: "Dock 아이콘 표시")
static let showDockIconDescription = localized(
    english: "QuickLate is menu-bar only by default. Turn this on if you want QuickLate to appear in the Dock.",
    korean: "QuickLate는 기본적으로 메뉴바에서만 표시됩니다. Dock에도 표시하려면 켜세요."
)
```

- [ ] **Step 2: Create AppPresenceController**

Create `Sources/QuickLate/Support/AppPresenceController.swift`:

```swift
import AppKit
import QuickLateCore

@MainActor
final class AppPresenceController {
    static let shared = AppPresenceController()

    private init() {}

    func apply(_ settings: AppPresenceSettings, activate: Bool) {
        switch settings.activationPolicyIntent {
        case .accessory:
            NSApp.setActivationPolicy(.accessory)
        case .regular:
            NSApp.setActivationPolicy(.regular)
            if activate {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
```

- [ ] **Step 3: Add persisted setting to TranslationSessionStore**

In `Sources/QuickLate/Services/TranslationSessionStore.swift`, add a settings key:

```swift
static let showDockIcon = "showDockIcon"
```

Add an observable property near other persisted settings:

```swift
var showDockIcon = AppPresenceSettings.default.showDockIcon {
    didSet {
        persistSelectedSettings()
        AppPresenceController.shared.apply(AppPresenceSettings(showDockIcon: showDockIcon), activate: showDockIcon)
    }
}
```

In `restoreSelectedSettings()`, add:

```swift
if defaults.object(forKey: SettingsKey.showDockIcon) != nil {
    showDockIcon = defaults.bool(forKey: SettingsKey.showDockIcon)
}
```

In `persistSelectedSettings()`, add:

```swift
defaults.set(showDockIcon, forKey: SettingsKey.showDockIcon)
```

- [ ] **Step 4: Change launch policy in QuickLateApp**

Replace the AppDelegate launch policy in `Sources/QuickLate/App/QuickLateApp.swift`:

```swift
NSApp.setActivationPolicy(.regular)
NSApp.activate(ignoringOtherApps: true)
```

with:

```swift
let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
AppPresenceController.shared.apply(AppPresenceSettings(showDockIcon: showDockIcon), activate: showDockIcon)
```

Also add:

```swift
import QuickLateCore
```

- [ ] **Step 5: Add Settings toggle**

In `SettingsView`, add a new section after the OpenAI section:

```swift
Section(AppText.appPresence) {
    Toggle(AppText.showDockIcon, isOn: $session.showDockIcon)

    Text(AppText.showDockIconDescription)
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

- [ ] **Step 6: Verify**

Run:

```bash
swift test --filter AppPresenceStateTests
swift build
```

Expected: both pass.

- [ ] **Step 7: Commit**

Run:

```bash
git add Sources/QuickLate/Support/AppPresenceController.swift Sources/QuickLate/App/QuickLateApp.swift Sources/QuickLate/Views/SettingsView.swift Sources/QuickLate/Models/AppText.swift Sources/QuickLate/Services/TranslationSessionStore.swift
git commit -m "feat: make QuickLate menu-bar first by default"
```

---

### Task 3: Asset Preflight Core State

**Files:**
- Create: `Sources/QuickLateCore/AssetPreflightState.swift`
- Create: `Tests/QuickLateCoreTests/AssetPreflightStateTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/QuickLateCoreTests/AssetPreflightStateTests.swift`:

```swift
import Testing
@testable import QuickLateCore

@Suite
struct AssetPreflightStateTests {
    @Test
    func installedSpeechAndMissingTranslationRequiresDownloadAndStart() {
        let state = AssetPreflightState(
            speech: .installed,
            translation: .downloadRequired,
            startIntent: .startAfterDownload
        )

        #expect(state.primaryAction == .downloadAndStart)
        #expect(state.blocksStart)
    }

    @Test
    func installedAssetsCanStartImmediately() {
        let state = AssetPreflightState(
            speech: .installed,
            translation: .installed,
            startIntent: .none
        )

        #expect(state.primaryAction == .start)
        #expect(!state.blocksStart)
    }

    @Test
    func unsupportedPairDoesNotOfferDownload() {
        let state = AssetPreflightState(
            speech: .installed,
            translation: .unsupported,
            startIntent: .none
        )

        #expect(state.primaryAction == .changeLanguagePair)
        #expect(state.blocksStart)
    }

    @Test
    func failedDownloadOffersRetryAndClearsStartIntent() {
        let state = AssetPreflightState(
            speech: .installed,
            translation: .failed,
            startIntent: .none
        )

        #expect(state.primaryAction == .retryDownload)
        #expect(state.startIntent == .none)
    }
}
```

- [ ] **Step 2: Run RED**

Run:

```bash
swift test --filter AssetPreflightStateTests
```

Expected: FAIL because `AssetPreflightState` is not defined.

- [ ] **Step 3: Add core state implementation**

Create `Sources/QuickLateCore/AssetPreflightState.swift`:

```swift
public enum AssetInstallState: Equatable {
    case checking
    case installed
    case downloadRequired
    case downloading
    case failed
    case unsupported
    case unavailable
}

public enum AssetStartIntent: Equatable {
    case none
    case startAfterDownload
}

public enum AssetPrimaryAction: Equatable {
    case wait
    case start
    case downloadAndStart
    case retryDownload
    case changeLanguagePair
    case openSystemSettings
}

public struct AssetPreflightState: Equatable {
    public var speech: AssetInstallState
    public var translation: AssetInstallState
    public var startIntent: AssetStartIntent

    public init(
        speech: AssetInstallState,
        translation: AssetInstallState,
        startIntent: AssetStartIntent
    ) {
        self.speech = speech
        self.translation = translation
        self.startIntent = startIntent
    }

    public var blocksStart: Bool {
        primaryAction != .start
    }

    public var primaryAction: AssetPrimaryAction {
        if speech == .checking || translation == .checking || speech == .downloading || translation == .downloading {
            return .wait
        }
        if speech == .installed && translation == .installed {
            return .start
        }
        if speech == .failed || translation == .failed {
            return .retryDownload
        }
        if speech == .unsupported || translation == .unsupported {
            return .changeLanguagePair
        }
        if speech == .unavailable || translation == .unavailable {
            return .openSystemSettings
        }
        return .downloadAndStart
    }
}
```

- [ ] **Step 4: Run GREEN**

Run:

```bash
swift test --filter AssetPreflightStateTests
```

Expected: PASS with 4 tests.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/QuickLateCore/AssetPreflightState.swift Tests/QuickLateCoreTests/AssetPreflightStateTests.swift
git commit -m "test: add asset preflight state"
```

---

### Task 4: Asset Download Coordinator and Start Gating

**Files:**
- Create: `Sources/QuickLate/Services/AssetDownloadCoordinator.swift`
- Modify: `Sources/QuickLate/Services/TranslationSessionStore.swift`
- Modify: `Sources/QuickLate/Models/AppText.swift`

- [ ] **Step 1: Add user-facing strings**

Add to `AppText`:

```swift
static let downloadAndStart = localized(english: "Download & Start", korean: "다운로드 후 시작")
static let checkingLanguagePacks = localized(english: "Checking language packs…", korean: "언어팩 확인 중…")
static let languagePackNeeded = localized(english: "Language pack needed", korean: "언어팩 필요")
static let retryDownload = localized(english: "Retry Download", korean: "다운로드 다시 시도")
static let changeLanguagePair = localized(english: "Change language pair", korean: "언어쌍 변경")
```

- [ ] **Step 2: Create coordinator**

Create `Sources/QuickLate/Services/AssetDownloadCoordinator.swift`:

```swift
import Foundation
import QuickLateCore

@MainActor
final class AssetDownloadCoordinator {
    private(set) var startIntent: AssetStartIntent = .none

    func state(from availability: ModelAvailability) -> AssetInstallState {
        switch availability.state {
        case .checking:
            return .checking
        case .installed:
            return .installed
        case .downloadRequired:
            return .downloadRequired
        case .downloading:
            return .downloading
        case .failed:
            return .failed
        case .unsupported:
            return .unsupported
        case .unavailable:
            return .unavailable
        }
    }

    func rememberStartAfterDownload() {
        startIntent = .startAfterDownload
    }

    func clearStartIntent() {
        startIntent = .none
    }
}
```

- [ ] **Step 3: Wire minimal start gating in TranslationSessionStore**

Add a property:

```swift
private let assetDownloadCoordinator = AssetDownloadCoordinator()
```

Add helper methods:

```swift
var applePreflightState: AssetPreflightState {
    AssetPreflightState(
        speech: assetDownloadCoordinator.state(from: modelAvailability(for: .appleSpeechOnly)),
        translation: assetDownloadCoordinator.state(from: modelAvailability(for: .appleOnDevice)),
        startIntent: assetDownloadCoordinator.startIntent
    )
}

func requestStartFromWorkspace() {
    switch applePreflightState.primaryAction {
    case .start:
        start()
    case .downloadAndStart:
        assetDownloadCoordinator.rememberStartAfterDownload()
        downloadModelAssets(for: .appleSystem)
    case .retryDownload:
        assetDownloadCoordinator.rememberStartAfterDownload()
        downloadModelAssets(for: .appleSystem)
    case .changeLanguagePair, .openSystemSettings, .wait:
        statusMessage = AppText.languagePackNeeded
    }
}
```

In `downloadModelAssets(for:)` after `refreshModelAvailability()`, add:

```swift
if assetDownloadCoordinator.startIntent == .startAfterDownload {
    assetDownloadCoordinator.clearStartIntent()
    start()
}
```

In the catch block, add:

```swift
assetDownloadCoordinator.clearStartIntent()
```

- [ ] **Step 4: Verify**

Run:

```bash
swift test --filter AssetPreflightStateTests
swift build
```

Expected: both pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/QuickLate/Services/AssetDownloadCoordinator.swift Sources/QuickLate/Services/TranslationSessionStore.swift Sources/QuickLate/Models/AppText.swift
git commit -m "feat: gate start on Apple language packs"
```

---

### Task 5: Setup Rail Core State and Collapsible UI

**Files:**
- Create: `Sources/QuickLateCore/SetupRailState.swift`
- Create: `Tests/QuickLateCoreTests/SetupRailStateTests.swift`
- Create: `Sources/QuickLate/Views/CollapsibleSetupRailView.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/QuickLateCoreTests/SetupRailStateTests.swift`:

```swift
import Testing
@testable import QuickLateCore

@Suite
struct SetupRailStateTests {
    @Test
    func railIsCollapsedByDefault() {
        let state = SetupRailState.default

        #expect(state.isExpanded == false)
        #expect(state.isPinnedOpen == false)
    }

    @Test
    func blockingPreflightShowsAttention() {
        let state = SetupRailState(
            isExpanded: false,
            isPinnedOpen: false,
            preflight: AssetPreflightState(
                speech: .installed,
                translation: .downloadRequired,
                startIntent: .none
            )
        )

        #expect(state.requiresAttention)
        #expect(state.shouldPeek)
    }

    @Test
    func installedAssetsDoNotPeekWhenCollapsed() {
        let state = SetupRailState(
            isExpanded: false,
            isPinnedOpen: false,
            preflight: AssetPreflightState(
                speech: .installed,
                translation: .installed,
                startIntent: .none
            )
        )

        #expect(!state.requiresAttention)
        #expect(!state.shouldPeek)
    }
}
```

- [ ] **Step 2: Run RED**

Run:

```bash
swift test --filter SetupRailStateTests
```

Expected: FAIL because `SetupRailState` is not defined.

- [ ] **Step 3: Add core implementation**

Create `Sources/QuickLateCore/SetupRailState.swift`:

```swift
public struct SetupRailState: Equatable {
    public var isExpanded: Bool
    public var isPinnedOpen: Bool
    public var preflight: AssetPreflightState

    public init(isExpanded: Bool, isPinnedOpen: Bool, preflight: AssetPreflightState) {
        self.isExpanded = isExpanded
        self.isPinnedOpen = isPinnedOpen
        self.preflight = preflight
    }

    public static let `default` = SetupRailState(
        isExpanded: false,
        isPinnedOpen: false,
        preflight: AssetPreflightState(speech: .checking, translation: .checking, startIntent: .none)
    )

    public var requiresAttention: Bool {
        switch preflight.primaryAction {
        case .downloadAndStart, .retryDownload, .changeLanguagePair, .openSystemSettings:
            return true
        case .wait, .start:
            return false
        }
    }

    public var shouldPeek: Bool {
        requiresAttention && !isExpanded && !isPinnedOpen
    }
}
```

- [ ] **Step 4: Run GREEN**

Run:

```bash
swift test --filter SetupRailStateTests
```

Expected: PASS with 3 tests.

- [ ] **Step 5: Add icon-only SwiftUI view**

Create `Sources/QuickLate/Views/CollapsibleSetupRailView.swift`:

```swift
import QuickLateCore
import SwiftUI

struct CollapsibleSetupRailView: View {
    let state: SetupRailState
    let download: () -> Void
    let toggleExpanded: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: toggleExpanded) {
                Image(systemName: "slider.horizontal.3")
                    .font(.callout.weight(.semibold))
                    .frame(width: 40, height: 38)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if state.requiresAttention {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 7, height: 7)
                                .offset(x: -5, y: 5)
                        }
                    }
            }
            .buttonStyle(.plain)
            .help(AppText.setupStatus)
            .accessibilityLabel(AppText.setupStatus)

            Button(action: download) {
                Image(systemName: "arrow.down.circle")
                    .frame(width: 40, height: 34)
            }
            .buttonStyle(.plain)
            .help(AppText.downloadModelAssets)
            .accessibilityLabel(AppText.downloadModelAssets)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .frame(width: 56)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .trailing) {
            if state.shouldPeek {
                SetupRailPeekView(download: download)
                    .offset(x: -64)
            }
        }
    }
}

private struct SetupRailPeekView: View {
    let download: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppText.languagePackNeeded)
                .font(.headline)
            Text(AppText.downloadModelAssets)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(AppText.downloadAndStart, action: download)
        }
        .padding(14)
        .frame(width: 244, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 24, y: 12)
    }
}
```

- [ ] **Step 6: Add AppText string**

Add to `AppText`:

```swift
static let setupStatus = localized(english: "Setup status", korean: "설정 상태")
```

- [ ] **Step 7: Verify**

Run:

```bash
swift test --filter SetupRailStateTests
swift build
```

Expected: both pass.

- [ ] **Step 8: Commit**

Run:

```bash
git add Sources/QuickLateCore/SetupRailState.swift Tests/QuickLateCoreTests/SetupRailStateTests.swift Sources/QuickLate/Views/CollapsibleSetupRailView.swift Sources/QuickLate/Models/AppText.swift
git commit -m "feat: add collapsible setup rail state"
```

---

### Task 6: Command Workspace Shell

**Files:**
- Create: `Sources/QuickLate/Services/WorkspaceViewModel.swift`
- Create: `Sources/QuickLate/Views/CommandWorkspaceView.swift`
- Create: `Sources/QuickLate/Views/TranscriptPaneView.swift`
- Modify: `Sources/QuickLate/Views/ContentView.swift`

- [ ] **Step 1: Create WorkspaceViewModel**

Create `Sources/QuickLate/Services/WorkspaceViewModel.swift`:

```swift
import Foundation
import Observation
import QuickLateCore

@Observable
@MainActor
final class WorkspaceViewModel {
    let session: TranslationSessionStore
    var isSetupRailExpanded = false
    var isSetupRailPinnedOpen = false

    init(session: TranslationSessionStore) {
        self.session = session
    }

    var setupRailState: SetupRailState {
        SetupRailState(
            isExpanded: isSetupRailExpanded,
            isPinnedOpen: isSetupRailPinnedOpen,
            preflight: session.applePreflightState
        )
    }

    func toggleSetupRail() {
        isSetupRailExpanded.toggle()
    }

    func requestStart() {
        session.requestStartFromWorkspace()
    }
}
```

- [ ] **Step 2: Create TranscriptPaneView without Speak action**

Create `Sources/QuickLate/Views/TranscriptPaneView.swift`:

```swift
import AppKit
import SwiftUI

struct TranscriptPaneView: View {
    let title: String
    let subtitle: String
    let text: String
    let isTranslation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button {
                    copyText()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help(AppText.copy)
                .accessibilityLabel(AppText.copy)
            }

            ScrollView {
                Text(text.isEmpty ? AppText.noCaptionsYet : text)
                    .font(isTranslation ? .title3.weight(.medium) : .title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

            HStack(spacing: 10) {
                Button(AppText.copy, action: copyText)
                Button(AppText.floatingCaptions) {}
            }
            .controlSize(.small)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private func copyText() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trimmedText, forType: .string)
    }
}
```

- [ ] **Step 3: Create CommandWorkspaceView**

Create `Sources/QuickLate/Views/CommandWorkspaceView.swift`:

```swift
import SwiftUI

struct CommandWorkspaceView: View {
    @State private var viewModel: WorkspaceViewModel

    init(session: TranslationSessionStore) {
        _viewModel = State(initialValue: WorkspaceViewModel(session: session))
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 16) {
                topBar
                HStack(spacing: 16) {
                    TranscriptPaneView(
                        title: AppText.original,
                        subtitle: AppText.originalDescription,
                        text: viewModel.session.visibleTranscript(),
                        isTranslation: false
                    )
                    TranscriptPaneView(
                        title: AppText.translation,
                        subtitle: AppText.translationDescription,
                        text: viewModel.session.visibleTranslatedText(),
                        isTranslation: true
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CollapsibleSetupRailView(
                state: viewModel.setupRailState,
                download: { viewModel.session.downloadModelAssets(for: .appleSystem) },
                toggleExpanded: { viewModel.toggleSetupRail() }
            )
        }
        .padding(20)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Live Translation")
                    .font(.title2.weight(.semibold))
                Text(viewModel.session.languageSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(AppText.floatingCaptions) {
                FloatingCaptionWindowController.toggle(session: viewModel.session)
            }
            Button(primaryActionTitle) {
                viewModel.requestStart()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var primaryActionTitle: String {
        switch viewModel.session.applePreflightState.primaryAction {
        case .downloadAndStart:
            AppText.downloadAndStart
        case .retryDownload:
            AppText.retryDownload
        case .changeLanguagePair:
            AppText.changeLanguagePair
        case .wait:
            AppText.checkingLanguagePacks
        case .openSystemSettings:
            AppText.openPrivacySettings
        case .start:
            viewModel.session.isRunning ? AppText.stop : AppText.start
        }
    }
}
```

- [ ] **Step 4: Expose visible text helpers**

If `TranslationSessionStore.visibleTranscript()` and `visibleTranslatedText()` are private, change only their access level to internal so `CommandWorkspaceView` can read them. Do not change their behavior.

- [ ] **Step 5: Replace ContentView detail**

In `Sources/QuickLate/Views/ContentView.swift`, replace the old `NavigationSplitView` detail shell with:

```swift
CommandWorkspaceView(session: session)
```

Keep the existing toast overlay.

- [ ] **Step 6: Verify**

Run:

```bash
swift build
swift test
```

Expected: both pass. Also run a text check:

```bash
grep -RIn 'Speak' Sources/QuickLate/Views Sources/QuickLate/Models || true
```

Expected: no user-facing Translation pane action named `Speak`.

- [ ] **Step 7: Commit**

Run:

```bash
git add Sources/QuickLate/Services/WorkspaceViewModel.swift Sources/QuickLate/Views/CommandWorkspaceView.swift Sources/QuickLate/Views/TranscriptPaneView.swift Sources/QuickLate/Views/ContentView.swift Sources/QuickLate/Services/TranslationSessionStore.swift
git commit -m "feat: introduce command workspace shell"
```

---

### Task 7: Floating Caption Frame Persistence

**Files:**
- Modify: `Sources/QuickLate/Support/FloatingCaptionWindowController.swift`
- Modify: `Sources/QuickLate/Models/AppText.swift` only if a new help string is needed

- [ ] **Step 1: Add persisted frame keys**

At the top of `FloatingCaptionWindowController`, add:

```swift
private enum FloatingCaptionFrameKey {
    static let x = "floatingCaptionFrameX"
    static let y = "floatingCaptionFrameY"
    static let width = "floatingCaptionFrameWidth"
    static let height = "floatingCaptionFrameHeight"
}
```

- [ ] **Step 2: Restore saved frame before first positioning**

In `open(session:)`, replace:

```swift
if window == nil {
    positionForFirstOpen(panel)
}
```

with:

```swift
if window == nil {
    restoreSavedFrame(panel) || positionForFirstOpen(panel)
}
```

Change `positionForFirstOpen` to return `Bool`:

```swift
@discardableResult
private func positionForFirstOpen(_ panel: NSPanel) -> Bool {
    guard let visibleFrame = NSScreen.main?.visibleFrame else { return false }

    let frame = panel.frame
    let x = visibleFrame.midX - frame.width / 2
    let y = visibleFrame.minY + min(180, visibleFrame.height * 0.18)
    panel.setFrameOrigin(NSPoint(x: x, y: y))
    return true
}
```

- [ ] **Step 3: Save frame on close and move**

Add methods:

```swift
func windowDidMove(_ notification: Notification) {
    guard notification.object as? NSWindow === window else { return }
    saveFrame()
}

func windowDidResize(_ notification: Notification) {
    guard notification.object as? NSWindow === window else { return }
    saveFrame()
}

private func saveFrame() {
    guard let frame = window?.frame else { return }
    let defaults = UserDefaults.standard
    defaults.set(frame.origin.x, forKey: FloatingCaptionFrameKey.x)
    defaults.set(frame.origin.y, forKey: FloatingCaptionFrameKey.y)
    defaults.set(frame.size.width, forKey: FloatingCaptionFrameKey.width)
    defaults.set(frame.size.height, forKey: FloatingCaptionFrameKey.height)
}

@discardableResult
private func restoreSavedFrame(_ panel: NSPanel) -> Bool {
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: FloatingCaptionFrameKey.x) != nil,
          defaults.object(forKey: FloatingCaptionFrameKey.y) != nil,
          defaults.object(forKey: FloatingCaptionFrameKey.width) != nil,
          defaults.object(forKey: FloatingCaptionFrameKey.height) != nil else {
        return false
    }

    let frame = NSRect(
        x: defaults.double(forKey: FloatingCaptionFrameKey.x),
        y: defaults.double(forKey: FloatingCaptionFrameKey.y),
        width: max(360, defaults.double(forKey: FloatingCaptionFrameKey.width)),
        height: max(110, defaults.double(forKey: FloatingCaptionFrameKey.height))
    )
    panel.setFrame(frame, display: false)
    return true
}
```

In `windowWillClose`, call `saveFrame()` before clearing the window.

- [ ] **Step 4: Verify**

Run:

```bash
swift build
swift test
```

Expected: both pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/QuickLate/Support/FloatingCaptionWindowController.swift
git commit -m "feat: persist floating caption frame"
```

---

### Task 8: Runtime Verification and Commit Hygiene

**Files:**
- No new source files expected.

- [ ] **Step 1: Run full verification**

Run:

```bash
swift test
swift build
./script/build_and_run.sh --verify
```

Expected:

- `swift test` passes all tests.
- `swift build` exits 0.
- `./script/build_and_run.sh --verify` exits 0 and creates `dist/QuickLate.app`.

- [ ] **Step 2: Inspect Info.plist**

Run:

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' dist/QuickLate.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' dist/QuickLate.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :NSSystemAudioCaptureUsageDescription' dist/QuickLate.app/Contents/Info.plist
```

Expected:

```text
QuickLate
QuickLate
QuickLate captures Mac system audio so it can transcribe and translate what is playing.
```

- [ ] **Step 3: Inspect repository hygiene**

Run:

```bash
git status --short --untracked-files=all
grep -RIn 'AirTranslate' Sources Tests Package.swift script Release Resources docs/assets README.md README.ko.md NOTICE || true
grep -RIn 'README.ja\|README.zh\|airtranslate-readme-hero\|himomohi/AirTranslate/releases\|AirTranslate-1.2.1' . --exclude-dir=.git --exclude-dir=.build --exclude-dir=.swiftpm --exclude-dir=dist || true
```

Expected:

- No untracked build artifacts staged for commit.
- `AirTranslate` appears only in attribution text such as `NOTICE`, `README`, or the design spec baseline notes.
- No Japanese/Chinese README links or inherited release ZIP links remain.

- [ ] **Step 4: Commit final integration changes if any**

If previous tasks left verified changes uncommitted, run:

```bash
git add -A
git diff --cached --check
git commit -m "feat: complete QuickLate redesign foundation"
```

- [ ] **Step 5: Stop before push**

Do not push to `origin` while it points to `https://github.com/himomohi/AirTranslate.git`. Report the local commit list and ask for the correct QuickLate remote before pushing.
