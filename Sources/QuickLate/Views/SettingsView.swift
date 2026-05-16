import QuickLateCore
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

                SettingsCard(title: AppText.versionInfo, systemImage: "number") {
                    settingsVersionAndUpdatesSection
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
        VStack(alignment: .leading, spacing: 10) {
            SettingsSegmentedControl(
                title: AppText.model,
                options: SettingsProcessingEngine.allCases,
                selection: processingEngineBinding,
                titleForOption: { $0.title },
                isDisabled: session.isRunning
            )

            Text(processingDescription)
                .font(.caption)
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if session.isUsingOpenAIRealtimeTranslation {
                SettingsToggleRow(
                    title: AppText.translatedVoiceOutput,
                    subtitle: AppText.translatedVoiceOutputDescription,
                    systemImage: "speaker.wave.2.fill",
                    isOn: $session.isDubbingEnabled,
                    isDisabled: session.isRunning
                )
            }
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

        }
    }

    private var openAISection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SecureField(AppText.openAIAPIKeyPlaceholder, text: $openAIAPIKey)
                    .textFieldStyle(.plain)
                    .modifier(SettingsTextFieldSurface())

                SettingsActionButton(
                    title: AppText.saveOpenAIAPIKey,
                    systemImage: "checkmark",
                    action: {
                        session.saveOpenAIAPIKey(openAIAPIKey)
                        openAIAPIKey = ""
                    },
                    isDisabled: openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                SettingsActionButton(
                    title: AppText.removeOpenAIAPIKey,
                    systemImage: "trash",
                    tint: QuickLatePalette.critical,
                    action: {
                        session.removeOpenAIAPIKey()
                        openAIAPIKey = ""
                    },
                    isDisabled: !session.hasOpenAIAPIKey
                )
            }

            SettingsStatusLine(
                title: session.hasOpenAIAPIKey ? AppText.openAIAPIKeyConfigured : AppText.openAIAPIKeyNotConfigured,
                systemImage: session.hasOpenAIAPIKey ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                color: session.hasOpenAIAPIKey ? QuickLatePalette.success : QuickLatePalette.attention
            )

            HStack(spacing: 10) {
                SettingsMenuSelector(
                    title: AppText.gptTranscriptionModel,
                    systemImage: "waveform",
                    options: OpenAIRealtimeTranscriptionModel.allCases,
                    selection: $session.openAITranscriptionModel,
                    titleForOption: { $0.title },
                    isDisabled: session.isRunning
                )

                SettingsMenuSelector(
                    title: AppText.gptTranslationModel,
                    systemImage: "text.bubble",
                    options: OpenAIRealtimeTranslationModel.allCases,
                    selection: $session.openAITranslationModel,
                    titleForOption: { $0.title },
                    isDisabled: session.isRunning
                )
            }

            Text(AppText.openAIAPIKeyDescription)
                .font(.caption)
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(3)
        }
    }

    private var floatingCaptionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SettingsMenuSelector(
                    title: AppText.floatingDisplay,
                    systemImage: "rectangle.on.rectangle",
                    options: FloatingCaptionDisplayMode.allCases,
                    selection: $session.floatingCaptionDisplayMode,
                    titleForOption: { $0.title }
                )

                SettingsMenuSelector(
                    title: AppText.floatingTextSize,
                    systemImage: "textformat.size",
                    options: FloatingCaptionTextSize.allCases,
                    selection: $session.floatingCaptionTextSize,
                    titleForOption: { $0.title }
                )

                SettingsMenuSelector(
                    title: AppText.floatingLineCount,
                    systemImage: "line.3.horizontal",
                    options: FloatingCaptionLineCount.allCases,
                    selection: $session.floatingCaptionLineCount,
                    titleForOption: { $0.title }
                )
            }

            Text(AppText.floatingDisplayDescription)
                .font(.caption)
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(1)
        }
    }

    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SettingsMenuSelector(
                    title: AppText.sessionLength,
                    systemImage: "timer",
                    options: SessionDurationMode.allCases,
                    selection: $session.sessionDurationMode,
                    titleForOption: { $0.title },
                    isDisabled: session.isRunning
                )

                SettingsNumericStepper(
                    title: AppText.paragraphBreakSilenceInterval,
                    value: $session.paragraphBreakSilenceInterval,
                    range: 1...15,
                    step: 0.5
                )
            }

            Text(session.sessionDurationMode.detail)
                .font(.caption)
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(1)

            SettingsToggleRow(
                title: AppText.transcriptLint,
                subtitle: nil,
                systemImage: "checklist",
                isOn: $session.isTranscriptLintEnabled,
                isDisabled: session.isUsingOpenAIRealtime || session.isRunning
            )

            HStack(alignment: .bottom, spacing: 10) {
                SettingsMenuSelector(
                    title: AppText.savedTranscriptContent,
                    systemImage: "tray.full",
                    options: SavedTranscriptContentMode.allCases,
                    selection: $session.savedTranscriptContentMode,
                    titleForOption: { $0.title }
                )

                SettingsActionButton(
                    title: AppText.openSaveFolder,
                    systemImage: "folder",
                    action: { session.openTranscriptsFolder() }
                )
            }
        }
    }

    private var appAndPermissionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsToggleRow(
                title: AppText.showDockIcon,
                subtitle: AppText.showDockIconDescription,
                systemImage: "dock.rectangle",
                isOn: $session.showDockIcon
            )

            Divider()

            HStack(alignment: .center, spacing: 12) {
                Text(AppText.permissionsHelp)
                    .font(.caption)
                    .foregroundStyle(QuickLatePalette.slate)
                    .lineLimit(2)

                Spacer(minLength: 8)

                SettingsActionButton(
                    title: AppText.openPrivacySettings,
                    systemImage: "lock.shield",
                    action: { session.openPrivacySettings() }
                )
            }
        }
    }

    private var settingsVersionAndUpdatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("\(session.currentAppVersion) (\(session.currentAppBuild))", systemImage: "number")
                    .font(.system(size: settingsVersionFooterFontSize, weight: .bold))
                    .foregroundStyle(QuickLatePalette.inkDeep)
                    .lineLimit(1)

                Spacer(minLength: 8)

                SettingsActionButton(
                    title: AppText.checkForUpdates,
                    systemImage: "arrow.triangle.2.circlepath",
                    action: {
                        Task { @MainActor in
                            await session.checkForUpdates()
                        }
                    },
                    isDisabled: session.updateCheckState.isChecking
                )

                if session.updateCheckState.releaseURL != nil {
                    SettingsActionButton(
                        title: AppText.openUpdatePage,
                        systemImage: "arrow.up.right.square",
                        action: { session.openUpdatePage() }
                    )
                }
            }

            Label(settingsUpdateStatusText, systemImage: settingsUpdateStatusImage)
                .font(.system(size: settingsVersionFooterFontSize, weight: .semibold))
                .foregroundStyle(settingsUpdateStatusColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            session.refreshUpdateAvailabilityIfNeeded()
        }
    }

    private var settingsUpdateStatusText: String {
        switch session.updateCheckState {
        case .idle:
            AppText.updateCheckIdle
        case .checking:
            AppText.checkingForUpdates
        case let .updateAvailable(latestVersion, _):
            AppText.updateAvailable(latestVersion: latestVersion)
        case .upToDate:
            AppText.updateCheckUpToDate
        case let .failed(message):
            AppText.updateCheckFailed(message)
        }
    }

    private var settingsUpdateStatusImage: String {
        switch session.updateCheckState {
        case .idle:
            "arrow.triangle.2.circlepath"
        case .checking:
            "hourglass"
        case .updateAvailable:
            "arrow.down.circle.fill"
        case .upToDate:
            "checkmark.seal.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    private var settingsUpdateStatusColor: Color {
        switch session.updateCheckState {
        case .updateAvailable:
            QuickLatePalette.primary
        case .upToDate:
            QuickLatePalette.success
        case .failed:
            QuickLatePalette.critical
        case .idle, .checking:
            QuickLatePalette.slate
        }
    }

    private var settingsVersionFooterFontSize: CGFloat {
        CGFloat(QuickLateUIDensityMetrics.comfortableDesktop.settingsVersionFooterFontSize)
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

                    SettingsMenuSelector(
                        title: AppText.preferredLanguage,
                        systemImage: "globe",
                        options: LanguageOption.supported,
                        selection: $session.targetLanguage,
                        titleForOption: { $0.localizedTitle },
                        isDisabled: session.isRunning
                    )

                    Text(AppText.openAILanguageModeDescription)
                        .font(.caption)
                        .foregroundStyle(QuickLatePalette.slate)
                        .lineLimit(3)
                } else {
                    HStack(alignment: .bottom, spacing: 10) {
                        SettingsMenuSelector(
                            title: AppText.from,
                            systemImage: "waveform",
                            options: LanguageOption.supported,
                            selection: $session.sourceLanguage,
                            titleForOption: { $0.localizedTitle },
                            isDisabled: session.isRunning
                        )

                        SettingsIconButton(
                            systemImage: "arrow.left.arrow.right",
                            accessibilityLabel: AppText.swapLanguages,
                            action: swapLanguages,
                            isDisabled: session.isRunning
                        )

                        SettingsMenuSelector(
                            title: AppText.to,
                            systemImage: "text.bubble",
                            options: LanguageOption.supported,
                            selection: $session.targetLanguage,
                            titleForOption: { $0.localizedTitle },
                            isDisabled: session.isRunning
                        )
                    }
                }
            }
        }
    }

    private func swapLanguages() {
        let source = session.sourceLanguage
        session.sourceLanguage = session.targetLanguage
        session.targetLanguage = source
    }
}

