import AVFAudio
import AppKit
import QuickLateCore
import Foundation
import Observation
@preconcurrency import Translation

private enum SettingsKey {
    static let sourceLanguageID = "sourceLanguageID"
    static let targetLanguageID = "targetLanguageID"
    static let selectedModelID = "selectedModelID"
    static let openAITranscriptionModelID = "openAITranscriptionModelID"
    static let openAITranslationModelID = "openAITranslationModelID"
    static let isDubbingEnabled = "isDubbingEnabled"
    static let isTranscriptLintEnabled = "isTranscriptLintEnabled"
    static let floatingCaptionDisplayMode = "floatingCaptionDisplayMode"
    static let floatingCaptionTextSize = "floatingCaptionTextSize"
    static let floatingCaptionLineCount = "floatingCaptionLineCount"
    static let paragraphBreakSilenceInterval = "paragraphBreakSilenceInterval"
    static let savedTranscriptContentMode = "savedTranscriptContentMode"
    static let sessionDurationMode = "sessionDurationMode"
    static let showDockIcon = "showDockIcon"
}

private struct TranslationRequest {
    let line: CaptionLine
    let sourceText: String
    let source: LanguageOption
    let target: LanguageOption
}

private struct PendingCaptionPresentation {
    let lineID: UUID
    let sourceText: String
    let isFinal: Bool
    let source: LanguageOption
    let target: LanguageOption
}

@Observable
@MainActor
final class TranslationSessionStore {
    private static let maxTranslationCacheEntries = 2_000
    private static let largeTranscriptPresentationCharacterLimit = 4_000
    private static let largeTranscriptPresentationInterval: TimeInterval = RealtimeLatencyPolicy.largeTranscriptPresentationIntervalSeconds
    private static let largeTranscriptTranslationCharacterLimit = 4_000
    private static let veryLargeTranscriptTranslationCharacterLimit = 10_000
    private static let floatingCaptionEarlyRevisionWindow = RealtimeLatencyPolicy.floatingCaptionEarlyRevisionWindowSeconds
    private static let floatingCaptionImmediateExtensionCharacterLimit = 28
    private static let minimumFloatingCaptionDwell = RealtimeLatencyPolicy.minimumFloatingCaptionDwellSeconds
    private static let maximumFloatingCaptionDwell = RealtimeLatencyPolicy.maximumFloatingCaptionDwellSeconds

    var isRunning = false
    var isPaused = false
    var isDubbingEnabled = false {
        didSet {
            persistSelectedSettings()
            if isDubbingEnabled {
                if isUsingOpenAIRealtimeTranslation {
                    openAIRealtimeAudioOutput.stop()
                } else {
                    primeDubbingBaselineToCurrentTranslation()
                }
            } else {
                stopSpeaking()
                lastSpokenTranslatedText = ""
                clearSpokenTranslationUnits()
            }
        }
    }
    var sourceLanguage = LanguageOption.supported[0] {
        didSet {
            persistSelectedSettings()
            resetTranslationCache()
            resetDubbingProgress()
            refreshModelAvailability()
        }
    }
    var targetLanguage = LanguageOption.supported[1] {
        didSet {
            persistSelectedSettings()
            resetTranslationCache()
            resetDubbingProgress()
            refreshModelAvailability()
        }
    }
    var selectedModel = IntelligenceModel.appleSystem {
        didSet {
            persistSelectedSettings()
            resetTranslationCache()
            resetDubbingProgress()
            refreshModelAvailability()
        }
    }
    var hasOpenAIAPIKey = OpenAIAPIKeyStore.hasAPIKey()
    var openAITranscriptionModel = OpenAIRealtimeTranscriptionModel.off {
        didSet {
            if openAITranscriptionModel.isEnabled {
                isTranscriptLintEnabled = false
            }
            persistSelectedSettings()
            resetTranslationCache()
            refreshModelAvailability()
        }
    }
    var openAITranslationModel = OpenAIRealtimeTranslationModel.off {
        didSet {
            if openAITranslationModel.isEnabled {
                isTranscriptLintEnabled = false
            }
            persistSelectedSettings()
            resetTranslationCache()
            resetDubbingProgress()
            refreshModelAvailability()
        }
    }
    var isTranscriptLintEnabled = false {
        didSet { persistSelectedSettings() }
    }
    var floatingCaptionDisplayMode = FloatingCaptionDisplayMode.originalAndTranslation {
        didSet { persistSelectedSettings() }
    }
    var floatingCaptionTextSize = FloatingCaptionTextSize.medium {
        didSet { persistSelectedSettings() }
    }
    var floatingCaptionLineCount = FloatingCaptionLineCount.three {
        didSet { persistSelectedSettings() }
    }
    var paragraphBreakSilenceInterval = 5.0 {
        didSet { persistSelectedSettings() }
    }
    var savedTranscriptContentMode = SavedTranscriptContentMode.original {
        didSet { persistSelectedSettings() }
    }
    var sessionDurationMode = SessionDurationMode.standard {
        didSet { persistSelectedSettings() }
    }
    var showDockIcon = AppPresenceSettings.default.showDockIcon {
        didSet {
            persistSelectedSettings()
            guard !isRestoringSelectedSettings else { return }
            AppPresenceController.shared.apply(AppPresenceSettings(showDockIcon: showDockIcon), activate: showDockIcon)
        }
    }
    var statusMessage = AppText.ready
    var lastErrorMessage: String?
    var toastMessage: String?
    var toastSequence = 0
    var lines: [CaptionLine] = []
    var savedTranscripts: [SavedTranscript] = []
    var selectedSavedTranscriptID: String?
    var savedDraftSourceText = ""
    var savedDraftTranslationText = ""
    var updateCheckState = UpdateCheckState.idle
    var isFoundationTranscriptCleanupRunning = false
    private(set) var latestAudioLevel: Float?
    var modelAvailabilityByModelID = Dictionary(
        uniqueKeysWithValues: IntelligenceModel.allCases.map {
            ($0.id, ModelAvailability.checking(for: $0))
        }
    )

    private let capture = SystemAudioCapture()
    private let transcriber = LiveSpeechTranscriber()
    private let openAITranscriber = OpenAIRealtimeTranscriber()
    private let translator = AppleTranslationService()
    private let openAITranslator = OpenAITranslationService()
    private let foundationTranscriptPolisher = FoundationTranscriptPolisher()
    private let updateChecker = GitHubUpdateChecker()
    private let speechOutput = TranslatedSpeechOutput()
    private let openAIRealtimeAudioOutput = OpenAIRealtimeAudioOutput()
    private let assetDownloadCoordinator = AssetDownloadCoordinator()
    private let spellChecker = NSSpellChecker.shared
    private let spellDocumentTag = NSSpellChecker.uniqueSpellDocumentTag()
    private var audioSampleCount = 0
    private var lastRecognizedText = ""
    private var lastRecognizedWasFinal = false
    private var lastRecognitionAt = Date.distantPast
    private var currentLineID: UUID?
    private var lastCaptionPresentationUpdateAt = Date.distantPast
    private var pendingCaptionPresentation: PendingCaptionPresentation?
    private var captionPresentationTask: Task<Void, Never>?
    private var transcriptCleanupTask: Task<Void, Never>?
    private var translationTask: Task<Void, Never>?
    private var latestTranslationRequest: TranslationRequest?
    private var translationBurstStartedAt = Date.distantPast
    private var committedSourceText = ""
    private var currentPartialText = ""
    private var pendingParagraphBreakBeforePartial = false
    private var floatingCommittedSourceText = ""
    private var floatingCurrentPartialText = ""
    private var pendingFloatingParagraphBreakBeforePartial = false
    private var floatingPresentedSourceText = ""
    private var floatingQueuedSourceText = ""
    private var floatingPresentedAt = Date.distantPast
    private var floatingDisplayTranslationText = ""
    private var floatingDisplayTranslationSourceText = ""
    private var floatingQueuedTranslationText = ""
    private var floatingQueuedTranslationSourceText = ""
    private var floatingPresentationTask: Task<Void, Never>?
    private var pendingTranslationSourceText = ""
    private var translatedSegmentsBySource: [String: String] = [:]
    private var translationCacheKeyOrder: [String] = []
    private var realtimeTranslationOnlyText = ""
    private var activeAutosaveSourceText = ""
    private var activeAutosaveTranslatedText = ""
    private var isRestoringSelectedSettings = false
    var translationDownloadConfiguration: TranslationSession.Configuration?
    private var pendingAssetDownload: PendingAssetDownload?
    private var isTranslationDownloadSessionActive = false
    private var modelAvailabilityTask: Task<Void, Never>?
    private var toastDismissTask: Task<Void, Never>?
    private var lastSpokenTranslatedText = ""
    private var spokenTranslationUnitKeys: Set<String> = []
    private var spokenTranslationUnitKeyOrder: [String] = []

    private enum SavedTranscriptPart {
        case original
        case translation
    }

    private var usesLongSessionMode: Bool {
        sessionDurationMode == .thirtyMinutesOrMore
    }

    var isUsingOpenAIRealtime: Bool {
        openAITranscriptionModel.isEnabled || openAITranslationModel.isEnabled
    }

    var isUsingOpenAIRealtimeTranslation: Bool {
        openAITranslationModel.usesRealtimeAudioTranslation
    }

    private struct SavedTranscriptFile {
        let fileName: String
        let text: String
        let updatedAt: Date
    }

    private struct PendingAssetDownload {
        let modelsToUpdate: [AppleAssetModel]
        var remainingRoutes: [AppleAssetDownloadRoute]
    }

    private struct PartialSavedTranscript {
        var original: SavedTranscriptFile?
        var translation: SavedTranscriptFile?
    }

    init() {
        restoreSelectedSettings()
        capture.delegate = self
        transcriber.delegate = self
        openAITranscriber.delegate = self
        loadSavedTranscripts()
        refreshModelAvailability()
    }

    func start() {
        guard !isRunning else { return }

        resetLiveSessionState(clearsVisibleLines: true)
        isPaused = false
        setCaptionersPaused(false)
        isRunning = true
        lastErrorMessage = nil
        statusMessage = AppText.checkingScreenPermission
        E2ERuntimeReporter.report("workspaceStartRequested")

        Task {
            do {
                try capture.requestScreenRecordingAccess()
                statusMessage = AppText.checkingSpeechPermission
                try await startCaptioners()
                statusMessage = AppText.startingCapture
                let usesOpenAIRealtimeAudio = openAITranscriptionModel.isEnabled
                    || openAITranslationModel.usesRealtimeAudioTranslation
                try await capture.start(sampleRate: usesOpenAIRealtimeAudio ? 24_000 : 16_000)
                statusMessage = AppText.listeningForSpeech
                E2ERuntimeReporter.report("workspaceStartSucceeded")
                warmTranslationSession()
            } catch {
                await handleStartFailure(error)
            }
        }
    }

    func stop() {
        guard isRunning else { return }

        flushPendingCaptionPresentation()
        let didSaveTranscript = flushPendingTranscriptSave()
        resetLiveSessionState(clearsVisibleLines: false)
        isPaused = false
        setCaptionersPaused(false)
        isRunning = false
        statusMessage = AppText.stopped
        stopCaptioners()
        if didSaveTranscript {
            showToast(AppText.transcriptSavedToast)
        }

        Task {
            await capture.stop()
        }
    }

