import QuickLateCore
import SwiftUI

private let workspaceDensity = QuickLateViewDensityMetrics.comfortableDesktop

struct CommandWorkspaceView: View {
    @State private var viewModel: WorkspaceViewModel
    @State private var isFloatingCaptionVisible = FloatingCaptionWindowController.isOpen

    init(session: TranslationSessionStore) {
        _viewModel = State(initialValue: WorkspaceViewModel(session: session))
    }

    var body: some View {
        VStack(spacing: 18) {
            topBar
            HStack(spacing: 18) {
                TranscriptPaneView(
                    title: AppText.original,
                    subtitle: AppText.originalDescription,
                    text: viewModel.session.visibleTranscript(),
                    isTranslation: false,
                    accentColor: QuickLatePalette.originalAccent
                )
                TranscriptPaneView(
                    title: AppText.translation,
                    subtitle: AppText.translationDescription,
                    text: viewModel.session.visibleTranslatedText(),
                    isTranslation: true,
                    accentColor: QuickLatePalette.translationAccent
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(18)
        .onAppear(perform: syncFloatingCaptionVisibility)
        .onReceive(NotificationCenter.default.publisher(for: FloatingCaptionWindowController.visibilityDidChangeNotification)) { _ in
            syncFloatingCaptionVisibility()
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    QuickLateWordmarkView()
                    Text(workspaceSummary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(QuickLatePalette.slate)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    statusBadge

                    SettingsLink {
                        TopBarSecondaryActionLabel(
                            title: AppText.settings,
                            systemImage: "gearshape",
                            accentColor: QuickLatePalette.primary
                        )
                    }
                    .buttonStyle(TopBarPressButtonStyle())
                    .help(AppText.openSettings)

                    Button(action: showFloatingCaptions) {
                        TopBarSecondaryActionLabel(
                            title: AppText.floatingCaptions,
                            systemImage: isFloatingCaptionVisible ? "captions.bubble.fill" : "captions.bubble",
                            accentColor: isFloatingCaptionVisible ? QuickLatePalette.success : QuickLatePalette.primary
                        )
                    }
                    .buttonStyle(TopBarPressButtonStyle())
                    .help(AppText.showFloatingCaptions)

                    Button {
                        viewModel.requestStart()
                    } label: {
                        TopBarPrimaryActionLabel(
                            title: primaryActionTitle,
                            systemImage: primaryActionSystemImage,
                            accentColor: primaryActionAccentColor
                        )
                    }
                    .buttonStyle(TopBarPressButtonStyle())
                }
            }

            HStack(alignment: .center, spacing: 12) {
                WorkspaceProcessingEnginePicker(
                    selection: processingEngineBinding,
                    isDisabled: viewModel.session.isRunning
                )

                Divider()
                    .frame(height: 28)

                languageControls
            }

            if viewModel.session.applePreflightState.showsDownloadProgress {
                LanguagePackDownloadProgressView()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(QuickLatePalette.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXXL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXXL, style: .continuous)
                .strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
        }
        .shadow(color: QuickLatePalette.primaryDeep.opacity(0.06), radius: 26, x: 0, y: 14)
    }

    private var workspaceSummary: String {
        let language = AppText.languageSummary(
            source: viewModel.session.sourceLanguage.localizedTitle,
            target: viewModel.session.targetLanguage.localizedTitle
        )
        return "\(language) · \(WorkspaceProcessingEngine.current(for: viewModel.session).title)"
    }

    private var statusBadgeTitle: String {
        switch viewModel.session.applePreflightState.primaryAction {
        case .start:
            viewModel.session.isRunning ? AppText.listening : AppText.ready
        case .wait:
            AppText.checkingLanguagePacks
        case .downloadAndStart, .retryDownload:
            AppText.languagePackNeeded
        case .changeLanguagePair:
            AppText.changeLanguagePair
        case .openSystemSettings:
            AppText.openPrivacySettings
        }
    }

    private var statusBadgeColor: Color {
        switch viewModel.session.applePreflightState.primaryAction {
        case .start:
            viewModel.session.isRunning ? QuickLatePalette.success : QuickLatePalette.primary
        case .wait:
            QuickLatePalette.attention
        case .downloadAndStart, .retryDownload, .changeLanguagePair, .openSystemSettings:
            QuickLatePalette.attention
        }
    }

    private var statusBadge: some View {
        Text(statusBadgeTitle)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(statusBadgeColor)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(statusBadgeColor.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private var languageControls: some View {
        switch languageControlMode {
        case .autoDetectTargetOnly:
            HStack(spacing: 10) {
                AutoDetectLanguageBadge()

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(QuickLatePalette.slate)

                LanguageMenuChip(
                    title: AppText.preferredLanguageShort,
                    systemImage: "globe",
                    selection: targetLanguageBinding,
                    isDisabled: viewModel.session.isRunning
                )
            }
            .help(AppText.openAILanguageModeDescription)
        case .manualSourceAndTarget:
            HStack(spacing: 8) {
                LanguageMenuChip(
                    title: AppText.from,
                    systemImage: "waveform",
                    selection: sourceLanguageBinding,
                    isDisabled: viewModel.session.isRunning
                )

                Button(action: swapLanguages) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(viewModel.session.isRunning ? QuickLatePalette.steel : QuickLatePalette.primary)
                        .frame(width: 34, height: 34)
                        .background(QuickLatePalette.primarySoft, in: Circle())
                }
                .buttonStyle(TopBarPressButtonStyle())
                .disabled(viewModel.session.isRunning)
                .help(AppText.swapLanguages)
                .accessibilityLabel(AppText.swapLanguages)

                LanguageMenuChip(
                    title: AppText.to,
                    systemImage: "text.bubble",
                    selection: targetLanguageBinding,
                    isDisabled: viewModel.session.isRunning
                )
            }
            .help(AppText.languageSummary(
                source: viewModel.session.sourceLanguage.localizedTitle,
                target: viewModel.session.targetLanguage.localizedTitle
            ))
        }
    }

    private var languageControlMode: TranslationLanguageControlMode {
        TranslationLanguageControlMode.resolved(
            usesOpenAIRealtimeTranslation: viewModel.session.isUsingOpenAIRealtimeTranslation
        )
    }

    private var processingEngineBinding: Binding<WorkspaceProcessingEngine> {
        Binding(
            get: { WorkspaceProcessingEngine.current(for: viewModel.session) },
            set: { engine in
                guard !viewModel.session.isRunning else { return }
                switch engine {
                case .apple:
                    viewModel.session.useAppleDefaultMode()
                case .gptAuto:
                    viewModel.session.useGPTRealtimeMode()
                    if !viewModel.session.hasOpenAIAPIKey {
                        viewModel.session.statusMessage = AppText.openAIAPIKeyRequiredForGPTMode
                    }
                }
            }
        )
    }

    private var sourceLanguageBinding: Binding<LanguageOption> {
        Binding(
            get: { viewModel.session.sourceLanguage },
            set: { viewModel.session.sourceLanguage = $0 }
        )
    }

    private var targetLanguageBinding: Binding<LanguageOption> {
        Binding(
            get: { viewModel.session.targetLanguage },
            set: { viewModel.session.targetLanguage = $0 }
        )
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

    private var primaryActionSystemImage: String {
        switch viewModel.session.applePreflightState.primaryAction {
        case .downloadAndStart, .retryDownload:
            "arrow.down.circle.fill"
        case .changeLanguagePair:
            "arrow.triangle.2.circlepath"
        case .wait:
            "hourglass"
        case .openSystemSettings:
            "gearshape.fill"
        case .start:
            viewModel.session.isRunning ? "stop.fill" : "play.fill"
        }
    }

    private var primaryActionAccentColor: Color {
        switch viewModel.session.applePreflightState.primaryAction {
        case .downloadAndStart, .retryDownload:
            QuickLatePalette.primaryDeep
        case .changeLanguagePair, .openSystemSettings:
            QuickLatePalette.primary
        case .wait:
            QuickLatePalette.attention
        case .start:
            viewModel.session.isRunning ? QuickLatePalette.critical : QuickLatePalette.primaryDeep
        }
    }

    private func showFloatingCaptions() {
        FloatingCaptionWindowController.toggle(session: viewModel.session)
        syncFloatingCaptionVisibility()
    }

    private func swapLanguages() {
        guard !viewModel.session.isRunning else { return }
        let sourceLanguage = viewModel.session.sourceLanguage
        viewModel.session.sourceLanguage = viewModel.session.targetLanguage
        viewModel.session.targetLanguage = sourceLanguage
    }

    private func syncFloatingCaptionVisibility() {
        isFloatingCaptionVisible = FloatingCaptionWindowController.isOpen
    }
}

private struct LanguagePackDownloadProgressView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(QuickLatePalette.primary)
                Text(AppText.languagePackDownloadInProgress)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(QuickLatePalette.inkDeep)
                    .lineLimit(1)
            }
            ProgressView()
                .progressViewStyle(.linear)
                .controlSize(.small)
                .tint(QuickLatePalette.primary)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppText.languagePackDownloadInProgress)
    }
}

private enum WorkspaceProcessingEngine: String, CaseIterable, Identifiable {
    case apple
    case gptAuto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple:
            AppText.appleProcessingMode
        case .gptAuto:
            AppText.localized(
                english: "GPT Auto",
                korean: "GPT 자동",
                japanese: "GPT自動",
                chineseSimplified: "GPT 自动"
            )
        }
    }

    @MainActor
    static func current(for session: TranslationSessionStore) -> WorkspaceProcessingEngine {
        session.isUsingOpenAIRealtimeTranslation ? .gptAuto : .apple
    }
}

