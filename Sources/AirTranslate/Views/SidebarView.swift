import AppKit
import SwiftUI

struct SidebarView: View {
    @Bindable var session: TranslationSessionStore
    @State private var isLibraryPresented = false
    @State private var isConfigurationExpanded = false
    @State private var openAIAPIKey = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                brandHeader
                sessionCard
                libraryCard
            }
            .padding(12)
        }
        .background(.bar)
        .navigationTitle("AirTranslate")
        .sheet(isPresented: $isLibraryPresented) {
            TranscriptLibraryView(session: session)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            AppIconMark()

            VStack(alignment: .leading, spacing: 3) {
                Text(AppText.appName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(AppText.appTagline)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                CaptureStatusIndicator(
                    symbolName: statusSymbolName,
                    color: statusColor,
                    statusMessage: session.statusMessage
                )

                if needsPermissionAction {
                    Button {
                        session.openPrivacySettings()
                    } label: {
                        Image(systemName: "gear")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help(AppText.openPrivacySettings)
                    .accessibilityLabel(AppText.openPrivacySettings)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        }
    }

    private var sessionCard: some View {
        SidebarCard(
            title: AppText.translationSettings,
            headerAccessory: {
                expandConfigurationButton
            }
        ) {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    CompactLanguagePicker(title: AppText.from, selection: $session.sourceLanguage)

                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                        .accessibilityHidden(true)

                    CompactLanguagePicker(title: AppText.to, selection: $session.targetLanguage)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SessionDurationRadioGroup(
                    selection: $session.sessionDurationMode,
                    isDisabled: session.isRunning
                )

                Divider()

                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        isConfigurationExpanded.toggle()
                    }
                } label: {
                    ConfigurationSummaryRow(
                        modelTitle: "\(session.selectedModel.title) · \(session.sessionDurationMode.title)",
                        outputTitle: outputSummary,
                        isExpanded: isConfigurationExpanded
                    )
                }
                .buttonStyle(.plain)
                .help(AppText.configureTranslationSettings)
                .accessibilityLabel(AppText.configureTranslationSettings)
                .accessibilityValue(isConfigurationExpanded ? AppText.localized(english: "Expanded", korean: "펼쳐짐") : AppText.localized(english: "Collapsed", korean: "접힘"))

                if isConfigurationExpanded {
                    inlineConfigurationControls
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .onAppear {
            isConfigurationExpanded = false
            session.refreshModelAvailability()
        }
    }

    private var expandConfigurationButton: some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                isConfigurationExpanded.toggle()
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(isConfigurationExpanded ? Color.white : Color.accentColor)
                .frame(width: 26, height: 26)
                .background(isConfigurationExpanded ? Color.accentColor : Color.accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(AppText.configureTranslationSettings)
        .accessibilityLabel(AppText.configureTranslationSettings)
    }

    private var inlineConfigurationControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            InlineSettingsGroup(
                systemImage: "cpu",
                title: AppText.model
            ) {
                VStack(spacing: 6) {
                    ForEach(IntelligenceModel.allCases) { model in
                        Button {
                            session.selectedModel = model
                        } label: {
                            ModelModeRow(
                                model: model,
                                isSelected: session.selectedModel == model
                            )
                        }
                        .buttonStyle(.plain)
                        .help(model.detail)
                    }
                }
            }

            InlineSettingsGroup(
                systemImage: "sparkles",
                title: AppText.gptModels
            ) {
                VStack(spacing: 6) {
                    GPTModelMenuRow(
                        title: AppText.gptTranscriptionModel,
                        systemImage: "waveform",
                        value: session.openAITranscriptionModel.title
                    ) {
                        ForEach(OpenAIRealtimeTranscriptionModel.allCases) { model in
                            Button(model.title) {
                                session.openAITranscriptionModel = model
                            }
                        }
                    }

                    GPTModelMenuRow(
                        title: AppText.gptTranslationModel,
                        systemImage: "globe.asia.australia.fill",
                        value: session.openAITranslationModel.title
                    ) {
                        ForEach(OpenAIRealtimeTranslationModel.allCases) { model in
                            Button(model.title) {
                                session.openAITranslationModel = model
                            }
                        }
                    }

                    GPTAPIKeyRow(
                        apiKey: $openAIAPIKey,
                        hasAPIKey: session.hasOpenAIAPIKey,
                        save: {
                            session.saveOpenAIAPIKey(openAIAPIKey)
                            openAIAPIKey = ""
                        },
                        remove: {
                            session.removeOpenAIAPIKey()
                            openAIAPIKey = ""
                        }
                    )

                    Text(AppText.gptModelsDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }
            }

            InlineSettingsGroup(
                systemImage: "externaldrive.badge.checkmark",
                title: AppText.requiredAssets
            ) {
                VStack(spacing: 6) {
                    AssetAvailabilityRow(
                        title: AppText.speechLanguagePack,
                        availability: session.modelAvailability(for: .appleSpeechOnly),
                        helpText: "\(IntelligenceModel.appleSpeechOnly.detail)\n\(session.modelAvailability(for: .appleSpeechOnly).detail)"
                    ) {
                        session.downloadModelAssets(for: .appleSpeechOnly)
                    }

                    if session.selectedModel == .appleSystem || session.openAITranscriptionModel.isEnabled {
                        AssetAvailabilityRow(
                            title: AppText.translationLanguagePack,
                            availability: session.modelAvailability(for: .appleOnDevice),
                            helpText: "\(IntelligenceModel.appleOnDevice.detail)\n\(session.modelAvailability(for: .appleOnDevice).detail)"
                        ) {
                            session.downloadModelAssets(for: .appleOnDevice)
                        }
                    }
                }
            }

            InlineSettingsGroup(
                systemImage: "waveform.and.person.filled",
                title: AppText.liveOutput
            ) {
                VStack(spacing: 6) {
                    CompactToggleRow(
                        title: AppText.transcriptPolish,
                        systemImage: "text.badge.checkmark",
                        isOn: $session.isTranscriptLintEnabled
                    )
                    .help(AppText.transcriptLintDescription)

                    CompactToggleRow(
                        title: AppText.voiceOutput,
                        systemImage: "speaker.wave.2.fill",
                        isOn: $session.isDubbingEnabled
                    )
                }
            }
        }
    }

    private var outputSummary: String {
        switch (session.isTranscriptLintEnabled, session.isDubbingEnabled) {
        case (true, true):
            AppText.localized(
                english: "Polish + Voice",
                korean: "다듬기+음성"
            )
        case (true, false):
            AppText.localized(
                english: "Polish",
                korean: "다듬기"
            )
        case (false, true):
            AppText.localized(
                english: "Voice",
                korean: "음성"
            )
        case (false, false):
            AppText.localized(
                english: "Transcript only",
                korean: "기록만"
            )
        }
    }

    private var libraryCard: some View {
        SidebarCard(title: AppText.library) {
            VStack(alignment: .leading, spacing: 10) {
                Text(AppText.librarySummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    isLibraryPresented = true
                } label: {
                    Label(AppText.manageSavedTranscripts, systemImage: "tray.full")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .controlSize(.small)
            }
        }
    }

    private var needsPermissionAction: Bool {
        session.statusMessage.localizedCaseInsensitiveContains("permission")
            || session.statusMessage.localizedCaseInsensitiveContains("권한")
    }

    private var statusSymbolName: String {
        if session.isPaused {
            return "pause.circle.fill"
        }
        if session.isRunning {
            return "waveform.circle.fill"
        }
        return "circle.dotted"
    }

    private var statusColor: Color {
        if session.isPaused {
            return .orange
        }
        if session.isRunning {
            return .green
        }
        return .secondary
    }
}

private struct ConfigurationSummaryRow: View {
    let modelTitle: String
    let outputTitle: String
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(AppText.localized(english: "Session Options", korean: "세부 설정"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(modelTitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 6)

            Text(outputTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12), in: Capsule())

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 14)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct InlineSettingsGroup<Content: View>: View {
    let systemImage: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
        }
    }
}

private struct CompactToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                    .frame(width: 16)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .toggleStyle(.switch)
        .accessibilityLabel(title)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct GPTModelMenuRow<MenuContent: View>: View {
    let title: String
    let systemImage: String
    let value: String
    @ViewBuilder let menuContent: MenuContent

    var body: some View {
        Menu {
            menuContent
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 16)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 6)

                Text(value)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private struct GPTAPIKeyRow: View {
    @Binding var apiKey: String
    let hasAPIKey: Bool
    let save: () -> Void
    let remove: () -> Void

    private var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(hasAPIKey ? Color.green : Color.secondary)
                    .frame(width: 16)

                SecureField(AppText.openAIAPIKeyPlaceholder, text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)

                Button {
                    save()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(trimmedAPIKey.isEmpty)
                .help(AppText.saveOpenAIAPIKey)
                .accessibilityLabel(AppText.saveOpenAIAPIKey)

                Button {
                    remove()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(!hasAPIKey)
                .help(AppText.removeOpenAIAPIKey)
                .accessibilityLabel(AppText.removeOpenAIAPIKey)
            }

            Text(hasAPIKey ? AppText.openAIAPIKeyConfigured : AppText.openAIAPIKeyNotConfigured)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(hasAPIKey ? Color.green : Color.secondary)
                .padding(.leading, 24)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SessionDurationRadioGroup: View {
    @Binding var selection: SessionDurationMode
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: "timer")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                Text(AppText.sessionLength)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            Picker(AppText.sessionLength, selection: $selection) {
                ForEach(SessionDurationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .disabled(isDisabled)
            .accessibilityLabel(AppText.sessionLength)

            Text(selection.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

private struct CompactLanguagePicker: View {
    let title: String
    @Binding var selection: LanguageOption

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
                .lineLimit(1)

            Menu {
                ForEach(LanguageOption.supported) { language in
                    Button(language.localizedTitle) {
                        selection = language
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selection.localizedTitle)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .frame(width: 72)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(title)
            .accessibilityLabel(title)
            .accessibilityValue(selection.localizedTitle)
        }
        .frame(width: 100)
    }
}

private struct AppIconMark: View {
    private var appIcon: NSImage {
        NSImage(named: "AppIcon") ?? NSApp.applicationIconImage
    }

    var body: some View {
        Image(nsImage: appIcon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color.black.opacity(0.16), radius: 5, x: 0, y: 2)
            .accessibilityHidden(true)
    }
}

private struct CaptureStatusIndicator: View {
    let symbolName: String
    let color: Color
    let statusMessage: String

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.14))

            Circle()
                .strokeBorder(color.opacity(0.36), lineWidth: 1)

            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: 30, height: 30)
        .help(statusMessage)
        .accessibilityLabel(AppText.capture)
        .accessibilityValue(statusMessage)
    }
}

private struct ModelModeRow: View {
    let model: IntelligenceModel
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.callout.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.55))
                .frame(width: 18, height: 18)

            Text(model.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isSelected ? Color.accentColor : Color.primary).opacity(isSelected ? 0.11 : 0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder((isSelected ? Color.accentColor : Color.primary).opacity(isSelected ? 0.24 : 0.06), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct AssetAvailabilityRow: View {
    let title: String
    let availability: ModelAvailability
    let helpText: String
    let download: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: assetSymbolName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(availabilityColor)
                .frame(width: 28, height: 28)
                .background(availabilityColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(availability.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            trailingStatus
        }
        .padding(10)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .help(helpText)
    }

    @ViewBuilder
    private var trailingStatus: some View {
        if availability.state == .downloading || availability.state == .checking {
            ProgressView()
                .controlSize(.small)
                .help(availability.state.title)
        } else if availability.state.canDownload {
            Button {
                download()
            } label: {
                Label(AppText.download, systemImage: "arrow.down.circle")
                    .labelStyle(.iconOnly)
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(availabilityColor)
            .help(AppText.downloadModelAssets)
        } else {
            Text(availability.state.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(availabilityColor)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(availabilityColor.opacity(0.12), in: Capsule())
        }
    }

    private var assetSymbolName: String {
        switch availability.state {
        case .checking:
            "clock"
        case .installed:
            "checkmark.seal.fill"
        case .downloadRequired:
            "arrow.down.circle"
        case .downloading:
            "arrow.down.circle"
        case .unsupported, .unavailable, .failed:
            "exclamationmark.triangle.fill"
        }
    }

    private var availabilityColor: Color {
        switch availability.state {
        case .checking:
            .secondary
        case .installed:
            .green
        case .downloadRequired, .downloading:
            .orange
        case .unsupported, .unavailable, .failed:
            .red
        }
    }
}

private struct SidebarCard<Content: View, HeaderAccessory: View>: View {
    let title: String?
    @ViewBuilder let headerAccessory: HeaderAccessory
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) where HeaderAccessory == EmptyView {
        self.title = title
        self.headerAccessory = EmptyView()
        self.content = content()
    }

    init(
        title: String? = nil,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.headerAccessory = headerAccessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer(minLength: 0)

                    headerAccessory
                }
            }

            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        }
    }
}