    func pause() {
        guard isRunning, !isPaused else { return }

        flushPendingCaptionPresentation()
        transcriptCleanupTask?.cancel()
        transcriptCleanupTask = nil
        commitCurrentPartial()
        organizeCurrentTranscript(sourceTextOverride: visibleTranscript())
        setCaptionersPaused(true)
        isPaused = true
        statusMessage = AppText.paused
    }

    func resume() {
        guard isRunning, isPaused else { return }

        setCaptionersPaused(false)
        isPaused = false
        lastRecognitionAt = Date()
        statusMessage = AppText.listeningForSpeech
    }

    func prepareForTermination() {
        flushPendingCaptionPresentation()
        _ = flushPendingTranscriptSave()
    }

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    var currentAppBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    func refreshUpdateAvailabilityIfNeeded() {
        guard case .idle = updateCheckState else { return }
        Task { @MainActor in
            await checkForUpdates(isUserInitiated: false)
        }
    }

    func checkForUpdates(isUserInitiated: Bool = true) async {
        guard !updateCheckState.isChecking else { return }

        updateCheckState = .checking
        do {
            let release = try await updateChecker.latestRelease()
            let availability = AppUpdatePolicy.availability(
                currentVersion: currentAppVersion,
                release: release
            )
            applyUpdateAvailability(availability, isUserInitiated: isUserInitiated)
        } catch {
            let message = error.localizedDescription
            updateCheckState = .failed(message)
            if isUserInitiated {
                showToast(AppText.updateCheckFailed(message))
            }
        }
    }

    func openUpdatePage() {
        let url = updateCheckState.releaseURL ?? AppIdentity.githubRepositoryURL
        NSWorkspace.shared.open(url)
    }

    private func applyUpdateAvailability(_ availability: AppUpdateAvailability, isUserInitiated: Bool) {
        switch availability {
        case let .updateAvailable(_, latestVersion, releaseURL):
            updateCheckState = .updateAvailable(latestVersion: latestVersion, releaseURL: releaseURL)
            showToast(AppText.updateAvailable(latestVersion: latestVersion))
        case let .upToDate(_, latestVersion, releaseURL):
            updateCheckState = .upToDate(latestVersion: latestVersion, releaseURL: releaseURL)
            if isUserInitiated {
                showToast(AppText.updateCheckUpToDate)
            }
        case let .unavailable(reason):
            let message: String
            switch reason {
            case .invalidCurrentVersion:
                message = AppText.updateCheckInvalidCurrentVersion
            case .invalidReleaseVersion:
                message = AppText.updateCheckInvalidReleaseVersion
            }
            updateCheckState = .failed(message)
            if isUserInitiated {
                showToast(AppText.updateCheckFailed(message))
            }
        }
    }

    private func handleStartFailure(_ error: Error) async {
        isRunning = false
        stopCaptioners()
        await capture.stop()

        let message = error.localizedDescription
        lastErrorMessage = message
        let failureKind = startFailureKind(for: error)
        let recoveryRoute = WorkspaceStartActionPolicy.recoveryRoute(for: failureKind)
        E2ERuntimeReporter.report(
            "workspaceStartFailure",
            fields: [
                "failureKind": String(describing: failureKind),
                "recoveryRoute": recoveryRoute.rawValue,
                "error": message
            ]
        )

        switch recoveryRoute {
        case .requestPermissionsAgain:
            requestPermissionsAgainAfterStartFailure(message)
        case .showError:
            statusMessage = AppText.startFailed(message)
        }
    }

    private func startFailureKind(for error: Error) -> WorkspaceStartFailureKind {
        if case .screenRecordingNotGranted = error as? CaptureError {
            return .permissionRequired
        }
        if case .notAuthorized = error as? SpeechError {
            return .permissionRequired
        }
        return .other
    }

    private func requestPermissionsAgainAfterStartFailure(_ message: String) {
        statusMessage = AppText.permissionRequestRepeated
        lastErrorMessage = message
        openPrivacySettings()
    }

