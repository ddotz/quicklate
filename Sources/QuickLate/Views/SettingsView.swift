import SwiftUI
@preconcurrency import Translation

struct SettingsView: View {
    @Bindable var session: TranslationSessionStore
    @State private var openAIAPIKey = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsHeader

                SettingsCard(title: AppText.processingSettings, systemImage: "slider.horizontal.3") {
                    processingSection
                }

                SettingsLanguageSection(session: session)

                SettingsCard(title: AppText.modelAssetSettings, systemImage: "arrow.down.circle") {
                    modelAssetsSection
                }

                SettingsCard(title: AppText.openAIAPIKey, systemImage: "key") {
                    openAISection
                }

                SettingsCard(title: AppText.floatingCaptions, systemImage: "captions.bubble") {
                    floatingCaptionsSection
                }

                SettingsCard(title: AppText.recordingSettings, systemImage: "text.alignleft") {
                    recordingSection
                }

                SettingsCard(title: AppText.appAndPermissions, systemImage: "macwindow") {
                    appAndPermissionsSection
                }
            }
            .padding(22)
        }
        .background(QuickLateStageBackground())
        .frame(width: 620)
        .frame(minHeight: 680)
        .translationTask(session.translationDownloadConfiguration) { translationSession in
            await session.handleTranslationDownloadSession(translationSession)
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 12) {
            QuickLateAppIconView(size: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(AppText.settings)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(QuickLatePalette.inkDeep)
                Text(AppText.settingsSummary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(QuickLatePalette.slate)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 2)
    }

    private var processingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(AppText.model, selection: processingEngineBinding) {
                ForEach(SettingsProcessingEngine.allCases) { engine in
                    Text(engine.title).tag(engine)
                }
            }
            .pickerStyle(.segmented)
            .disabled(session.isRunning)

            Text(processingDescription)
                .font(.caption)
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(AppText.translatedVoiceOutput, isOn: $session.isDubbingEnabled)
                .disabled(session.isRunning)

            Text(AppText.translatedVoiceOutputDescription)
                .font(.caption)
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(2)
        }
    }

    private var modelAssetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsAssetAvailabilityRow(
                title: IntelligenceModel.appleSystem.title,
                availability: session.modelAvailability(for: .appleSystem)
            ) {
                session.downloadModelAssets(for: .appleSystem)
            }

            Divider()

            SettingsAssetAvailabilityRow(
                title: AppText.speechLanguagePack,
                availability: session.modelAvailability(for: .appleSpeechOnly)
            ) {
                session.downloadModelAssets(for: .appleSpeechOnly)
            }

            SettingsAssetAvailabilityRow(
                title: AppText.translationLanguagePack,
                availability: session.modelAvailability(for: .appleOnDevice)
            ) {
                session.downloadModelAssets(for: .appleOnDevice)
            }

            HStack {
                Text(AppText.languagePackNeeded)
                    .font(.caption)
                    .foregroundStyle(QuickLatePalette.slate)
                Spacer()
                Button {
                    session.refreshModelAvailability()
                } label: {
                    Label(AppText.modelStatusChecking, systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
            }
        }
    }

    private var openAISection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SecureField(AppText.openAIAPIKeyPlaceholder, text: $openAIAPIKey)
                    .textFieldStyle(.roundedBorder)

                Button(AppText.saveOpenAIAPIKey) {
                    session.saveOpenAIAPIKey(openAIAPIKey)
                    openAIAPIKey = ""
                }
                .disabled(openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(AppText.removeOpenAIAPIKey) {
                    session.removeOpenAIAPIKey()
                    openAIAPIKey = ""
                }
                .disabled(!session.hasOpenAIAPIKey)
            }

            SettingsStatusLine(
                title: session.hasOpenAIAPIKey ? AppText.openAIAPIKeyConfigured : AppText.openAIAPIKeyNotConfigured,
                systemImage: session.hasOpenAIAPIKey ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                color: session.hasOpenAIAPIKey ? QuickLatePalette.success : QuickLatePalette.attention
            )

            Picker(AppText.gptTranscriptionModel, selection: $session.openAITranscriptionModel) {
                ForEach(OpenAIRealtimeTranscriptionModel.allCases) { model in
                    Text(model.title).tag(model)
                }
            }
            .disabled(session.isRunning)

            Picker(AppText.gptTranslationModel, selection: $session.openAITranslationModel) {
                ForEach(OpenAIRealtimeTranslationModel.allCases) { model in
                    Text(model.title).tag(model)
                }
            }
            .disabled(session.isRunning)

            Text(AppText.openAIAPIKeyDescription)
                .font(.caption)
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(3)
        }
    }

    private var floatingCaptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(AppText.floatingDisplay, selection: $session.floatingCaptionDisplayMode) {
                ForEach(FloatingCaptionDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Picker(AppText.floatingTextSize, selection: $session.floatingCaptionTextSize) {
                ForEach(FloatingCaptionTextSize.allCases) { size in
                    Text(size.title).tag(size)
                }
            }

            Picker(AppText.floatingLineCount, selection: $session.floatingCaptionLineCount) {
                ForEach(FloatingCaptionLineCount.allCases) { lineCount in
                    Text(lineCount.title).tag(lineCount)
                }
            }

            Text(AppText.floatingDisplayDescription)
                .font(.caption)
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(2)
        }
    }

    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(AppText.sessionLength, selection: $session.sessionDurationMode) {
                ForEach(SessionDurationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .disabled(session.isRunning)

            Text(session.sessionDurationMode.detail)
                .font(.caption)
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(3)

            Stepper(
                value: $session.paragraphBreakSilenceInterval,
                in: 1...15,
                step: 0.5
            ) {
                HStack {
                    Text(AppText.paragraphBreakSilenceInterval)
                    Spacer()
                    Text(AppText.seconds(session.paragraphBreakSilenceInterval))
                        .foregroundStyle(QuickLatePalette.slate)
                }
            }

            Toggle(AppText.transcriptLint, isOn: $session.isTranscriptLintEnabled)
                .disabled(session.isUsingOpenAIRealtime || session.isRunning)

            Picker(AppText.savedTranscriptContent, selection: $session.savedTranscriptContentMode) {
                ForEach(SavedTranscriptContentMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            HStack {
                Text(AppText.autoSaveDescription)
                    .font(.caption)
                    .foregroundStyle(QuickLatePalette.slate)
                    .lineLimit(3)
                Spacer()
                Button {
                    session.openTranscriptsFolder()
                } label: {
                    Label(AppText.openSaveFolder, systemImage: "folder")
                }
                .controlSize(.small)
            }
        }
    }

    private var appAndPermissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(AppText.showDockIcon, isOn: $session.showDockIcon)

            Text(AppText.showDockIconDescription)
                .font(.caption)
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(3)

            Divider()

            Text(AppText.permissionsHelp)
                .font(.caption)
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(4)

            Button {
                session.openPrivacySettings()
            } label: {
                Label(AppText.openPrivacySettings, systemImage: "lock.shield")
            }
            .controlSize(.small)
        }
    }

    private var processingEngineBinding: Binding<SettingsProcessingEngine> {
        Binding(
            get: { session.isUsingOpenAIRealtimeTranslation ? .gptAuto : .apple },
            set: { engine in
                guard !session.isRunning else { return }
                switch engine {
                case .apple:
                    session.useAppleDefaultMode()
                case .gptAuto:
                    session.useGPTRealtimeMode()
                    if !session.hasOpenAIAPIKey {
                        session.statusMessage = AppText.openAIAPIKeyRequiredForGPTMode
                    }
                }
            }
        )
    }

    private var processingDescription: String {
        session.isUsingOpenAIRealtimeTranslation
            ? AppText.openAILanguageModeDescription
            : AppText.appleProcessingModeDescription
    }
}

