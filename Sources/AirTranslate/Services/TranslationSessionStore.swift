import AVFAudio
import AppKit
import Foundation
import Observation

private enum SettingsKey {
    static let sourceLanguageID = "sourceLanguageID"
    static let targetLanguageID = "targetLanguageID"
    static let selectedModelID = "selectedModelID"
    static let isDubbingEnabled = "isDubbingEnabled"
    static let isTranscriptLintEnabled = "isTranscriptLintEnabled"
    static let floatingCaptionDisplayMode = "floatingCaptionDisplayMode"
    static let floatingCaptionTextSize = "floatingCaptionTextSize"
    static let floatingCaptionLineCount = "floatingCaptionLineCount"
    static let paragraphBreakSilenceInterval = "paragraphBreakSilenceInterval"
    static let savedTranscriptContentMode = "savedTranscriptContentMode"
}

private struct TranslationRequest {
    let line: CaptionLine
    let sourceText: String
    let source: LanguageOption
    let target: LanguageOption
}

@Observable
@MainActor
final class TranslationSessionStore {
    private static let maxTranslationCacheEntries = 2_000
    private static let committedRevisionSearchLimit = 2

    var isRunning = false
    var isPaused = false
    var isDubbingEnabled = false {
        didSet {
            persistSelectedSettings()
            if isDubbingEnabled {
                primeDubbingBaselineToCurrentTranslation()
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
    var statusMessage = AppText.ready
    var toastMessage: String?
    var toastSequence = 0
    var lines: [CaptionLine] = []
    var savedTranscripts: [SavedTranscript] = []
    var selectedSavedTranscriptID: String?
    var savedDraftSourceText = ""
    var savedDraftTranslationText = ""
    private(set) var latestAudioLevel: Float?
    var modelAvailabilityByModelID = Dictionary(
        uniqueKeysWithValues: IntelligenceModel.allCases.map {
            ($0.id, ModelAvailability.checking(for: $0))
        }
    )

    private let capture = SystemAudioCapture()
    private let transcriber = LiveSpeechTranscriber()
    private let translator = AppleTranslationService()
    private let speechOutput = TranslatedSpeechOutput()
    private let spellChecker = NSSpellChecker.shared
    private let spellDocumentTag = NSSpellChecker.uniqueSpellDocumentTag()
    private var audioSampleCount = 0
    private var lastRecognizedText = ""
    private var lastRecognizedWasFinal = false
    private var lastRecognitionAt = Date.distantPast
    private var currentLineID: UUID?
    private var transcriptCleanupTask: Task<Void, Never>?
    private var translationTask: Task<Void, Never>?
    private var latestTranslationRequest: TranslationRequest?
    private var translationBurstStartedAt = Date.distantPast
    private var committedSourceText = ""
    private var currentPartialText = ""
    private var pendingParagraphBreakBeforePartial = false
    private var pendingTranslationSourceText = ""
    private var translatedSegmentsBySource: [String: String] = [:]
    private var translationCacheKeyOrder: [String] = []
    private var activeAutosaveTranscriptID: String?
    private var activeAutosaveSourceText = ""
    private var activeAutosaveTranslatedText = ""
    private var isRestoringSelectedSettings = false
    private var modelAvailabilityTask: Task<Void, Never>?
    private var toastDismissTask: Task<Void, Never>?
    private var lastSpokenTranslatedText = ""
    private var spokenTranslationUnitKeys: Set<String> = []
    private var spokenTranslationUnitKeyOrder: [String] = []

    private enum SavedTranscriptPart {
        case original
        case translation
    }

    private struct SavedTranscriptFile {
        let fileName: String
        let text: String
        let updatedAt: Date
    }

    private struct PartialSavedTranscript {
        var original: SavedTranscriptFile?
        var translation: SavedTranscriptFile?
    }

    private struct TranscriptUnit {
        var separatorBefore: String
        var text: String
    }

    init() {
        restoreSelectedSettings()
        capture.delegate = self
        transcriber.delegate = self
        loadSavedTranscripts()
        refreshModelAvailability()
    }

    func start() {
        guard !isRunning else { return }

        resetLiveSessionState(clearsVisibleLines: true)
        isPaused = false
        transcriber.setPaused(false)
        isRunning = true
        statusMessage = AppText.checkingScreenPermission

        Task {
            do {
                try capture.requestScreenRecordingAccess()
                statusMessage = AppText.checkingSpeechPermission
                try await startCaptioners()
                statusMessage = AppText.startingCapture
                try await capture.start()
                statusMessage = AppText.listeningForSpeech
                warmTranslationSession()
            } catch {
                isRunning = false
                stopCaptioners()
                await capture.stop()
                statusMessage = AppText.startFailed(error.localizedDescription)
            }
        }
    }

    func stop() {
        guard isRunning else { return }

        let didSaveTranscript = flushPendingTranscriptSave()
        resetLiveSessionState(clearsVisibleLines: false)
        isPaused = false
        transcriber.setPaused(false)
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

        transcriptCleanupTask?.cancel()
        transcriptCleanupTask = nil
        commitCurrentPartial()
        organizeCurrentTranscript(sourceTextOverride: visibleTranscript())
        transcriber.setPaused(true)
        isPaused = true
        statusMessage = AppText.paused
    }

    func resume() {
        guard isRunning, isPaused else { return }

        transcriber.setPaused(false)
        isPaused = false
        lastRecognitionAt = Date()
        statusMessage = AppText.listeningForSpeech
    }

    func prepareForTermination() {
        _ = flushPendingTranscriptSave()
    }

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }

        NSWorkspace.shared.open(url)
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
        AppText.languageSummary(source: sourceLanguage.localizedTitle, target: targetLanguage.localizedTitle)
    }

    func modelAvailability(for model: IntelligenceModel) -> ModelAvailability {
        modelAvailabilityByModelID[model.id] ?? ModelAvailability.checking(for: model)
    }

    func downloadModelAssets(for model: IntelligenceModel) {
        guard modelAvailability(for: model).state.canDownload else { return }

        let sourceLanguage = sourceLanguage
        let targetLanguage = targetLanguage
        modelAvailabilityByModelID[model.id] = ModelAvailability(
            state: .downloading,
            detail: model.detail
        )

        Task { @MainActor in
            do {
                try await ModelAvailabilityChecker.downloadAssets(
                    for: model,
                    source: sourceLanguage,
                    target: targetLanguage
                )
                refreshModelAvailability()
            } catch {
                modelAvailabilityByModelID[model.id] = ModelAvailability(
                    state: .failed,
                    detail: error.localizedDescription
                )
            }
        }
    }

    var floatingSourceText: String {
        floatingCaptionText(from: lines.last?.sourceText)
    }

    var floatingTranslationText: String {
        guard let translatedText = lines.last?.translatedText.trimmingCharacters(in: .whitespacesAndNewlines),
              translatedText != AppText.translating
        else {
            return ""
        }

        return floatingCaptionText(from: translatedText)
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

    func deleteSelectedTranscript() {
        guard let selectedTranscript = selectedSavedTranscript else { return }

        savedTranscripts.removeAll { $0.id == selectedTranscript.id }
        try? FileManager.default.removeItem(at: transcriptURL(fileName: selectedTranscript.sourceFileName))
        if let translationFileName = selectedTranscript.translationFileName {
            try? FileManager.default.removeItem(at: transcriptURL(fileName: translationFileName))
        }
        if activeAutosaveTranscriptID == selectedTranscript.id {
            activeAutosaveTranscriptID = nil
            activeAutosaveSourceText = ""
            activeAutosaveTranslatedText = ""
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
            activeAutosaveTranscriptID = nil
            activeAutosaveSourceText = ""
            activeAutosaveTranslatedText = ""
        } catch {
            statusMessage = AppText.saveLibraryFailed(error.localizedDescription)
        }
    }

    private func startCaptioners() async throws {
        try await transcriber.start(languages: [sourceLanguage])
    }

    private func stopCaptioners() {
        transcriber.stop()
    }

    private func resetLiveSessionState(clearsVisibleLines: Bool) {
        audioSampleCount = 0
        latestAudioLevel = nil
        lastRecognizedText = ""
        lastRecognizedWasFinal = false
        currentLineID = nil
        committedSourceText = ""
        currentPartialText = ""
        pendingParagraphBreakBeforePartial = false
        pendingTranslationSourceText = ""
        latestTranslationRequest = nil
        translationBurstStartedAt = Date.distantPast
        resetTranslationCache()
        activeAutosaveTranscriptID = nil
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
        let warmSourceLanguage = sourceLanguage
        let warmTargetLanguage = targetLanguage
        let warmSelectedModel = selectedModel

        Task { @MainActor in
            try? await translator.prepare(
                source: warmSourceLanguage,
                target: warmTargetLanguage,
                model: warmSelectedModel
            )
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
    }

    private func persistSelectedSettings() {
        guard !isRestoringSelectedSettings else { return }

        let defaults = UserDefaults.standard
        defaults.set(sourceLanguage.id, forKey: SettingsKey.sourceLanguageID)
        defaults.set(targetLanguage.id, forKey: SettingsKey.targetLanguageID)
        defaults.set(selectedModel.id, forKey: SettingsKey.selectedModelID)
        defaults.set(isDubbingEnabled, forKey: SettingsKey.isDubbingEnabled)
        defaults.set(isTranscriptLintEnabled, forKey: SettingsKey.isTranscriptLintEnabled)
        defaults.set(floatingCaptionDisplayMode.id, forKey: SettingsKey.floatingCaptionDisplayMode)
        defaults.set(floatingCaptionTextSize.id, forKey: SettingsKey.floatingCaptionTextSize)
        defaults.set(floatingCaptionLineCount.id, forKey: SettingsKey.floatingCaptionLineCount)
        defaults.set(paragraphBreakSilenceInterval, forKey: SettingsKey.paragraphBreakSilenceInterval)
        defaults.set(savedTranscriptContentMode.id, forKey: SettingsKey.savedTranscriptContentMode)
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
        let sourceText = activeAutosaveSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else { return false }

        let updatedAt = Date()
        let baseFileName = activeAutosaveTranscriptID ?? makeTranscriptFileName(for: sourceText, date: updatedAt)
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

        activeAutosaveTranscriptID = nil
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
            .appendingPathComponent("AirTranslate", isDirectory: true)
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
        recognizedLanguage: LanguageOption,
        confidence _: Double,
        isFinal: Bool
    ) async {
        guard isRunning, !isPaused else { return }
        guard sourceText != lastRecognizedText || isFinal != lastRecognizedWasFinal else { return }
        guard let direction = translationDirection(for: sourceText, recognizedLanguage: recognizedLanguage) else { return }

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

        let line: CaptionLine
        if let currentLineID,
           let index = lines.firstIndex(where: { $0.id == currentLineID }) {
            let existingLine = lines[index]
            guard updatedSourceText != existingLine.sourceText else { return }

            line = CaptionLine(
                id: existingLine.id,
                sourceText: updatedSourceText,
                translatedText: existingLine.translatedText,
                translatedSourceText: existingLine.translatedSourceText,
                createdAt: existingLine.createdAt,
                isFinal: isFinal,
                revision: existingLine.revision + 1
            )
            lines[index] = line
        } else {
            line = CaptionLine(
                sourceText: updatedSourceText,
                translatedText: AppText.translating,
                createdAt: Date(),
                isFinal: isFinal,
                revision: 1
            )
            currentLineID = line.id
            lines.append(line)
        }

        stageTranscriptForSave(line.sourceText)
        requestTranslation(for: line, source: direction.source, target: direction.target)
    }

    private func accumulatedTranscript(incoming: String, hadLongSilence: Bool) -> String {
        let trimmedIncoming = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIncoming.isEmpty else { return visibleTranscript() }

        if hadLongSilence, !currentPartialText.isEmpty {
            commitCurrentPartial()
            pendingParagraphBreakBeforePartial = !committedSourceText.isEmpty
        }

        let incomingPartial = uncommittedIncomingText(
            from: trimmedIncoming,
            allowsCommittedRevision: !hadLongSilence,
            allowsCommittedReplay: !hadLongSilence
        )
        guard !incomingPartial.isEmpty else { return visibleTranscript() }

        if currentPartialText.isEmpty {
            currentPartialText = incomingPartial
            return visibleTranscript()
        }

        if isRevisionOfCurrentPartial(incomingPartial) {
            currentPartialText = preferredPartialText(current: currentPartialText, incoming: incomingPartial)
            return visibleTranscript()
        }

        commitCurrentPartial()
        pendingParagraphBreakBeforePartial = hadLongSilence && !committedSourceText.isEmpty
        currentPartialText = uncommittedIncomingText(
            from: trimmedIncoming,
            allowsCommittedRevision: true,
            allowsCommittedReplay: true
        )
        return visibleTranscript()
    }

    private func uncommittedIncomingText(
        from incoming: String,
        allowsCommittedRevision: Bool,
        allowsCommittedReplay: Bool
    ) -> String {
        if allowsCommittedReplay, committedTranscriptAlreadyMatches(incoming) {
            return ""
        }

        if allowsCommittedRevision,
           replaceCommittedUnitsIfRevision(with: incoming, allowsBackfill: true) {
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

    private func incomingTailAfterCommittedText(
        _ incoming: String,
        allowsCommittedReplay: Bool
    ) -> String? {
        let normalizedCommitted = normalizedTranscriptForComparison(committedSourceText)
        let normalizedIncoming = normalizedTranscriptForComparison(incoming)
        guard isWholeTextPrefix(normalizedCommitted, of: normalizedIncoming) else {
            return nil
        }

        guard normalizedIncoming != normalizedCommitted else {
            if allowsCommittedReplay,
               transcriptUnits(from: incoming).count > 1 || shouldSuppressExactRecentRepeat(normalizedIncoming) {
                return ""
            }

            return nil
        }

        guard let tailStart = originalIndex(
            in: incoming,
            afterNormalizedPrefix: normalizedCommitted
        ) else {
            return nil
        }

        return String(incoming[tailStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func originalIndex(
        in text: String,
        afterNormalizedPrefix normalizedPrefix: String
    ) -> String.Index? {
        guard !normalizedPrefix.isEmpty else { return text.startIndex }

        var normalizedText = ""
        var previousWasWhitespace = true

        for index in text.indices {
            let character = text[index]
            let nextIndex = text.index(after: index)

            if character.isWhitespace {
                guard !previousWasWhitespace else { continue }
                previousWasWhitespace = true
                normalizedText.append(" ")
            } else {
                previousWasWhitespace = false
                normalizedText.append(character)
            }

            guard normalizedPrefix.hasPrefix(normalizedText) else {
                return nil
            }

            if normalizedText == normalizedPrefix {
                return nextIndex
            }
        }

        return nil
    }

    private func isRevisionOfCurrentPartial(_ incomingPartial: String) -> Bool {
        let normalizedCurrent = normalizedTranscriptForComparison(currentPartialText)
        let normalizedIncoming = normalizedTranscriptForComparison(incomingPartial)
        guard !normalizedCurrent.isEmpty, !normalizedIncoming.isEmpty else {
            return false
        }

        if normalizedIncoming == normalizedCurrent
            || isWholeTextPrefix(normalizedCurrent, of: normalizedIncoming)
            || isWholeTextPrefix(normalizedIncoming, of: normalizedCurrent) {
            return true
        }

        let sharedPrefixLength = commonPrefixLength(normalizedCurrent, normalizedIncoming)
        let shorterLength = min(normalizedCurrent.count, normalizedIncoming.count)
        return shorterLength >= 12 && sharedPrefixLength * 2 >= shorterLength
    }

    private func preferredPartialText(current: String, incoming: String) -> String {
        let normalizedCurrent = normalizedTranscriptForComparison(current)
        let normalizedIncoming = normalizedTranscriptForComparison(incoming)

        if normalizedCurrent.count > normalizedIncoming.count + 2 {
            return current
        }

        return incoming
    }

    private func isWholeTextPrefix(_ prefix: String, of text: String) -> Bool {
        guard !prefix.isEmpty, text.hasPrefix(prefix) else { return false }
        guard text != prefix else { return true }
        guard let nextCharacter = text.dropFirst(prefix.count).first,
              let previousCharacter = prefix.last
        else {
            return true
        }

        return !isLetterOrNumber(previousCharacter) || !isLetterOrNumber(nextCharacter)
    }

    private func isLetterOrNumber(_ character: Character) -> Bool {
        let lettersAndNumbers = CharacterSet.letters.union(.decimalDigits)
        return character.unicodeScalars.allSatisfy { lettersAndNumbers.contains($0) }
    }

    private func commitCurrentPartial() {
        let partial = organizeTranscript(currentPartialText, language: sourceLanguage)
        guard !partial.isEmpty else { return }

        if committedSourceText.isEmpty {
            committedSourceText = partial
        } else if replaceCommittedUnitsIfRevision(with: partial, allowsBackfill: false) {
            // The speech recognizer can resend the last phrase with better wording after
            // cleanup. Treat that as a replacement, not a new line.
        } else if shouldAppendCommittedPartial(partial) {
            let separator = pendingParagraphBreakBeforePartial ? "\n\n" : "\n"
            committedSourceText += separator + partial
        }
        pendingParagraphBreakBeforePartial = false
        currentPartialText = ""
    }

    private func replaceCommittedUnitsIfRevision(with text: String, allowsBackfill: Bool) -> Bool {
        let revisedText = organizeTranscript(text, language: sourceLanguage)
        let incomingUnits = transcriptUnits(from: revisedText)
        guard !incomingUnits.isEmpty else { return false }

        var committedUnits = transcriptUnits(from: committedSourceText)
        guard !committedUnits.isEmpty else { return false }

        if incomingUnits.count > 1 {
            guard incomingUnits.count <= committedUnits.count else { return false }

            let suffixStartIndex = committedUnits.count - incomingUnits.count
            let suffixPairs = zip(incomingUnits, committedUnits[suffixStartIndex...])
            guard suffixPairs.allSatisfy({
                isLikelyRecentTranscriptRevision($0.text, of: $1.text, allowsExactRepeat: false)
                    || normalizedTranscriptForComparison($0.text) == normalizedTranscriptForComparison($1.text)
            }) else {
                return false
            }
            guard suffixPairs.contains(where: {
                normalizedTranscriptForComparison($0.text) != normalizedTranscriptForComparison($1.text)
            }) else {
                return false
            }

            for (offset, incomingUnit) in incomingUnits.enumerated() {
                let index = suffixStartIndex + offset
                committedUnits[index].text = preferredCommittedRevision(
                    existing: committedUnits[index].text,
                    incoming: incomingUnit.text
                )
            }
            committedSourceText = transcriptText(from: committedUnits)
            return true
        }

        guard let incomingUnit = incomingUnits.first else { return false }

        let tailIndex = committedUnits.count - 1
        let firstSearchIndex = allowsBackfill
            ? max(0, committedUnits.count - Self.committedRevisionSearchLimit)
            : tailIndex

        for index in stride(from: tailIndex, through: firstSearchIndex, by: -1) {
            if index < tailIndex, committedUnits[tailIndex].separatorBefore == "\n\n" {
                break
            }

            let existingText = committedUnits[index].text
            let isTail = index == tailIndex
            guard isLikelyRecentTranscriptRevision(
                incomingUnit.text,
                of: existingText,
                allowsExactRepeat: isTail
            ) else {
                continue
            }

            committedUnits[index].text = preferredCommittedRevision(
                existing: existingText,
                incoming: incomingUnit.text
            )
            committedSourceText = transcriptText(from: committedUnits)
            return true
        }

        return false
    }

    private func isLikelyRecentTranscriptRevision(
        _ incoming: String,
        of existing: String,
        allowsExactRepeat: Bool
    ) -> Bool {
        let normalizedIncoming = normalizedTranscriptForComparison(incoming)
        let normalizedExisting = normalizedTranscriptForComparison(existing)
        guard normalizedIncoming != normalizedExisting,
              normalizedIncoming.count >= 12,
              normalizedExisting.count >= 12
        else {
            return allowsExactRepeat && shouldSuppressExactRecentRepeat(normalizedIncoming)
        }

        if isWholeTextPrefix(normalizedIncoming, of: normalizedExisting)
            || isWholeTextPrefix(normalizedExisting, of: normalizedIncoming) {
            return true
        }

        let incomingTokens = transcriptTokens(from: normalizedIncoming)
        let existingTokens = transcriptTokens(from: normalizedExisting)
        let smallerCount = min(incomingTokens.count, existingTokens.count)
        guard smallerCount >= 5 else { return false }

        let sharedPrefixLength = commonPrefixLength(normalizedIncoming, normalizedExisting)
        let overlapCount = orderedTokenOverlapCount(incomingTokens, existingTokens)
        let overlapRatio = Double(overlapCount) / Double(smallerCount)
        let shorterLength = min(normalizedIncoming.count, normalizedExisting.count)
        let longerLength = max(normalizedIncoming.count, normalizedExisting.count)
        let lengthRatio = Double(longerLength) / Double(shorterLength)

        if sharedPrefixLength >= 8,
           overlapCount >= 4,
           overlapRatio >= 0.58,
           lengthRatio <= 2.25 {
            return true
        }

        if overlapCount >= 8,
           overlapRatio >= 0.74,
           lengthRatio <= 1.35 {
            return true
        }

        return overlapCount >= 5
            && overlapRatio >= 0.78
            && lengthRatio <= 1.6
    }

    private func preferredCommittedRevision(existing: String, incoming: String) -> String {
        let normalizedExisting = normalizedTranscriptForComparison(existing)
        let normalizedIncoming = normalizedTranscriptForComparison(incoming)

        if normalizedIncoming.count * 5 >= normalizedExisting.count * 3 {
            return incoming
        }

        return existing
    }

    private func orderedTokenOverlapCount(_ lhs: [String], _ rhs: [String]) -> Int {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }

        var previousRow = Array(repeating: 0, count: rhs.count + 1)
        for lhsToken in lhs {
            var currentRow = Array(repeating: 0, count: rhs.count + 1)
            for (rhsIndex, rhsToken) in rhs.enumerated() {
                if lhsToken == rhsToken {
                    currentRow[rhsIndex + 1] = previousRow[rhsIndex] + 1
                } else {
                    currentRow[rhsIndex + 1] = max(previousRow[rhsIndex + 1], currentRow[rhsIndex])
                }
            }
            previousRow = currentRow
        }

        return previousRow[rhs.count]
    }

    private func transcriptTokens(from text: String) -> [String] {
        let allowedCharacters = CharacterSet.letters
            .union(.decimalDigits)
            .union(.whitespacesAndNewlines)
        let filteredText = String(text.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : " "
        })

        return filteredText
            .lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 1 }
    }

    private func committedTranscriptAlreadyMatches(_ text: String) -> Bool {
        let committed = committedSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !committed.isEmpty else { return false }

        let normalizedCommitted = normalizedTranscriptForComparison(committed)
        let normalizedText = normalizedTranscriptForComparison(text)
        guard !normalizedText.isEmpty else { return false }

        return normalizedCommitted == normalizedText
            && (transcriptUnits(from: committed).count > 1 || shouldSuppressExactRecentRepeat(normalizedText))
    }

    private func shouldAppendCommittedPartial(_ partial: String) -> Bool {
        let normalizedPartial = normalizedTranscriptForComparison(partial)
        guard !normalizedPartial.isEmpty else { return false }

        guard !committedTranscriptAlreadyMatches(partial) else { return false }

        let partialUnits = transcriptUnits(from: partial)
        let committedUnits = transcriptUnits(from: committedSourceText)
        guard partialUnits.count == 1,
              let partialUnit = partialUnits.first,
              let lastCommittedUnit = committedUnits.last
        else {
            return true
        }

        let normalizedPartialUnit = normalizedTranscriptForComparison(partialUnit.text)
        let normalizedLastUnit = normalizedTranscriptForComparison(lastCommittedUnit.text)
        return normalizedPartialUnit != normalizedLastUnit
            || pendingParagraphBreakBeforePartial
            || !shouldSuppressExactRecentRepeat(normalizedPartialUnit)
    }

    private func shouldSuppressExactRecentRepeat(_ normalizedText: String) -> Bool {
        normalizedText.count >= 15
            && transcriptTokens(from: normalizedText).count >= 4
    }

    private func transcriptUnits(from text: String) -> [TranscriptUnit] {
        var units: [TranscriptUnit] = []
        var buffer = ""
        var newlineCount = 0
        var separatorForNext = ""
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        func appendBufferedUnit() {
            let trimmedText = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                buffer = ""
                return
            }

            let separator = units.isEmpty ? "" : (separatorForNext.isEmpty ? "\n" : separatorForNext)
            units.append(TranscriptUnit(separatorBefore: separator, text: trimmedText))
            buffer = ""
            separatorForNext = ""
        }

        for character in normalizedText {
            if character == "\n" {
                appendBufferedUnit()
                newlineCount += 1
                continue
            }

            if newlineCount > 0 {
                separatorForNext = newlineCount >= 2 ? "\n\n" : "\n"
                newlineCount = 0
            }
            buffer.append(character)
        }

        appendBufferedUnit()
        return units
    }

    private func transcriptText(from units: [TranscriptUnit]) -> String {
        units.enumerated().map { index, unit in
            if index == 0 {
                return unit.text
            }

            let separator = unit.separatorBefore.isEmpty ? "\n" : unit.separatorBefore
            return separator + unit.text
        }
        .joined()
    }

    private func normalizedTranscriptForComparison(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func visibleTranscript() -> String {
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

    private func scheduleTranscriptCleanup() {
        guard isRunning, currentLineID != nil else { return }
        guard Date().timeIntervalSince(lastRecognitionAt) > 1.5 else { return }

        transcriptCleanupTask?.cancel()
        transcriptCleanupTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            organizeCurrentTranscript()
        }
    }

    private func organizeCurrentTranscript(sourceTextOverride: String? = nil) {
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
            revision: line.revision + 1
        )

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
        paragraphParts(from: text)
            .map {
                let organized = organizeParagraph($0, language: language)
                return appliesLint ? lintParagraph(organized, language: language) : organized
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func organizeParagraph(_ text: String, language: LanguageOption) -> String {
        var organized = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        organized = organized.replacingOccurrences(
            of: #"([.!?。！？]+)\s+"#,
            with: "$1\n",
            options: .regularExpression
        )

        if language.id == "ko-KR" {
            organized = organized.replacingOccurrences(
                of: #"(습니다|니다|어요|아요|세요|군요|네요|죠|지요|다)\s+"#,
                with: "$1\n",
                options: .regularExpression
            )
        }

        return organized
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
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
        let marker = "\u{1E}"
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"[ \t]*\n{2,}[ \t]*"#, with: marker, options: .regularExpression)

        return normalized
            .components(separatedBy: marker)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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

                let translatedSegment = try await translator.translate(
                    segment,
                    source: source,
                    target: target,
                    model: selectedModel
                )
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

    private func requestTranslation(for line: CaptionLine, source: LanguageOption, target: LanguageOption) {
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
                let delay = translationDebounceDelay()
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
                statusMessage = error.localizedDescription
            }
        }

        translationTask = nil
    }

    private func translationDebounceDelay() -> Int {
        guard translationBurstStartedAt != .distantPast else { return 45 }
        let burstAge = Date().timeIntervalSince(translationBurstStartedAt)
        return burstAge >= 0.45 ? 0 : 70
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
            revision: lines[index].revision + 1
        )

        speakTranslatedDeltaIfNeeded(organizedTranslatedText)
    }

    private func translationDirection(
        for text: String,
        recognizedLanguage: LanguageOption
    ) -> (source: LanguageOption, target: LanguageOption)? {
        (sourceLanguage, targetLanguage)
    }

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        speechOutput.speak(text, language: targetLanguage)
    }

    private func speakTranslatedDeltaIfNeeded(_ translatedText: String) {
        guard isRunning, isDubbingEnabled else { return }

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
    }
}

extension TranslationSessionStore: SystemAudioCaptureDelegate {
    nonisolated func systemAudioCapture(_ capture: SystemAudioCapture, didOutput sampleBuffer: CMSampleBuffer) {
        transcriber.append(sampleBuffer)
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

    nonisolated func liveSpeechTranscriber(_ transcriber: LiveSpeechTranscriber, didFail error: Error) {
        Task { @MainActor in
            statusMessage = error.localizedDescription
        }
    }
}