    func saveOpenAIAPIKey(_ key: String) {
        do {
            try OpenAIAPIKeyStore.saveAPIKey(key)
            hasOpenAIAPIKey = true
            statusMessage = AppText.openAIAPIKeySaved
            refreshModelAvailability()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func removeOpenAIAPIKey() {
        do {
            try OpenAIAPIKeyStore.deleteAPIKey()
            hasOpenAIAPIKey = false
            statusMessage = AppText.openAIAPIKeyRemoved
            refreshModelAvailability()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func openTranscriptsFolder() {
        do {
            try FileManager.default.createDirectory(
                at: transcriptsDirectoryURL,
                withIntermediateDirectories: true
            )
            NSWorkspace.shared.open(transcriptsDirectoryURL)
        } catch {
            statusMessage = AppText.saveLibraryFailed(error.localizedDescription)
        }
    }

    var languageSummary: String {
        if isUsingOpenAIRealtimeTranslation {
            return AppText.openAILanguageSummary(target: targetLanguage.localizedTitle)
        }
        return AppText.languageSummary(source: sourceLanguage.localizedTitle, target: targetLanguage.localizedTitle)
    }

    func usePreferredLanguageForOpenAIOutput() {
        let preferredLanguage = LanguageOption.preferredSystemLanguage(fallback: targetLanguage)
        if targetLanguage != preferredLanguage {
            targetLanguage = preferredLanguage
        }
    }

    func useAppleDefaultMode() {
        selectedModel = .appleSystem
        openAITranscriptionModel = .off
        openAITranslationModel = .off
    }

    func useGPTRealtimeMode() {
        selectedModel = .appleSystem
        isTranscriptLintEnabled = false
        if !openAITranscriptionModel.isEnabled {
            openAITranscriptionModel = .gptRealtimeWhisper
        }
        if !openAITranslationModel.isEnabled {
            openAITranslationModel = .gptRealtimeTranslate
        }
        usePreferredLanguageForOpenAIOutput()
    }

    func modelAvailability(for model: IntelligenceModel) -> ModelAvailability {
        modelAvailabilityByModelID[model.id] ?? ModelAvailability.checking(for: model)
    }

    var applePreflightState: AssetPreflightState {
        AssetPreflightState(
            speech: assetDownloadCoordinator.state(from: modelAvailability(for: .appleSpeechOnly)),
            translation: assetDownloadCoordinator.state(from: modelAvailability(for: .appleOnDevice)),
            startIntent: assetDownloadCoordinator.startIntent
        )
    }

    func requestStartFromWorkspace() {
        let primaryAction = applePreflightState.primaryAction
        let route = WorkspaceStartActionPolicy.route(for: primaryAction)
        E2ERuntimeReporter.report(
            "workspaceStartAction",
            fields: [
                "primaryAction": String(describing: primaryAction),
                "route": route.rawValue
            ]
        )

        switch route {
        case .startCapture:
            start()
        case .downloadAssetsAndStart:
            assetDownloadCoordinator.rememberStartAfterDownload()
            downloadModelAssets(for: .appleSystem)
        case .openSystemSettings:
            statusMessage = AppText.permissionsHelp
            openPrivacySettings()
        case .changeLanguagePair:
            statusMessage = AppText.changeLanguagePair
        case .wait:
            statusMessage = AppText.checkingLanguagePacks
        }
    }

    func downloadModelAssets(for model: IntelligenceModel) {
        guard modelAvailability(for: model).state.canDownload else { return }

        let plan = AppleAssetDownloadPlan(
            model: model.appleAssetModel,
            speech: assetDownloadCoordinator.state(from: modelAvailability(for: .appleSpeechOnly)),
            translation: assetDownloadCoordinator.state(from: modelAvailability(for: .appleOnDevice))
        )
        guard !plan.routes.isEmpty else { return }

        pendingAssetDownload = PendingAssetDownload(
            modelsToUpdate: plan.modelsToMarkDownloading,
            remainingRoutes: plan.routes
        )
        markAssetDownloadModels(plan.modelsToMarkDownloading, state: .downloading, detail: AppText.modelStatusDownloading)
        E2ERuntimeReporter.report(
            "assetDownloadStarted",
            fields: [
                "model": model.id,
                "routes": plan.routes.map(\.e2eName).joined(separator: ",")
            ]
        )

        let sourceLanguage = sourceLanguage
        let targetLanguage = targetLanguage
        if plan.routes.contains(.speechAssetInventory) {
            startSpeechAssetDownload(source: sourceLanguage)
        }
        if plan.routes.contains(.swiftUITranslationTask) {
            startTranslationAssetDownload(source: sourceLanguage, target: targetLanguage)
        }
    }

    func handleTranslationDownloadSession(_ translationSession: TranslationSession) async {
        guard pendingAssetDownload?.remainingRoutes.contains(.swiftUITranslationTask) == true else { return }
        guard !isTranslationDownloadSessionActive else { return }

        isTranslationDownloadSessionActive = true
        defer { isTranslationDownloadSessionActive = false }
        E2ERuntimeReporter.report(
            "translationAssetDownloadTaskStarted",
            fields: ["canRequestDownloads": String(translationSession.canRequestDownloads)]
        )

        do {
            try await translationSession.prepareTranslation()
            E2ERuntimeReporter.report("translationAssetDownloadTaskFinished")
            completePendingAssetDownloadRoute(.swiftUITranslationTask)
        } catch {
            E2ERuntimeReporter.report(
                "translationAssetDownloadTaskFailed",
                fields: ["error": error.localizedDescription]
            )
            failPendingAssetDownload(error)
        }
    }

    private func startSpeechAssetDownload(source: LanguageOption) {
        Task {
            do {
                try await ModelAvailabilityChecker.downloadSpeechAssets(for: source)
                await MainActor.run {
                    self.completePendingAssetDownloadRoute(.speechAssetInventory)
                }
            } catch {
                await MainActor.run {
                    self.failPendingAssetDownload(error)
                }
            }
        }
    }

    private func startTranslationAssetDownload(source: LanguageOption, target: LanguageOption) {
        translationDownloadConfiguration = nil
        translationDownloadConfiguration = TranslationSession.Configuration(
            source: Locale.Language(identifier: source.id),
            target: Locale.Language(identifier: target.id)
        )
    }

    private func completePendingAssetDownloadRoute(_ route: AppleAssetDownloadRoute) {
        guard var pendingAssetDownload else { return }
        pendingAssetDownload.remainingRoutes.removeAll { $0 == route }
        self.pendingAssetDownload = pendingAssetDownload
        guard pendingAssetDownload.remainingRoutes.isEmpty else { return }

        let shouldStart = assetDownloadCoordinator.startIntent == .startAfterDownload
        translationDownloadConfiguration = nil
        self.pendingAssetDownload = nil
        assetDownloadCoordinator.clearStartIntent()
        refreshModelAvailability()
        if shouldStart {
            start()
        }
    }

    private func failPendingAssetDownload(_ error: Error) {
        guard let pendingAssetDownload else { return }
        translationDownloadConfiguration = nil
        self.pendingAssetDownload = nil
        assetDownloadCoordinator.clearStartIntent()
        markAssetDownloadModels(
            pendingAssetDownload.modelsToUpdate,
            state: .failed,
            detail: error.localizedDescription
        )
    }

    private func markAssetDownloadModels(
        _ models: [AppleAssetModel],
        state: ModelAvailabilityState,
        detail: String
    ) {
        for model in models {
            let intelligenceModel = model.intelligenceModel
            modelAvailabilityByModelID[intelligenceModel.id] = ModelAvailability(
                state: state,
                detail: detail
            )
        }
    }

    var floatingSourceText: String {
        let displayText = floatingPresentedSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !displayText.isEmpty {
            return floatingCaptionText(from: displayText)
        }

        let liveDisplayText = floatingVisibleSourceTranscript()
        if !liveDisplayText.isEmpty {
            return floatingCaptionText(from: liveDisplayText)
        }

        return floatingCaptionText(from: lines.last?.sourceText)
    }

    var floatingTranslationText: String {
        let displaySourceText = floatingPresentedSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !displaySourceText.isEmpty {
            let translatedText = floatingDisplayTranslationText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !translatedText.isEmpty, translatedText != AppText.translating else {
                return ""
            }
            guard floatingDisplayTranslationSourceText.isEmpty
                || translationSource(floatingDisplayTranslationSourceText, matches: displaySourceText)
            else {
                return ""
            }

            return floatingCaptionText(from: translatedText)
        }

        guard let lineTranslatedText = lines.last?.translatedText.trimmingCharacters(in: .whitespacesAndNewlines),
              lineTranslatedText != AppText.translating
        else {
            return ""
        }

        return floatingCaptionText(from: lineTranslatedText)
    }

    var hasFloatingCaptionContent: Bool {
        !floatingSourceText.isEmpty || !floatingTranslationText.isEmpty
    }

    var hasTranscriptContent: Bool {
        !lines.isEmpty
    }

    var shouldShowTranscript: Bool {
        isRunning || !lines.isEmpty
    }

    var selectedSavedTranscript: SavedTranscript? {
        guard let selectedSavedTranscriptID else { return nil }
        return savedTranscripts.first { $0.id == selectedSavedTranscriptID }
    }

    func selectSavedTranscript(_ id: String) {
        guard let transcript = savedTranscripts.first(where: { $0.id == id }) else { return }

        selectedSavedTranscriptID = id
        savedDraftSourceText = transcript.sourceText
        savedDraftTranslationText = transcript.translatedText ?? ""
    }

    func saveSelectedTranscriptEdits() {
        guard let selectedTranscript = selectedSavedTranscript else { return }

        let sourceText = savedDraftSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else { return }

        if selectedTranscript.isOriginalAndTranslation,
           let translationFileName = selectedTranscript.translationFileName {
            let translatedText = savedDraftTranslationText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard writeTranscriptText(sourceText, fileName: selectedTranscript.sourceFileName),
                  writeTranscriptText(translatedText, fileName: translationFileName)
            else {
                return
            }
        } else {
            guard writeTranscriptText(sourceText, fileName: selectedTranscript.sourceFileName) else { return }
        }

        let selectedID = selectedTranscript.id
        loadSavedTranscripts()
        selectSavedTranscript(selectedID)
    }

    func polishSelectedTranscriptDraftWithFoundationModel() {
        guard !isFoundationTranscriptCleanupRunning,
              let selectedTranscript = selectedSavedTranscript
        else {
            return
        }

        let selectedID = selectedTranscript.id
        let sourceText = savedDraftSourceText
        let translationText = savedDraftTranslationText
        let shouldPolishTranslation = selectedTranscript.isOriginalAndTranslation
            && translationText.rangeOfCharacter(from: .whitespacesAndNewlines.inverted) != nil
        guard sourceText.rangeOfCharacter(from: .whitespacesAndNewlines.inverted) != nil
            || shouldPolishTranslation
        else {
            return
        }

        isFoundationTranscriptCleanupRunning = true
        statusMessage = AppText.foundationModelCleanupRunning

        Task { @MainActor in
            do {
                let cleanedSource = try await foundationTranscriptPolisher.polishTranscript(sourceText)
                let cleanedTranslation = shouldPolishTranslation
                    ? try await foundationTranscriptPolisher.polishTranscript(translationText)
                    : ""

                if selectedSavedTranscriptID == selectedID {
                    if !cleanedSource.isEmpty {
                        savedDraftSourceText = cleanedSource
                    }
                    if shouldPolishTranslation {
                        savedDraftTranslationText = cleanedTranslation
                    }
                    statusMessage = AppText.foundationModelCleanupComplete
                }
            } catch {
                statusMessage = AppText.foundationModelCleanupFailed(error.localizedDescription)
            }

            isFoundationTranscriptCleanupRunning = false
        }
    }

    func deleteSelectedTranscript() {
        guard let selectedTranscript = selectedSavedTranscript else { return }

        savedTranscripts.removeAll { $0.id == selectedTranscript.id }
        try? FileManager.default.removeItem(at: transcriptURL(fileName: selectedTranscript.sourceFileName))
        if let translationFileName = selectedTranscript.translationFileName {
            try? FileManager.default.removeItem(at: transcriptURL(fileName: translationFileName))
        }
        self.selectedSavedTranscriptID = nil
        savedDraftSourceText = ""
        savedDraftTranslationText = ""
    }

    func deleteAllSavedTranscripts() {
        do {
            try FileManager.default.createDirectory(
                at: transcriptsDirectoryURL,
                withIntermediateDirectories: true
            )
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: transcriptsDirectoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for fileURL in fileURLs where fileURL.pathExtension == "txt" {
                try FileManager.default.removeItem(at: fileURL)
            }
            savedTranscripts.removeAll()
            selectedSavedTranscriptID = nil
            savedDraftSourceText = ""
            savedDraftTranslationText = ""
            activeAutosaveSourceText = ""
            activeAutosaveTranslatedText = ""
        } catch {
            statusMessage = AppText.saveLibraryFailed(error.localizedDescription)
        }
    }

    private func startCaptioners() async throws {
        if openAITranslationModel.usesRealtimeAudioTranslation {
            try await openAITranscriber.startRealtimeTranslationOnly(
                language: targetLanguage,
                model: openAITranslationModel
            )
        } else if openAITranscriptionModel.isEnabled {
            try await openAITranscriber.start(language: sourceLanguage, model: openAITranscriptionModel)
        } else {
            try await transcriber.start(languages: [sourceLanguage])
        }
    }

    private func stopCaptioners() {
        transcriber.stop()
        openAITranscriber.stop()
    }

    private func setCaptionersPaused(_ isPaused: Bool) {
        transcriber.setPaused(isPaused)
        openAITranscriber.setPaused(isPaused)
    }

    private func resetLiveSessionState(clearsVisibleLines: Bool) {
        audioSampleCount = 0
        latestAudioLevel = nil
        lastRecognizedText = ""
        lastRecognizedWasFinal = false
        currentLineID = nil
        lastCaptionPresentationUpdateAt = Date.distantPast
        pendingCaptionPresentation = nil
        captionPresentationTask?.cancel()
        captionPresentationTask = nil
        committedSourceText = ""
        currentPartialText = ""
        pendingParagraphBreakBeforePartial = false
        floatingPresentationTask?.cancel()
        floatingPresentationTask = nil
        if clearsVisibleLines {
            floatingCommittedSourceText = ""
            floatingCurrentPartialText = ""
            pendingFloatingParagraphBreakBeforePartial = false
            floatingPresentedSourceText = ""
            floatingQueuedSourceText = ""
            floatingPresentedAt = Date.distantPast
            floatingDisplayTranslationText = ""
            floatingDisplayTranslationSourceText = ""
            floatingQueuedTranslationText = ""
            floatingQueuedTranslationSourceText = ""
        } else {
            rehydrateFloatingCaptionDisplayFromCurrentLine()
        }
        pendingTranslationSourceText = ""
        latestTranslationRequest = nil
        translationBurstStartedAt = Date.distantPast
        resetTranslationCache()
        realtimeTranslationOnlyText = ""
        activeAutosaveSourceText = ""
        activeAutosaveTranslatedText = ""
        stopSpeaking()
        lastSpokenTranslatedText = ""
        clearSpokenTranslationUnits()
        translationTask?.cancel()
        translationTask = nil
        transcriptCleanupTask?.cancel()
        transcriptCleanupTask = nil

        if clearsVisibleLines {
            lines.removeAll()
        }
    }

    private func warmTranslationSession() {
        guard !openAITranslationModel.isEnabled else { return }

        let warmSourceLanguage = sourceLanguage
        let warmTargetLanguage = targetLanguage
        let warmSelectedModel = selectedModel

        Task { @MainActor in
            do {
                try await translator.prepare(
                    source: warmSourceLanguage,
                    target: warmTargetLanguage,
                    model: warmSelectedModel
                )
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func refreshModelAvailability() {
        let sourceLanguage = sourceLanguage
        let targetLanguage = targetLanguage

        modelAvailabilityTask?.cancel()
        modelAvailabilityByModelID = Dictionary(
            uniqueKeysWithValues: IntelligenceModel.allCases.map {
                ($0.id, ModelAvailability.checking(for: $0))
            }
        )

        modelAvailabilityTask = Task { [weak self, sourceLanguage, targetLanguage] in
            let availabilityByModelID = await ModelAvailabilityChecker.availability(
                source: sourceLanguage,
                target: targetLanguage
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self?.modelAvailabilityByModelID = availabilityByModelID
            }
        }
    }

    private func restoreSelectedSettings() {
        isRestoringSelectedSettings = true
        defer { isRestoringSelectedSettings = false }

        let defaults = UserDefaults.standard
        if let sourceLanguageID = defaults.string(forKey: SettingsKey.sourceLanguageID),
           let language = LanguageOption.supported.first(where: { $0.id == sourceLanguageID }) {
            sourceLanguage = language
        }
        if let targetLanguageID = defaults.string(forKey: SettingsKey.targetLanguageID),
           let language = LanguageOption.supported.first(where: { $0.id == targetLanguageID }) {
            targetLanguage = language
        }
        if let modelID = defaults.string(forKey: SettingsKey.selectedModelID),
           let model = IntelligenceModel(rawValue: modelID) {
            selectedModel = model == .appleOnDevice ? .appleSystem : model
        }
        if let modelID = defaults.string(forKey: SettingsKey.openAITranscriptionModelID),
           let model = OpenAIRealtimeTranscriptionModel(rawValue: modelID) {
            openAITranscriptionModel = model
        }
        if let modelID = defaults.string(forKey: SettingsKey.openAITranslationModelID),
           let model = OpenAIRealtimeTranslationModel(rawValue: modelID) {
            openAITranslationModel = model
        }
        if defaults.object(forKey: SettingsKey.isDubbingEnabled) != nil {
            isDubbingEnabled = defaults.bool(forKey: SettingsKey.isDubbingEnabled)
        }
        if defaults.object(forKey: SettingsKey.isTranscriptLintEnabled) != nil {
            isTranscriptLintEnabled = defaults.bool(forKey: SettingsKey.isTranscriptLintEnabled)
        }
        if let modeID = defaults.string(forKey: SettingsKey.floatingCaptionDisplayMode),
           let mode = FloatingCaptionDisplayMode(rawValue: modeID) {
            floatingCaptionDisplayMode = mode
        }
        if let sizeID = defaults.string(forKey: SettingsKey.floatingCaptionTextSize),
           let size = FloatingCaptionTextSize(rawValue: sizeID) {
            floatingCaptionTextSize = size
        }
        if let lineCountID = defaults.string(forKey: SettingsKey.floatingCaptionLineCount),
           let rawValue = Int(lineCountID),
           let lineCount = FloatingCaptionLineCount(rawValue: rawValue) {
            floatingCaptionLineCount = lineCount
        }
        if defaults.object(forKey: SettingsKey.paragraphBreakSilenceInterval) != nil {
            paragraphBreakSilenceInterval = min(
                max(defaults.double(forKey: SettingsKey.paragraphBreakSilenceInterval), 1),
                15
            )
        }
        if let contentModeID = defaults.string(forKey: SettingsKey.savedTranscriptContentMode),
           let contentMode = SavedTranscriptContentMode(rawValue: contentModeID) {
            savedTranscriptContentMode = contentMode
        }
        if let durationModeID = defaults.string(forKey: SettingsKey.sessionDurationMode),
           let durationMode = SessionDurationMode(rawValue: durationModeID) {
            sessionDurationMode = durationMode
        }
        if defaults.object(forKey: SettingsKey.showDockIcon) != nil {
            showDockIcon = defaults.bool(forKey: SettingsKey.showDockIcon)
        }
    }

    private func persistSelectedSettings() {
        guard !isRestoringSelectedSettings else { return }

        let defaults = UserDefaults.standard
        defaults.set(sourceLanguage.id, forKey: SettingsKey.sourceLanguageID)
        defaults.set(targetLanguage.id, forKey: SettingsKey.targetLanguageID)
        defaults.set(selectedModel.id, forKey: SettingsKey.selectedModelID)
        defaults.set(openAITranscriptionModel.id, forKey: SettingsKey.openAITranscriptionModelID)
        defaults.set(openAITranslationModel.id, forKey: SettingsKey.openAITranslationModelID)
        defaults.set(isDubbingEnabled, forKey: SettingsKey.isDubbingEnabled)
        defaults.set(isTranscriptLintEnabled, forKey: SettingsKey.isTranscriptLintEnabled)
        defaults.set(floatingCaptionDisplayMode.id, forKey: SettingsKey.floatingCaptionDisplayMode)
        defaults.set(floatingCaptionTextSize.id, forKey: SettingsKey.floatingCaptionTextSize)
        defaults.set(floatingCaptionLineCount.id, forKey: SettingsKey.floatingCaptionLineCount)
        defaults.set(paragraphBreakSilenceInterval, forKey: SettingsKey.paragraphBreakSilenceInterval)
        defaults.set(savedTranscriptContentMode.id, forKey: SettingsKey.savedTranscriptContentMode)
        defaults.set(sessionDurationMode.id, forKey: SettingsKey.sessionDurationMode)
        defaults.set(showDockIcon, forKey: SettingsKey.showDockIcon)
    }

    private func floatingCaptionText(from text: String?) -> String {
        guard let text else { return "" }

        return text.floatingCaptionTail(maxLines: floatingCaptionLineCount.rawValue)
    }

    private func loadSavedTranscripts() {
        do {
            try FileManager.default.createDirectory(
                at: transcriptsDirectoryURL,
                withIntermediateDirectories: true
            )
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: transcriptsDirectoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            let transcriptFiles = fileURLs
                .filter { $0.pathExtension == "txt" }
                .compactMap { fileURL -> SavedTranscriptFile? in
                    guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
                        return nil
                    }
                    let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                    return SavedTranscriptFile(
                        fileName: fileURL.lastPathComponent,
                        text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                        updatedAt: values?.contentModificationDate ?? Date.distantPast
                    )
                }
            savedTranscripts = groupedSavedTranscripts(from: transcriptFiles)
            sortSavedTranscripts()
        } catch {
            savedTranscripts = []
        }
    }

    private func groupedSavedTranscripts(from files: [SavedTranscriptFile]) -> [SavedTranscript] {
        var standaloneTranscripts: [SavedTranscript] = []
        var partialTranscripts: [String: PartialSavedTranscript] = [:]

        for file in files {
            if let variant = transcriptVariantInfo(file.fileName) {
                var partial = partialTranscripts[variant.baseFileName] ?? PartialSavedTranscript()
                switch variant.part {
                case .original:
                    partial.original = file
                case .translation:
                    partial.translation = file
                }
                partialTranscripts[variant.baseFileName] = partial
            } else {
                standaloneTranscripts.append(
                    SavedTranscript(
                        fileName: file.fileName,
                        sourceText: file.text,
                        updatedAt: file.updatedAt
                    )
                )
            }
        }

        for (baseFileName, partial) in partialTranscripts {
            if let original = partial.original, let translation = partial.translation {
                standaloneTranscripts.append(
                    SavedTranscript(
                        id: baseFileName,
                        sourceFileName: original.fileName,
                        translationFileName: translation.fileName,
                        sourceText: original.text,
                        translatedText: translation.text,
                        updatedAt: max(original.updatedAt, translation.updatedAt)
                    )
                )
            } else if let original = partial.original {
                standaloneTranscripts.append(
                    SavedTranscript(
                        fileName: original.fileName,
                        sourceText: original.text,
                        updatedAt: original.updatedAt
                    )
                )
            } else if let translation = partial.translation {
                standaloneTranscripts.append(
                    SavedTranscript(
                        fileName: translation.fileName,
                        sourceText: translation.text,
                        updatedAt: translation.updatedAt
                    )
                )
            }
        }

        return standaloneTranscripts
    }

    private func stageTranscriptForSave(_ sourceText: String, translatedText: String? = nil) {
        let sourceText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else { return }

        activeAutosaveSourceText = sourceText
        if let translatedText {
            let translatedText = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !translatedText.isEmpty, translatedText != AppText.translating {
                activeAutosaveTranslatedText = translatedText
            }
        }
    }

    @discardableResult
    private func flushPendingTranscriptSave() -> Bool {
        let currentSourceText = visibleTranscript().trimmingCharacters(in: .whitespacesAndNewlines)
        if !currentSourceText.isEmpty {
            activeAutosaveSourceText = currentSourceText
        }

        let sourceText = activeAutosaveSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else { return false }

        let updatedAt = Date()
        let baseFileName = makeTranscriptFileName(for: sourceText, date: updatedAt)
        let savedFiles = savedTranscriptFiles(
            sourceText: sourceText,
            translatedText: activeAutosaveTranslatedText,
            baseFileName: baseFileName
        )

        for savedFile in savedFiles {
            guard writeTranscriptText(savedFile.text, fileName: savedFile.fileName) else {
                return false
            }
        }

        activeAutosaveSourceText = ""
        activeAutosaveTranslatedText = ""
        loadSavedTranscripts()
        return true
    }

    private func savedTranscriptFiles(
        sourceText: String,
        translatedText: String,
        baseFileName: String
    ) -> [(fileName: String, text: String)] {
        let sourceText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let translatedText = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch savedTranscriptContentMode {
        case .original:
            return [(baseFileName, sourceText)]
        case .translation:
            return [(baseFileName, translatedText.isEmpty ? sourceText : translatedText)]
        case .originalAndTranslation:
            guard !translatedText.isEmpty else {
                return [(baseFileName, sourceText)]
            }

            return [
                (transcriptVariantFileName(baseFileName, suffix: "original"), sourceText),
                (transcriptVariantFileName(baseFileName, suffix: "translation"), translatedText)
            ]
        }
    }

    @discardableResult
    private func writeTranscriptText(_ text: String, fileName: String) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: transcriptsDirectoryURL,
                withIntermediateDirectories: true
            )
            try text.write(
                to: transcriptURL(fileName: fileName),
                atomically: true,
                encoding: .utf8
            )
            return true
        } catch {
            statusMessage = AppText.saveLibraryFailed(error.localizedDescription)
            return false
        }
    }

    private func showToast(_ message: String) {
        toastDismissTask?.cancel()
        toastMessage = message
        toastSequence += 1

        let sequence = toastSequence
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard toastSequence == sequence else { return }
            toastMessage = nil
        }
    }

    private func sortSavedTranscripts() {
        savedTranscripts.sort { $0.updatedAt > $1.updatedAt }
    }

    private var transcriptsDirectoryURL: URL {
        let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return supportDirectory
            .appendingPathComponent("QuickLate", isDirectory: true)
            .appendingPathComponent("Transcripts", isDirectory: true)
    }

    private func transcriptURL(fileName: String) -> URL {
        transcriptsDirectoryURL.appendingPathComponent(fileName)
    }

    private func transcriptVariantFileName(_ fileName: String, suffix: String) -> String {
        let stem = fileName.hasSuffix(".txt") ? String(fileName.dropLast(4)) : fileName
        return "\(stem)_\(suffix).txt"
    }

    private func legacyTranscriptVariantFileName(_ fileName: String, suffix: String) -> String {
        let stem = fileName.hasSuffix(".txt") ? String(fileName.dropLast(4)) : fileName
        return "\(stem)-\(suffix).txt"
    }

    private func transcriptVariantInfo(_ fileName: String) -> (baseFileName: String, part: SavedTranscriptPart)? {
        let variants: [(suffix: String, part: SavedTranscriptPart)] = [
            ("_original.txt", .original),
            ("_translation.txt", .translation),
            ("-original.txt", .original),
            ("-translation.txt", .translation)
        ]

        for variant in variants where fileName.hasSuffix(variant.suffix) {
            let stem = String(fileName.dropLast(variant.suffix.count))
            return ("\(stem).txt", variant.part)
        }

        return nil
    }

    private func makeTranscriptFileName(for sourceText: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let timestamp = formatter.string(from: date)
        let baseName = "\(timestamp)_\(shortFileTitle(from: sourceText))"
        var fileName = "\(baseName).txt"
        var suffix = 2

        while transcriptFileExists(fileName) {
            fileName = "\(baseName)_\(suffix).txt"
            suffix += 1
        }

        return fileName
    }

    private func transcriptFileExists(_ fileName: String) -> Bool {
        let fileNames = [
            fileName,
            transcriptVariantFileName(fileName, suffix: "original"),
            transcriptVariantFileName(fileName, suffix: "translation"),
            legacyTranscriptVariantFileName(fileName, suffix: "original"),
            legacyTranscriptVariantFileName(fileName, suffix: "translation")
        ]
        return fileNames.contains { FileManager.default.fileExists(atPath: transcriptURL(fileName: $0).path) }
    }

    private func shortFileTitle(from sourceText: String) -> String {
        let firstLine = sourceText
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? AppText.untitledTranscript
        let allowedCharacters = CharacterSet.letters
            .union(.decimalDigits)
            .union(.whitespacesAndNewlines)
            .union(CharacterSet(charactersIn: "-_"))
        let readableText = String(firstLine.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : " "
        })
        let sanitized = readableText
            .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-_ "))

        guard !sanitized.isEmpty else {
            return AppText.untitledTranscript.replacingOccurrences(of: " ", with: "-")
        }

        return String(sanitized.prefix(32))
    }

    private func appendCaption(
        sourceText: String,
        recognizedLanguage _: LanguageOption,
        confidence _: Double,
        isFinal: Bool
    ) async {
        guard isRunning, !isPaused else { return }
        guard sourceText != lastRecognizedText || isFinal != lastRecognizedWasFinal else { return }
        let direction = translationDirection()

        let now = Date()
        let hadLongSilence = now.timeIntervalSince(lastRecognitionAt) > paragraphBreakSilenceInterval

        let updatedSourceText = accumulatedTranscript(
            incoming: sourceText,
            hadLongSilence: hadLongSilence
        )
        guard !updatedSourceText.isEmpty else { return }

        lastRecognizedText = sourceText
        lastRecognizedWasFinal = isFinal
        lastRecognitionAt = now
        transcriptCleanupTask?.cancel()

        if let currentLineID,
           let index = lines.firstIndex(where: { $0.id == currentLineID }) {
            let existingLine = lines[index]
            guard updatedSourceText != existingLine.sourceText else { return }

            if shouldPresentCaptionUpdate(sourceText: updatedSourceText, isFinal: isFinal) {
                clearPendingCaptionPresentation()
                presentCaptionLineUpdate(
                    lineID: existingLine.id,
                    sourceText: updatedSourceText,
                    isFinal: isFinal,
                    source: direction.source,
                    target: direction.target
                )
            } else {
                scheduleCaptionPresentation(
                    lineID: existingLine.id,
                    sourceText: updatedSourceText,
                    isFinal: isFinal,
                    source: direction.source,
                    target: direction.target
                )
            }
        } else {
            clearPendingCaptionPresentation()
            let line = CaptionLine(
                sourceText: updatedSourceText,
                translatedText: AppText.translating,
                createdAt: Date(),
                isFinal: isFinal,
                revision: 1,
                usesLongSessionDisplay: usesLongSessionMode
            )
            currentLineID = line.id
            lines.append(line)
            lastCaptionPresentationUpdateAt = Date()
            stageTranscriptForSave(line.sourceText)
            requestTranslation(for: line, source: direction.source, target: direction.target)
        }
    }

    private func shouldPresentCaptionUpdate(sourceText: String, isFinal: Bool) -> Bool {
        guard usesLongSessionMode else { return true }

        let sourceLength = sourceText.utf16.count
        guard sourceLength >= Self.largeTranscriptPresentationCharacterLimit else { return true }

        let elapsed = Date().timeIntervalSince(lastCaptionPresentationUpdateAt)
        let interval = isFinal
            ? Self.largeTranscriptPresentationInterval / 2
            : Self.largeTranscriptPresentationInterval
        return elapsed >= interval
    }

    private func scheduleCaptionPresentation(
        lineID: UUID,
        sourceText: String,
        isFinal: Bool,
        source: LanguageOption,
        target: LanguageOption
    ) {
        pendingCaptionPresentation = PendingCaptionPresentation(
            lineID: lineID,
            sourceText: sourceText,
            isFinal: isFinal,
            source: source,
            target: target
        )
        captionPresentationTask?.cancel()

        let elapsed = Date().timeIntervalSince(lastCaptionPresentationUpdateAt)
        let delay = max(0, Self.largeTranscriptPresentationInterval - elapsed)
        captionPresentationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(delay * 1_000)))
            guard !Task.isCancelled else { return }
            flushPendingCaptionPresentation()
        }
    }

    private func flushPendingCaptionPresentation() {
        guard let pendingCaptionPresentation else { return }

        self.pendingCaptionPresentation = nil
        captionPresentationTask?.cancel()
        captionPresentationTask = nil
        presentCaptionLineUpdate(
            lineID: pendingCaptionPresentation.lineID,
            sourceText: pendingCaptionPresentation.sourceText,
            isFinal: pendingCaptionPresentation.isFinal,
            source: pendingCaptionPresentation.source,
            target: pendingCaptionPresentation.target
        )
    }

    private func clearPendingCaptionPresentation() {
        pendingCaptionPresentation = nil
        captionPresentationTask?.cancel()
        captionPresentationTask = nil
    }

    private func presentCaptionLineUpdate(
        lineID: UUID,
        sourceText: String,
        isFinal: Bool,
        source: LanguageOption,
        target: LanguageOption
    ) {
        guard let index = lines.firstIndex(where: { $0.id == lineID }) else { return }

        let existingLine = lines[index]
        guard sourceText != existingLine.sourceText || isFinal != existingLine.isFinal else { return }

        let line = CaptionLine(
            id: existingLine.id,
            sourceText: sourceText,
            translatedText: existingLine.translatedText,
            translatedSourceText: existingLine.translatedSourceText,
            createdAt: existingLine.createdAt,
            isFinal: isFinal,
            revision: existingLine.revision + 1,
            usesLongSessionDisplay: usesLongSessionMode
        )
        lines[index] = line
        lastCaptionPresentationUpdateAt = Date()
        stageTranscriptForSave(line.sourceText)
        requestTranslation(for: line, source: source, target: target)
    }

    private func accumulatedTranscript(incoming: String, hadLongSilence: Bool) -> String {
        let trimmedIncoming = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIncoming.isEmpty else { return visibleTranscript() }

        if hadLongSilence, !currentPartialText.isEmpty {
            commitCurrentPartial()
            pendingParagraphBreakBeforePartial = !committedSourceText.isEmpty
            pendingFloatingParagraphBreakBeforePartial = !floatingCommittedSourceText.isEmpty
        }

        let incomingPartial = uncommittedIncomingText(
            from: trimmedIncoming,
            allowsCommittedRevision: !hadLongSilence,
            allowsCommittedReplay: !hadLongSilence
        )
        guard !incomingPartial.isEmpty else { return visibleTranscript() }

        if currentPartialText.isEmpty {
            currentPartialText = incomingPartial
            setFloatingCurrentPartialText(incomingPartial)
            return visibleTranscript()
        }

        if isRevisionOfCurrentPartial(incomingPartial) {
            currentPartialText = preferredPartialText(current: currentPartialText, incoming: incomingPartial)
            setFloatingCurrentPartialText(currentPartialText)
            return visibleTranscript()
        }

        commitCurrentPartial()
        pendingParagraphBreakBeforePartial = hadLongSilence && !committedSourceText.isEmpty
        pendingFloatingParagraphBreakBeforePartial = hadLongSilence && !floatingCommittedSourceText.isEmpty
        currentPartialText = uncommittedIncomingText(
            from: trimmedIncoming,
            allowsCommittedRevision: true,
            allowsCommittedReplay: true
        )
        setFloatingCurrentPartialText(currentPartialText)
        return visibleTranscript()
    }

    private func uncommittedIncomingText(
        from incoming: String,
        allowsCommittedRevision: Bool,
        allowsCommittedReplay: Bool
    ) -> String {
        if let replayTail = incomingTailAfterRecentCommittedReplay(incoming) {
            syncFloatingCommittedSourceTextToCommittedSourceText()
            return replayTail
        }

        if allowsCommittedReplay,
           TranscriptTextProcessor.committedTranscriptAlreadyMatches(incoming, in: committedSourceText) {
            return ""
        }

        if allowsCommittedRevision,
           replaceCommittedUnitsIfRevision(with: incoming, allowsBackfill: true) {
            syncFloatingCommittedSourceTextToCommittedSourceText()
            return ""
        }

        if let tail = incomingTailAfterCommittedText(
            incoming,
            allowsCommittedReplay: allowsCommittedReplay
        ) {
            return tail
        }

        return incoming
    }

    private func incomingTailAfterRecentCommittedReplay(_ incoming: String) -> String? {
        guard let replay = TranscriptTextProcessor.incomingTailAfterRecentCommittedReplay(
            incoming,
            committedText: committedSourceText,
            languageID: sourceLanguage.id
        ) else {
            return nil
        }

        committedSourceText = replay.committedText
        return replay.tailText
    }

    private func incomingTailAfterCommittedText(
        _ incoming: String,
        allowsCommittedReplay: Bool
    ) -> String? {
        TranscriptTextProcessor.incomingTailAfterCommittedText(
            incoming,
            committedText: committedSourceText,
            allowsCommittedReplay: allowsCommittedReplay
        )
    }

    private func isRevisionOfCurrentPartial(_ incomingPartial: String) -> Bool {
        TranscriptTextProcessor.isRevisionOfCurrentPartial(
            current: currentPartialText,
            incoming: incomingPartial
        )
    }

    private func preferredPartialText(current: String, incoming: String) -> String {
        TranscriptTextProcessor.preferredPartialText(current: current, incoming: incoming)
    }

    private func isWholeTextPrefix(_ prefix: String, of text: String) -> Bool {
        TranscriptTextProcessor.isWholeTextPrefix(prefix, of: text)
    }

    private func commitCurrentPartial() {
        let partial = isUsingOpenAIRealtime
            ? currentPartialText.trimmingCharacters(in: .whitespacesAndNewlines)
            : organizeTranscript(currentPartialText, language: sourceLanguage)
        guard !partial.isEmpty else { return }

        var didAppendCommittedPartial = false
        var didReplaceCommittedPartial = false
        if committedSourceText.isEmpty {
            committedSourceText = partial
            didAppendCommittedPartial = true
        } else if replaceCommittedUnitsIfRevision(with: partial, allowsBackfill: false) {
            // The speech recognizer can resend the last phrase with better wording after
            // cleanup. Treat that as a replacement, not a new line.
            didReplaceCommittedPartial = true
        } else if shouldAppendCommittedPartial(partial) {
            let separator = pendingParagraphBreakBeforePartial ? "\n\n" : "\n"
            committedSourceText += separator + partial
            didAppendCommittedPartial = true
        }
        pendingParagraphBreakBeforePartial = false
        currentPartialText = ""

        if didAppendCommittedPartial {
            commitFloatingCurrentPartial()
        } else if didReplaceCommittedPartial {
            syncFloatingCommittedSourceTextToCommittedSourceText(keepsCurrentPartial: false)
        } else {
            discardFloatingCurrentPartial()
        }
    }

    private func commitFloatingCurrentPartial() {
        let partial = floatingCurrentPartialText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !partial.isEmpty else { return }

        if floatingCommittedSourceText.isEmpty {
            floatingCommittedSourceText = partial
        } else if shouldAppendCommittedPartial(
            partial,
            to: floatingCommittedSourceText,
            pendingParagraphBreak: pendingFloatingParagraphBreakBeforePartial
        ) {
            let separator = pendingFloatingParagraphBreakBeforePartial ? "\n\n" : "\n"
            floatingCommittedSourceText += separator + partial
        }
        pendingFloatingParagraphBreakBeforePartial = false
        floatingCurrentPartialText = ""
        refreshFloatingCaptionPresentation()
    }

    private func setFloatingCurrentPartialText(_ text: String) {
        floatingCurrentPartialText = text
        refreshFloatingCaptionPresentation()
    }

    private func syncFloatingCommittedSourceTextToCommittedSourceText(keepsCurrentPartial: Bool = true) {
        floatingCommittedSourceText = committedSourceText
        if !keepsCurrentPartial {
            floatingCurrentPartialText = ""
            pendingFloatingParagraphBreakBeforePartial = false
        }
        refreshFloatingCaptionPresentation()
    }

    private func discardFloatingCurrentPartial() {
        floatingCurrentPartialText = ""
        pendingFloatingParagraphBreakBeforePartial = false
        refreshFloatingCaptionPresentation()
    }

    private func rehydrateFloatingCaptionDisplayFromCurrentLine() {
        guard let line = lines.last else {
            floatingCommittedSourceText = ""
            floatingCurrentPartialText = ""
            pendingFloatingParagraphBreakBeforePartial = false
            floatingPresentedSourceText = ""
            floatingQueuedSourceText = ""
            floatingPresentedAt = Date.distantPast
            floatingDisplayTranslationText = ""
            floatingDisplayTranslationSourceText = ""
            floatingQueuedTranslationText = ""
            floatingQueuedTranslationSourceText = ""
            return
        }

        floatingCommittedSourceText = line.sourceText
        floatingCurrentPartialText = ""
        pendingFloatingParagraphBreakBeforePartial = false
        floatingPresentedSourceText = isUsingOpenAIRealtime
            ? realtimeFloatingCaptionText(from: line.sourceText)
            : line.sourceText
        floatingQueuedSourceText = ""
        floatingPresentedAt = Date()

        let translatedText = line.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if translatedText.isEmpty || translatedText == AppText.translating {
            floatingDisplayTranslationText = ""
            floatingDisplayTranslationSourceText = ""
        } else {
            floatingDisplayTranslationText = isUsingOpenAIRealtime
                ? realtimeFloatingCaptionText(from: translatedText)
                : translatedText
            floatingDisplayTranslationSourceText = floatingPresentedSourceText
        }
        floatingQueuedTranslationText = ""
        floatingQueuedTranslationSourceText = ""
    }

    private func refreshFloatingCaptionPresentation() {
        let candidate = floatingVisibleSourceTranscript()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return }

        if floatingPresentedSourceText.isEmpty {
            presentFloatingSourceText(candidate)
            return
        }

        let normalizedCandidate = normalizedTranscriptForComparison(candidate)
        let normalizedPresented = normalizedTranscriptForComparison(floatingPresentedSourceText)
        guard normalizedCandidate != normalizedPresented else { return }

        let now = Date()
        if canUpdateFloatingPresentationImmediately(to: candidate, now: now)
            || canAdvanceFloatingPresentation(now: now) {
            presentFloatingSourceText(candidate)
            return
        }

        floatingQueuedSourceText = candidate
        scheduleFloatingPresentationAdvance()
    }

    private func canUpdateFloatingPresentationImmediately(to candidate: String, now: Date) -> Bool {
        let elapsed = now.timeIntervalSince(floatingPresentedAt)
        if elapsed <= Self.floatingCaptionEarlyRevisionWindow {
            return true
        }

        let normalizedPresented = normalizedTranscriptForComparison(floatingPresentedSourceText)
        let normalizedCandidate = normalizedTranscriptForComparison(candidate)
        return normalizedPresented.count < Self.floatingCaptionImmediateExtensionCharacterLimit
            && isWholeTextPrefix(normalizedPresented, of: normalizedCandidate)
    }

    private func canAdvanceFloatingPresentation(now: Date = Date()) -> Bool {
        guard !floatingPresentedSourceText.isEmpty else { return true }
        return now.timeIntervalSince(floatingPresentedAt) >= floatingCaptionDwellDuration()
    }

    private func floatingCaptionDwellDuration() -> TimeInterval {
        let sourceLength = normalizedTranscriptForComparison(floatingPresentedSourceText).count
        let translationLength = normalizedTranscriptForComparison(floatingDisplayTranslationText).count
        let readableLength = max(sourceLength, translationLength)
        let dwell = RealtimeLatencyPolicy.floatingCaptionBaseDwellSeconds
            + Double(readableLength) / RealtimeLatencyPolicy.floatingCaptionCharactersPerSecond
        return min(
            max(Self.minimumFloatingCaptionDwell, dwell),
            Self.maximumFloatingCaptionDwell
        )
    }

    private func presentFloatingSourceText(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        floatingPresentedSourceText = text
        floatingQueuedSourceText = ""
        floatingPresentedAt = Date()
        if !floatingDisplayTranslationSourceText.isEmpty,
           !translationSource(floatingDisplayTranslationSourceText, matches: text) {
            floatingDisplayTranslationText = ""
            floatingDisplayTranslationSourceText = ""
        }
        promoteQueuedFloatingTranslationIfPossible()
    }

    private func scheduleFloatingPresentationAdvance() {
        floatingPresentationTask?.cancel()

        let remaining = max(
            0.05,
            floatingCaptionDwellDuration() - Date().timeIntervalSince(floatingPresentedAt)
        )
        let delayMilliseconds = max(50, Int(remaining * 1_000))
        floatingPresentationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            promoteQueuedFloatingPresentationIfReady()
        }
    }

    private func promoteQueuedFloatingPresentationIfReady() {
        guard canAdvanceFloatingPresentation() else {
            scheduleFloatingPresentationAdvance()
            return
        }

        if !floatingQueuedSourceText.isEmpty {
            presentFloatingSourceText(floatingQueuedSourceText)
        } else {
            promoteQueuedFloatingTranslationIfPossible()
        }

        if !floatingQueuedSourceText.isEmpty || !floatingQueuedTranslationText.isEmpty {
            scheduleFloatingPresentationAdvance()
        } else {
            floatingPresentationTask = nil
        }
    }

    private func replaceCommittedUnitsIfRevision(with text: String, allowsBackfill: Bool) -> Bool {
        guard let updatedText = TranscriptTextProcessor.committedTextByReplacingRevision(
            with: text,
            committedText: committedSourceText,
            languageID: sourceLanguage.id,
            allowsBackfill: allowsBackfill
        ) else {
            return false
        }

        committedSourceText = updatedText
        return true
    }

    private func shouldAppendCommittedPartial(_ partial: String) -> Bool {
        shouldAppendCommittedPartial(
            partial,
            to: committedSourceText,
            pendingParagraphBreak: pendingParagraphBreakBeforePartial
        )
    }

    private func shouldAppendCommittedPartial(
        _ partial: String,
        to committedText: String,
        pendingParagraphBreak: Bool
    ) -> Bool {
        TranscriptTextProcessor.shouldAppendCommittedPartial(
            partial,
            to: committedText,
            pendingParagraphBreak: pendingParagraphBreak
        )
    }

    private func transcriptUnits(from text: String) -> [TranscriptUnit] {
        TranscriptTextProcessor.transcriptUnits(from: text)
    }

    private func transcriptText(from units: [TranscriptUnit]) -> String {
        TranscriptTextProcessor.transcriptText(from: units)
    }

    private func realtimeFloatingCaptionText(from text: String) -> String {
        let units = transcriptUnits(from: text)
        guard let latestUnit = units.last else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return latestUnit.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedTranscriptForComparison(_ text: String) -> String {
        TranscriptTextProcessor.normalizedForComparison(text)
    }

    func visibleTranscript() -> String {
        let committed = committedSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let partial = currentPartialText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !committed.isEmpty else {
            return partial
        }
        guard !partial.isEmpty else {
            return committed
        }

        let separator = pendingParagraphBreakBeforePartial ? "\n\n" : "\n"
        return committed + separator + partial
    }

    func visibleTranslatedText() -> String {
        let translatedLines = lines
            .map { $0.translatedText.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != AppText.translating }

        if !translatedLines.isEmpty {
            return translatedLines.joined(separator: "\n")
        }

        return floatingTranslationText
    }

    private func floatingVisibleSourceTranscript() -> String {
        let committed = floatingCommittedSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let partial = floatingCurrentPartialText.trimmingCharacters(in: .whitespacesAndNewlines)

        if isUsingOpenAIRealtime {
            if !partial.isEmpty {
                return realtimeFloatingCaptionText(from: partial)
            }
            return realtimeFloatingCaptionText(from: committed)
        }

        guard !committed.isEmpty else {
            return partial
        }
        guard !partial.isEmpty else {
            return committed
        }

        let separator = pendingFloatingParagraphBreakBeforePartial ? "\n\n" : "\n"
        return committed + separator + partial
    }

    private func scheduleTranscriptCleanup() {
        guard isRunning, currentLineID != nil else { return }
        guard !isUsingOpenAIRealtime else { return }
        guard Date().timeIntervalSince(lastRecognitionAt) > 1.5 else { return }

        transcriptCleanupTask?.cancel()
        transcriptCleanupTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            organizeCurrentTranscript()
        }
    }

    private func organizeCurrentTranscript(sourceTextOverride: String? = nil) {
        guard !isUsingOpenAIRealtime else { return }

        if sourceTextOverride == nil {
            flushPendingCaptionPresentation()
        }

        guard isRunning,
              let currentLineID,
              let index = lines.firstIndex(where: { $0.id == currentLineID })
        else {
            return
        }

        let line = lines[index]
        let sourceText = sourceTextOverride ?? line.sourceText
        let organizedSourceText = organizeTranscript(
            sourceText,
            language: sourceLanguage,
            appliesLint: isTranscriptLintEnabled
        )
        let organizedTranslatedText = organizeTranslatedText(line.translatedText)
        let sourceChanged = organizedSourceText != line.sourceText
        let translationChanged = organizedTranslatedText != line.translatedText
        let needsTranslationRefresh = line.translatedSourceText != organizedSourceText

        if !sourceChanged,
           !translationChanged,
           needsTranslationRefresh,
           pendingTranslationSourceText == organizedSourceText {
            return
        }

        guard sourceChanged || translationChanged || needsTranslationRefresh else {
            return
        }

        committedSourceText = organizedSourceText
        currentPartialText = ""
        lines[index] = CaptionLine(
            id: line.id,
            sourceText: organizedSourceText,
            translatedText: organizedTranslatedText,
            translatedSourceText: line.translatedSourceText,
            createdAt: line.createdAt,
            isFinal: line.isFinal,
            revision: line.revision + 1,
            usesLongSessionDisplay: usesLongSessionMode
        )

        // Keep floating captions stable while cleanup rewrites the saved transcript.
        let updatedLine = lines[index]
        stageTranscriptForSave(updatedLine.sourceText)
        if updatedLine.translatedSourceText != updatedLine.sourceText {
            requestTranslation(for: updatedLine, source: sourceLanguage, target: targetLanguage)
        }
    }

    private func organizeTranslatedText(_ text: String) -> String {
        guard text != AppText.translating else { return text }
        return organizeTranscript(text, language: targetLanguage)
    }

    private func organizeTranscript(_ text: String, language: LanguageOption) -> String {
        organizeTranscript(text, language: language, appliesLint: false)
    }

    private func organizeTranscript(
        _ text: String,
        language: LanguageOption,
        appliesLint: Bool
    ) -> String {
        if !appliesLint {
            return TranscriptTextProcessor.organizeTranscript(text, languageID: language.id)
        }

        return paragraphParts(from: text)
            .map {
                let organized = organizeParagraph($0, language: language)
                return lintParagraph(organized, language: language)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func organizeParagraph(_ text: String, language: LanguageOption) -> String {
        TranscriptTextProcessor.organizeParagraph(text, languageID: language.id)
    }

    private func lintParagraph(_ text: String, language: LanguageOption) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { lintLine(String($0), language: language) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func lintLine(_ text: String, language: LanguageOption) -> String {
        var linted = text
            .replacingOccurrences(of: #"(^|[\s,，])[,，]{1,}(\s*[,，]+)*"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+([,.!?。！？])"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"([,.!?])(?=\S)"#, with: "$1 ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        linted = correctUnknownWords(in: linted, language: language)

        if language.id == "en-US" {
            linted = capitalizeSentenceStarts(linted)
        }

        return linted.trimmingCharacters(in: CharacterSet(charactersIn: " ,，"))
    }

    private func correctUnknownWords(in text: String, language: LanguageOption) -> String {
        guard let spellLanguage = spellCheckerLanguage(for: language) else { return text }

        var corrected = text
        var searchLocation = 0

        while searchLocation < (corrected as NSString).length {
            var wordCount = 0
            let misspelledRange = spellChecker.checkSpelling(
                of: corrected,
                startingAt: searchLocation,
                language: spellLanguage,
                wrap: false,
                inSpellDocumentWithTag: spellDocumentTag,
                wordCount: &wordCount
            )
            guard misspelledRange.location != NSNotFound, misspelledRange.length > 0 else { break }

            let textValue = corrected as NSString
            let word = textValue.substring(with: misspelledRange)
            if let replacement = safeSpellingReplacement(
                for: word,
                in: corrected,
                range: misspelledRange,
                language: spellLanguage
            ) {
                corrected = textValue.replacingCharacters(in: misspelledRange, with: replacement)
                searchLocation = misspelledRange.location + (replacement as NSString).length
            } else {
                searchLocation = misspelledRange.location + misspelledRange.length
            }
        }

        return corrected
    }

    private func spellCheckerLanguage(for language: LanguageOption) -> String? {
        let availableLanguages = spellChecker.availableLanguages
        let normalizedID = language.id.replacingOccurrences(of: "-", with: "_")
        if availableLanguages.contains(language.id) {
            return language.id
        }
        if availableLanguages.contains(normalizedID) {
            return normalizedID
        }
        if let baseID = language.id.split(separator: "-").first.map(String.init),
           availableLanguages.contains(baseID) {
            return baseID
        }
        return nil
    }

    private func safeSpellingReplacement(
        for word: String,
        in text: String,
        range: NSRange,
        language: String
    ) -> String? {
        guard shouldCorrectSpelledWord(word, language: language),
              let guesses = spellChecker.guesses(
                  forWordRange: range,
                  in: text,
                  language: language,
                  inSpellDocumentWithTag: spellDocumentTag
              ),
              let replacement = guesses.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              isConservativeReplacement(original: word, replacement: replacement)
        else {
            return nil
        }

        return replacement
    }

    private func shouldCorrectSpelledWord(_ word: String, language: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
        guard trimmed.count > 1 else { return false }
        guard trimmed.rangeOfCharacter(from: .decimalDigits) == nil else { return false }
        guard trimmed.range(of: #"[/\\@#_]"#, options: .regularExpression) == nil else { return false }

        if language.hasPrefix("en"),
           let first = trimmed.first,
           first.isUppercase {
            return false
        }

        return true
    }

    private func isConservativeReplacement(original: String, replacement: String) -> Bool {
        guard !replacement.isEmpty, !replacement.contains("\n") else { return false }
        let originalLength = max((original as NSString).length, 1)
        let replacementLength = (replacement as NSString).length
        guard replacementLength <= originalLength + 4 else { return false }
        guard replacementLength * 3 >= originalLength else { return false }
        return true
    }

    private func capitalizeSentenceStarts(_ text: String) -> String {
        var result = ""
        var shouldCapitalize = true

        for character in text {
            if shouldCapitalize, character.isLetter {
                result.append(String(character).uppercased())
                shouldCapitalize = false
                continue
            }

            result.append(character)
            if ".!?".contains(character) {
                shouldCapitalize = true
            } else if !character.isWhitespace {
                shouldCapitalize = false
            }
        }

        return result
    }

    private func paragraphParts(from text: String) -> [String] {
        TranscriptTextProcessor.paragraphParts(from: text)
    }

    private func translateTranscript(
        _ text: String,
        source: LanguageOption,
        target: LanguageOption
    ) async throws -> String {
        let paragraphs = paragraphParts(from: text)

        guard !paragraphs.isEmpty else { return "" }

        var translatedParagraphs: [String] = []
        for paragraph in paragraphs {
            let segments = paragraph
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            var translatedSegments: [String] = []

            for segment in segments {
                try Task.checkCancellation()
                let cacheKey = translationCacheKey(segment: segment, source: source, target: target)
                if let cachedSegment = translatedSegmentsBySource[cacheKey] {
                    rememberTranslationCacheKey(cacheKey)
                    translatedSegments.append(cachedSegment)
                    continue
                }

                let translatedSegment: String
                if openAITranslationModel.isEnabled && !openAITranslationModel.usesRealtimeAudioTranslation {
                    translatedSegment = try await openAITranslator.translate(
                        segment,
                        source: source,
                        target: target,
                        model: openAITranslationModel
                    )
                } else {
                    translatedSegment = try await translator.translate(
                        segment,
                        source: source,
                        target: target,
                        model: selectedModel
                    )
                }
                try Task.checkCancellation()
                let organizedSegment = organizeTranscript(translatedSegment, language: target)
                cacheTranslatedSegment(organizedSegment, forKey: cacheKey)
                translatedSegments.append(organizedSegment)
            }

            translatedParagraphs.append(translatedSegments.joined(separator: "\n"))
        }

        return translatedParagraphs.joined(separator: "\n\n")
    }

    private func translationCacheKey(segment: String, source: LanguageOption, target: LanguageOption) -> String {
        "\(source.id)\t\(target.id)\t\(selectedModel.id)\t\(segment)"
    }

    private func cacheTranslatedSegment(_ segment: String, forKey key: String) {
        translatedSegmentsBySource[key] = segment
        rememberTranslationCacheKey(key)

        while translationCacheKeyOrder.count > Self.maxTranslationCacheEntries {
            let removedKey = translationCacheKeyOrder.removeFirst()
            if !translationCacheKeyOrder.contains(removedKey) {
                translatedSegmentsBySource.removeValue(forKey: removedKey)
            }
        }
    }

    private func rememberTranslationCacheKey(_ key: String) {
        translationCacheKeyOrder.removeAll { $0 == key }
        translationCacheKeyOrder.append(key)
    }

    private func resetTranslationCache() {
        translatedSegmentsBySource.removeAll()
        translationCacheKeyOrder.removeAll()
    }

    private func appendRealtimeTranslationOnly(_ text: String) {
        guard isRunning, !isPaused else { return }

        guard text.rangeOfCharacter(from: .whitespacesAndNewlines.inverted) != nil
            || !realtimeTranslationOnlyText.isEmpty else { return }

        if text.hasPrefix(realtimeTranslationOnlyText) {
            realtimeTranslationOnlyText = text
        } else if !realtimeTranslationOnlyText.hasSuffix(text) {
            realtimeTranslationOnlyText += text
        }

        let translatedText = realtimeTranslationOnlyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translatedText.isEmpty else { return }

        lastRecognizedText = translatedText
        lastRecognitionAt = Date()
        transcriptCleanupTask?.cancel()

        let sourceText = AppText.openAIRealtimeTranslationOnlySource

        if let currentLineID,
           let index = lines.firstIndex(where: { $0.id == currentLineID }) {
            let existingLine = lines[index]
            lines[index] = CaptionLine(
                id: existingLine.id,
                sourceText: sourceText,
                translatedText: translatedText,
                translatedSourceText: sourceText,
                createdAt: existingLine.createdAt,
                isFinal: false,
                revision: existingLine.revision + 1,
                usesLongSessionDisplay: usesLongSessionMode
            )
        } else {
            let line = CaptionLine(
                sourceText: sourceText,
                translatedText: translatedText,
                translatedSourceText: sourceText,
                createdAt: Date(),
                isFinal: false,
                revision: 1,
                usesLongSessionDisplay: usesLongSessionMode
            )
            currentLineID = line.id
            lines.append(line)
        }

        stageTranscriptForSave(sourceText, translatedText: translatedText)
        let floatingTranslatedText = isUsingOpenAIRealtimeTranslation
            ? text.trimmingCharacters(in: .whitespacesAndNewlines)
            : translatedText
        updateFloatingTranslationPresentation(floatingTranslatedText, sourceText: sourceText)
        speakTranslatedDeltaIfNeeded(translatedText)
    }

    private func requestTranslation(for line: CaptionLine, source: LanguageOption, target: LanguageOption) {
        guard !openAITranslationModel.usesRealtimeAudioTranslation else { return }

        guard selectedModel != .appleSpeechOnly else {
            markTranslationUnavailable(
                AppText.translationDisabledForSpeechOnly,
                for: line,
                matching: line.sourceText
            )
            return
        }

        guard source.id != target.id else {
            markTranslationUnavailable(
                AppText.sameLanguageTranslationUnavailable,
                for: line,
                matching: line.sourceText
            )
            return
        }

        let sourceText = line.sourceText
        guard pendingTranslationSourceText != sourceText else { return }
        pendingTranslationSourceText = sourceText
        if latestTranslationRequest == nil {
            translationBurstStartedAt = Date()
        }
        latestTranslationRequest = TranslationRequest(
            line: line,
            sourceText: sourceText,
            source: source,
            target: target
        )

        guard translationTask == nil else {
            return
        }

        translationTask = Task { @MainActor in
            await processPendingTranslationRequests()
        }
    }

    private func processPendingTranslationRequests() async {
        while !Task.isCancelled, let request = latestTranslationRequest {
            latestTranslationRequest = nil

            do {
                let delay = translationDebounceDelay(for: request.sourceText)
                if delay > 0 {
                    try await Task.sleep(for: .milliseconds(delay))
                }

                if latestTranslationRequest != nil {
                    continue
                }

                translationBurstStartedAt = .distantPast
                let translatedText = try await translateTranscript(
                    request.sourceText,
                    source: request.source,
                    target: request.target
                )
                try Task.checkCancellation()
                updateTranslation(translatedText, for: request.line, matching: request.sourceText)
            } catch is CancellationError {
                translationTask = nil
                return
            } catch {
                if pendingTranslationSourceText == request.sourceText {
                    pendingTranslationSourceText = ""
                }
                markTranslationUnavailable(error.localizedDescription, for: request.line, matching: request.sourceText)
            }
        }

        translationTask = nil
    }

    private func translationDebounceDelay(for sourceText: String) -> Int {
        if usesLongSessionMode {
            let sourceLength = sourceText.utf16.count
            if sourceLength >= Self.veryLargeTranscriptTranslationCharacterLimit {
                return RealtimeLatencyPolicy.veryLargeTranscriptTranslationDebounceMilliseconds
            }
            if sourceLength >= Self.largeTranscriptTranslationCharacterLimit {
                return RealtimeLatencyPolicy.largeTranscriptTranslationDebounceMilliseconds
            }
        }

        guard translationBurstStartedAt != .distantPast else {
            return RealtimeLatencyPolicy.defaultTranslationDebounceMilliseconds
        }
        let burstAge = Date().timeIntervalSince(translationBurstStartedAt)
        return burstAge >= RealtimeLatencyPolicy.maximumTranslationBurstHoldSeconds
            ? 0
            : RealtimeLatencyPolicy.initialTranslationBurstDebounceMilliseconds
    }

    private func updateTranslation(_ translatedText: String, for line: CaptionLine, matching sourceText: String) {
        guard let index = lines.firstIndex(where: { $0.id == line.id }) else { return }
        guard lines[index].sourceText == sourceText else {
            if pendingTranslationSourceText == sourceText {
                pendingTranslationSourceText = ""
            }
            return
        }
        let organizedTranslatedText = organizeTranscript(translatedText, language: targetLanguage)
        let floatingTranslatedText = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if pendingTranslationSourceText == sourceText {
            pendingTranslationSourceText = ""
        }
        stageTranscriptForSave(sourceText, translatedText: organizedTranslatedText)

        lines[index] = CaptionLine(
            id: line.id,
            sourceText: sourceText,
            translatedText: organizedTranslatedText,
            translatedSourceText: sourceText,
            createdAt: line.createdAt,
            isFinal: line.isFinal,
            revision: lines[index].revision + 1,
            usesLongSessionDisplay: usesLongSessionMode
        )

        updateFloatingTranslationPresentation(floatingTranslatedText, sourceText: sourceText)
        speakTranslatedDeltaIfNeeded(organizedTranslatedText)
    }

    private func markTranslationUnavailable(_ message: String, for line: CaptionLine, matching sourceText: String) {
        guard let index = lines.firstIndex(where: { $0.id == line.id }) else {
            statusMessage = message
            return
        }
        guard lines[index].sourceText == sourceText else {
            statusMessage = message
            return
        }

        if pendingTranslationSourceText == sourceText {
            pendingTranslationSourceText = ""
        }

        lines[index] = CaptionLine(
            id: line.id,
            sourceText: sourceText,
            translatedText: message,
            translatedSourceText: sourceText,
            createdAt: line.createdAt,
            isFinal: line.isFinal,
            revision: lines[index].revision + 1,
            usesLongSessionDisplay: usesLongSessionMode
        )
        updateFloatingTranslationPresentation(message, sourceText: sourceText)
        statusMessage = message
    }

    private func updateFloatingTranslationPresentation(_ translatedText: String, sourceText: String) {
        let displaySourceText = isUsingOpenAIRealtime
            ? realtimeFloatingCaptionText(from: sourceText)
            : sourceText
        let displayTranslatedText = isUsingOpenAIRealtime
            ? realtimeFloatingCaptionText(from: translatedText)
            : translatedText

        guard !displaySourceText.isEmpty,
              !displayTranslatedText.isEmpty,
              displayTranslatedText != AppText.translating
        else {
            return
        }

        if shouldUpdateFloatingTranslationDisplay(for: displaySourceText) {
            if floatingDisplayTranslationText.isEmpty || canAdvanceFloatingPresentation() {
                floatingDisplayTranslationText = displayTranslatedText
                floatingDisplayTranslationSourceText = displaySourceText
            } else {
                floatingQueuedTranslationText = displayTranslatedText
                floatingQueuedTranslationSourceText = displaySourceText
                scheduleFloatingPresentationAdvance()
            }
            return
        }

        if shouldUpdateQueuedFloatingTranslationDisplay(for: displaySourceText) {
            floatingQueuedTranslationText = displayTranslatedText
            floatingQueuedTranslationSourceText = displaySourceText
            scheduleFloatingPresentationAdvance()
        }
    }

    private func promoteQueuedFloatingTranslationIfPossible() {
        guard !floatingQueuedTranslationText.isEmpty else { return }
        guard shouldUpdateFloatingTranslationDisplay(for: floatingQueuedTranslationSourceText) else {
            if floatingQueuedSourceText.isEmpty {
                floatingQueuedTranslationText = ""
                floatingQueuedTranslationSourceText = ""
            }
            return
        }

        floatingDisplayTranslationText = floatingQueuedTranslationText
        floatingDisplayTranslationSourceText = floatingQueuedTranslationSourceText
        floatingQueuedTranslationText = ""
        floatingQueuedTranslationSourceText = ""
    }

    private func shouldUpdateFloatingTranslationDisplay(for sourceText: String) -> Bool {
        translationSource(sourceText, matches: floatingPresentedSourceText)
    }

    private func shouldUpdateQueuedFloatingTranslationDisplay(for sourceText: String) -> Bool {
        translationSource(sourceText, matches: floatingQueuedSourceText)
    }

    private func translationSource(_ sourceText: String, matches displaySourceText: String) -> Bool {
        guard !displaySourceText.isEmpty else { return false }

        let normalizedSourceText = normalizedTranscriptForComparison(sourceText)
        let normalizedDisplaySourceText = normalizedTranscriptForComparison(displaySourceText)
        if normalizedSourceText == normalizedDisplaySourceText
            || isWholeTextPrefix(normalizedSourceText, of: normalizedDisplaySourceText) {
            return true
        }

        let organizedDisplaySourceText = organizeTranscript(
            displaySourceText,
            language: sourceLanguage,
            appliesLint: false
        )
        let normalizedOrganizedDisplaySourceText = normalizedTranscriptForComparison(organizedDisplaySourceText)
        return normalizedSourceText == normalizedOrganizedDisplaySourceText
            || isWholeTextPrefix(normalizedSourceText, of: normalizedOrganizedDisplaySourceText)
    }

    private func translationDirection() -> (source: LanguageOption, target: LanguageOption) {
        (sourceLanguage, targetLanguage)
    }

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        speechOutput.speak(text, language: targetLanguage)
    }

    private func speakTranslatedDeltaIfNeeded(_ translatedText: String) {
        guard isRunning, isDubbingEnabled else { return }
        guard !openAITranslationModel.usesRealtimeAudioTranslation else { return }

        let currentText = speechReadyText(translatedText)
        guard !currentText.isEmpty else { return }

        let previousText = lastSpokenTranslatedText
        lastSpokenTranslatedText = currentText

        guard let delta = speechDelta(previous: previousText, current: currentText),
              let unspokenDelta = unspokenSpeechText(from: delta)
        else {
            return
        }

        speak(unspokenDelta)
    }

    private func speechReadyText(_ text: String) -> String {
        guard text != AppText.translating else { return "" }

        return text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func speechDelta(previous: String, current: String) -> String? {
        guard previous != current else { return nil }
        guard !current.isEmpty else { return nil }

        if previous.isEmpty {
            return current
        }

        if current.hasPrefix(previous) {
            return speakableText(String(current.dropFirst(previous.count)))
        }

        let sharedPrefixLength = commonPrefixLength(previous, current)
        if sharedPrefixLength > previous.count / 2 {
            return speakableText(String(current.dropFirst(sharedPrefixLength)))
        }

        return nil
    }

    private func commonPrefixLength(_ lhs: String, _ rhs: String) -> Int {
        var length = 0
        for (leftCharacter, rightCharacter) in zip(lhs, rhs) {
            guard leftCharacter == rightCharacter else { break }
            length += 1
        }
        return length
    }

    private func speakableText(_ text: String) -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.rangeOfCharacter(from: .letters.union(.decimalDigits)) != nil else {
            return nil
        }
        return trimmedText
    }

    private func unspokenSpeechText(from text: String) -> String? {
        let units = speechUnits(from: text)
        guard !units.isEmpty else { return nil }

        var unspokenUnits: [String] = []
        for unit in units {
            let key = normalizedSpeechUnitKey(unit)
            guard !key.isEmpty, !spokenTranslationUnitKeys.contains(key) else {
                continue
            }

            rememberSpokenTranslationUnitKey(key)
            unspokenUnits.append(unit)
        }

        guard !unspokenUnits.isEmpty else { return nil }
        return unspokenUnits.joined(separator: " ")
    }

    private func speechUnits(from text: String) -> [String] {
        var units: [String] = []
        var currentUnit = ""
        let terminators = CharacterSet(charactersIn: ".!?。！？\n")

        for scalar in text.unicodeScalars {
            currentUnit.unicodeScalars.append(scalar)
            if terminators.contains(scalar) {
                let unit = speechReadyText(currentUnit)
                if !unit.isEmpty {
                    units.append(unit)
                }
                currentUnit = ""
            }
        }

        let remainingUnit = speechReadyText(currentUnit)
        if !remainingUnit.isEmpty {
            units.append(remainingUnit)
        }

        return units
    }

    private func normalizedSpeechUnitKey(_ text: String) -> String {
        let foldedText = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: targetLanguage.locale)
        let allowedCharacters = CharacterSet.letters
            .union(.decimalDigits)
            .union(.whitespacesAndNewlines)
        let filteredText = String(foldedText.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : " "
        })

        return filteredText
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func rememberSpokenTranslationUnitKey(_ key: String) {
        spokenTranslationUnitKeys.insert(key)
        spokenTranslationUnitKeyOrder.append(key)

        while spokenTranslationUnitKeyOrder.count > 160 {
            let removedKey = spokenTranslationUnitKeyOrder.removeFirst()
            if !spokenTranslationUnitKeyOrder.contains(removedKey) {
                spokenTranslationUnitKeys.remove(removedKey)
            }
        }
    }

    private func rememberSpokenTranslationUnits(in text: String) {
        for unit in speechUnits(from: text) {
            let key = normalizedSpeechUnitKey(unit)
            if !key.isEmpty {
                rememberSpokenTranslationUnitKey(key)
            }
        }
    }

    private func clearSpokenTranslationUnits() {
        spokenTranslationUnitKeys.removeAll()
        spokenTranslationUnitKeyOrder.removeAll()
    }

    private func resetDubbingProgress() {
        lastSpokenTranslatedText = ""
        clearSpokenTranslationUnits()
        stopSpeaking()
    }

    private func primeDubbingBaselineToCurrentTranslation() {
        let currentTranslation = speechReadyText(lines.last?.translatedText ?? "")
        lastSpokenTranslatedText = currentTranslation
        clearSpokenTranslationUnits()
        rememberSpokenTranslationUnits(in: currentTranslation)
    }

    private func stopSpeaking() {
        speechOutput.stop()
        openAIRealtimeAudioOutput.stop()
    }
}

extension TranslationSessionStore: SystemAudioCaptureDelegate {
    nonisolated func systemAudioCapture(_ capture: SystemAudioCapture, didOutput sampleBuffer: CMSampleBuffer) {
        transcriber.append(sampleBuffer)
        openAITranscriber.append(sampleBuffer)
    }

    nonisolated func systemAudioCapture(_ capture: SystemAudioCapture, didReceiveAudioSampleCount count: Int, level: Float?) {
        Task { @MainActor in
            audioSampleCount = count
            latestAudioLevel = level
            guard !isPaused else {
                statusMessage = AppText.paused
                return
            }
            if isRunning, lines.isEmpty {
                statusMessage = audioStatusMessage(sampleCount: count, level: level)
            }
            if let level, level < -50 {
                scheduleTranscriptCleanup()
            }
        }
    }

    private func audioStatusMessage(sampleCount: Int, level: Float?) -> String {
        guard let level else {
            return AppText.receivingAudioWaiting(sampleCount: sampleCount)
        }

        let roundedLevel = Int(level.rounded())
        if level < -55 {
            return AppText.receivingSilentAudio(sampleCount: sampleCount, level: roundedLevel)
        }

        return AppText.receivingAudioTranscribing(sampleCount: sampleCount, level: roundedLevel)
    }
}

extension TranslationSessionStore: LiveSpeechTranscriberDelegate {
    nonisolated func liveSpeechTranscriber(
        _ transcriber: LiveSpeechTranscriber,
        didRecognize text: String,
        language: LanguageOption,
        confidence: Double
    ) {
        Task { @MainActor in
            await appendCaption(
                sourceText: text,
                recognizedLanguage: language,
                confidence: confidence,
                isFinal: false
            )
        }
    }

    nonisolated func liveSpeechTranscriber(
        _ transcriber: LiveSpeechTranscriber,
        didTranslate text: String,
        language: LanguageOption,
        confidence: Double
    ) {
        Task { @MainActor in
            appendRealtimeTranslationOnly(text)
        }
    }

    nonisolated func liveSpeechTranscriber(
        _ transcriber: LiveSpeechTranscriber,
        didOutputAudioPCM16Base64 audio: String,
        sampleRate: Double
    ) {
        Task { @MainActor in
            guard isRunning,
                  !isPaused,
                  isDubbingEnabled,
                  openAITranslationModel.usesRealtimeAudioTranslation
            else {
                return
            }

            openAIRealtimeAudioOutput.playPCM16Base64(audio, sampleRate: sampleRate)
        }
    }

    nonisolated func liveSpeechTranscriber(_ transcriber: LiveSpeechTranscriber, didFail error: Error) {
        Task { @MainActor in
            statusMessage = error.localizedDescription
        }
    }
}

private extension IntelligenceModel {
    var appleAssetModel: AppleAssetModel {
        switch self {
        case .appleSystem:
            .combined
        case .appleOnDevice:
            .translationOnly
        case .appleSpeechOnly:
            .speechOnly
        }
    }
}

private extension AppleAssetModel {
    var intelligenceModel: IntelligenceModel {
        switch self {
        case .combined:
            .appleSystem
        case .translationOnly:
            .appleOnDevice
        case .speechOnly:
            .appleSpeechOnly
        }
    }
}

private extension AppleAssetDownloadRoute {
    var e2eName: String {
        switch self {
        case .speechAssetInventory:
            "speechAssetInventory"
        case .swiftUITranslationTask:
            "swiftUITranslationTask"
        }
    }
}