private enum SettingsProcessingEngine: String, CaseIterable, Identifiable {
    case apple
    case gptAuto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple:
            AppText.appleProcessingMode
        case .gptAuto:
            AppText.localized(english: "GPT Auto", korean: "GPT 자동")
        }
    }
}

private struct SettingsLanguageSection: View {
    @Bindable var session: TranslationSessionStore

    var body: some View {
        SettingsCard(title: AppText.languageSettings, systemImage: "globe") {
            VStack(alignment: .leading, spacing: 12) {
                if session.isUsingOpenAIRealtimeTranslation {
                    SettingsStatusLine(
                        title: AppText.autoDetectInput,
                        systemImage: "sparkles",
                        color: QuickLatePalette.primary
                    )

                    Picker(AppText.preferredLanguage, selection: $session.targetLanguage) {
                        ForEach(LanguageOption.supported) { language in
                            Text(language.localizedTitle).tag(language)
                        }
                    }
                    .disabled(session.isRunning)

                    Text(AppText.openAILanguageModeDescription)
                        .font(.caption)
                        .foregroundStyle(QuickLatePalette.slate)
                        .lineLimit(3)
                } else {
                    Picker(AppText.from, selection: $session.sourceLanguage) {
                        ForEach(LanguageOption.supported) { language in
                            Text(language.localizedTitle).tag(language)
                        }
                    }
                    .disabled(session.isRunning)

                    Picker(AppText.to, selection: $session.targetLanguage) {
                        ForEach(LanguageOption.supported) { language in
                            Text(language.localizedTitle).tag(language)
                        }
                    }
                    .disabled(session.isRunning)

                    Button {
                        let source = session.sourceLanguage
                        session.sourceLanguage = session.targetLanguage
                        session.targetLanguage = source
                    } label: {
                        Label(AppText.swapLanguages, systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(session.isRunning)
                    .controlSize(.small)
                }
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(QuickLatePalette.inkDeep)
                .lineLimit(1)

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuickLatePalette.surface, in: RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXL, style: .continuous)
                .strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
        }
        .shadow(color: QuickLatePalette.primaryDeep.opacity(0.05), radius: 18, x: 0, y: 10)
    }
}

private struct SettingsStatusLine: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.12), in: Capsule())
            .lineLimit(1)
    }
}