private enum SettingsControlMetrics {
    static let controlHeight: CGFloat = 36
}

private struct SettingsTextFieldSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(QuickLatePalette.inkDeep)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(QuickLatePalette.surfaceSoft, in: RoundedRectangle(cornerRadius: QuickLateMetric.radiusXL, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: QuickLateMetric.radiusXL, style: .continuous)
                    .strokeBorder(QuickLatePalette.primary.opacity(0.22), lineWidth: 1)
            }
    }
}

private struct SettingsSegmentedControl<Option: Hashable>: View {
    let title: String
    let options: [Option]
    @Binding var selection: Option
    let titleForOption: (Option) -> String
    var isDisabled = false

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(QuickLatePalette.inkDeep)
                .lineLimit(1)

            HStack(spacing: 3) {
                ForEach(options, id: \.self) { option in
                    Button {
                        guard !isDisabled else { return }
                        selection = option
                    } label: {
                        Text(titleForOption(option))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(selection == option ? QuickLatePalette.onPrimary : QuickLatePalette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .padding(.horizontal, 10)
                            .background(selection == option ? QuickLatePalette.primary : Color.clear, in: Capsule())
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                }
            }
            .padding(3)
            .frame(width: 360)
            .background(QuickLatePalette.surfaceSoft, in: Capsule())
            .overlay {
                Capsule().strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
            }
            .opacity(isDisabled ? 0.56 : 1)
        }
    }
}