private struct WorkspaceProcessingEnginePicker: View {
    @Binding var selection: WorkspaceProcessingEngine
    let isDisabled: Bool

    var body: some View {
        Picker(AppText.model, selection: $selection) {
            ForEach(WorkspaceProcessingEngine.allCases) { engine in
                Text(engine.title).tag(engine)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 176)
        .disabled(isDisabled)
        .accessibilityLabel(AppText.model)
    }
}

private struct AutoDetectLanguageBadge: View {
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(QuickLatePalette.primary)

            Text(AppText.autoDetectInput)
                .font(.system(size: workspaceDensity.languageChipFontSize, weight: .semibold))
                .foregroundStyle(QuickLatePalette.inkDeep)
                .lineLimit(workspaceDensity.languageChipLineLimit)
                .minimumScaleFactor(workspaceDensity.languageChipMinimumScaleFactor)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(QuickLatePalette.primarySoft, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(QuickLatePalette.primary.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct LanguageMenuChip: View {
    let title: String
    let systemImage: String
    @Binding var selection: LanguageOption
    let isDisabled: Bool

    var body: some View {
        Menu {
            ForEach(LanguageOption.supported) { language in
                Button(language.localizedTitle) {
                    selection = language
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(QuickLatePalette.primary)

                Text("\(title) \(selection.localizedTitle)")
                    .font(.system(size: workspaceDensity.languageChipFontSize, weight: .semibold))
                    .foregroundStyle(QuickLatePalette.inkDeep)
                    .lineLimit(workspaceDensity.languageChipLineLimit)
                    .minimumScaleFactor(workspaceDensity.languageChipMinimumScaleFactor)
                    .fixedSize(horizontal: true, vertical: false)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(QuickLatePalette.steel)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(QuickLatePalette.surfaceSoft, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityValue(selection.localizedTitle)
    }
}

private struct TopBarSecondaryActionLabel: View {
    let title: String
    let systemImage: String
    let accentColor: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: workspaceDensity.primaryButtonFontSize, weight: .bold))
            .foregroundStyle(accentColor)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, 17)
            .padding(.vertical, 11)
            .background(accentColor.opacity(0.11), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(accentColor.opacity(0.16), lineWidth: 1)
            }
    }
}

private struct TopBarPrimaryActionLabel: View {
    let title: String
    let systemImage: String
    let accentColor: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: workspaceDensity.primaryButtonFontSize, weight: .bold))
            .foregroundStyle(QuickLatePalette.onPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(accentColor, in: Capsule())
            .shadow(color: accentColor.opacity(0.18), radius: 16, x: 0, y: 8)
    }
}

private struct TopBarPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