private struct SettingsAssetAvailabilityRow: View {
    let title: String
    let availability: ModelAvailability
    let download: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(QuickLatePalette.inkDeep)
                    .lineLimit(1)

                Text(availability.detail)
                    .font(.caption)
                    .foregroundStyle(QuickLatePalette.slate)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            if availability.state == .checking {
                ProgressView()
                    .controlSize(.small)
            } else if availability.state == .downloading {
                VStack(alignment: .trailing, spacing: 6) {
                    Text(AppText.modelStatusDownloading)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                    ProgressView()
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                        .tint(color)
                        .frame(width: 110)
                        .accessibilityLabel(AppText.languagePackDownloadInProgress)
                }
            } else if availability.state.canDownload {
                Button(availability.state == .failed ? AppText.retryDownload : AppText.download) {
                    download()
                }
                .controlSize(.small)
            } else {
                Text(availability.state.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
            }
        }
        .help(availability.detail)
    }

    private var symbolName: String {
        switch availability.state {
        case .checking:
            "clock"
        case .installed:
            "checkmark.seal.fill"
        case .downloadRequired, .downloading:
            "arrow.down.circle.fill"
        case .unsupported, .unavailable, .failed:
            "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch availability.state {
        case .checking:
            QuickLatePalette.steel
        case .installed:
            QuickLatePalette.success
        case .downloadRequired, .downloading:
            QuickLatePalette.attention
        case .unsupported, .unavailable, .failed:
            QuickLatePalette.critical
        }
    }
}