private struct SettingsMenuSelector<Option: Hashable>: View {
    let title: String
    let systemImage: String
    let options: [Option]
    @Binding var selection: Option
    let titleForOption: (Option) -> String
    var isDisabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(1)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(titleForOption(option)) {
                        selection = option
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(QuickLatePalette.primary)
                    Text(titleForOption(selection))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(QuickLatePalette.inkDeep)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(QuickLatePalette.steel)
                }
                .padding(.horizontal, 12)
                .frame(height: SettingsControlMetrics.controlHeight)
                .background(QuickLatePalette.surfaceSoft, in: RoundedRectangle(cornerRadius: QuickLateMetric.radiusXL, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: QuickLateMetric.radiusXL, style: .continuous)
                        .strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: QuickLateMetric.radiusXL, style: .continuous))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.56 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsActionButton: View {
    let title: String
    let systemImage: String
    var tint = QuickLatePalette.primary
    let action: () -> Void
    var isDisabled = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 11)
                .frame(height: SettingsControlMetrics.controlHeight)
                .background(tint.opacity(0.11), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(tint.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.48 : 1)
    }
}

private struct SettingsIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void
    var isDisabled = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(QuickLatePalette.primary)
                .frame(width: 34, height: 34)
                .background(QuickLatePalette.primarySoft, in: Circle())
                .overlay {
                    Circle().strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.48 : 1)
        .accessibilityLabel(accessibilityLabel)
    }
}

private let settingsCheckboxBorderColor = QuickLatePalette.steel.opacity(0.58)
private let settingsCheckboxBorderWidth: CGFloat = 1.35

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    @Binding var isOn: Bool
    var isDisabled = false

    var body: some View {
        Button {
            guard !isDisabled else { return }
            isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isOn ? QuickLatePalette.primary : QuickLatePalette.surface)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(QuickLatePalette.onPrimary)
                    }
                }
                .frame(width: 22, height: 22)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(checkboxBorderColor, lineWidth: isOn ? 1 : settingsCheckboxBorderWidth)
                }

                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isOn ? QuickLatePalette.primary : QuickLatePalette.steel)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(QuickLatePalette.inkDeep)
                        .lineLimit(1)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(QuickLatePalette.slate)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(QuickLatePalette.surfaceSoft.opacity(isOn ? 1 : 0.72), in: RoundedRectangle(cornerRadius: QuickLateMetric.radiusXL, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: QuickLateMetric.radiusXL, style: .continuous)
                    .strokeBorder(isOn ? QuickLatePalette.primary.opacity(0.2) : QuickLatePalette.hairlineSoft, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: QuickLateMetric.radiusXL, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.68 : 1)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }

    private var checkboxBorderColor: Color {
        isOn ? QuickLatePalette.primary.opacity(0.82) : settingsCheckboxBorderColor
    }
}

private struct SettingsNumericStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(1)

            HStack(spacing: 8) {
                stepButton(systemImage: "minus", delta: -step)

                Text(AppText.seconds(value))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(QuickLatePalette.inkDeep)
                    .lineLimit(1)
                    .frame(minWidth: 38)

                stepButton(systemImage: "plus", delta: step)
            }
            .padding(.horizontal, 10)
            .frame(height: SettingsControlMetrics.controlHeight)
            .background(QuickLatePalette.surfaceSoft, in: RoundedRectangle(cornerRadius: QuickLateMetric.radiusXL, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: QuickLateMetric.radiusXL, style: .continuous)
                    .strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepButton(systemImage: String, delta: Double) -> some View {
        Button {
            value = min(range.upperBound, max(range.lowerBound, value + delta))
        } label: {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(QuickLatePalette.primary)
                .frame(width: 22, height: 22)
                .background(QuickLatePalette.primarySoft, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(QuickLatePalette.inkDeep)
                .lineLimit(1)

            content
        }
        .padding(16)
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
                SettingsActionButton(
                    title: availability.state == .failed ? AppText.retryDownload : AppText.download,
                    systemImage: "arrow.down.circle",
                    tint: color,
                    action: download
                )
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
