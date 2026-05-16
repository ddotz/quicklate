import AppKit
import QuickLateCore
import SwiftUI

struct MenuBarStatusView: View {
    @Bindable var session: TranslationSessionStore
    @Environment(\.openWindow) private var openWindow
    @State private var isFloatingCaptionVisible = FloatingCaptionWindowController.isOpen
    @State private var isAppInfoExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            actionGrid

            Divider()

            displayModeGrid

            Divider()

            captionFormatControls
        }
        .padding(16)
        .frame(width: 360)
        .background(QuickLatePalette.surface)
        .onAppear {
            syncFloatingCaptionVisibility()
        }
        .onReceive(NotificationCenter.default.publisher(for: FloatingCaptionWindowController.visibilityDidChangeNotification)) { _ in
            syncFloatingCaptionVisibility()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                QuickLateAppIconView(size: 30)

                Text(AppText.appName)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(QuickLatePalette.inkDeep)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        isAppInfoExpanded.toggle()
                    }
                } label: {
                    MenuBarAppInfoButton(hasError: session.lastErrorMessage != nil)
                }
                .buttonStyle(.plain)
                .help(AppText.appInfo)
                .accessibilityLabel(AppText.appInfo)
            }

            if isAppInfoExpanded {
                MenuBarAppVersionInfo(errorMessage: session.lastErrorMessage)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var actionGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            Button {
                toggleCapture()
            } label: {
                IconPanelButtonLabel(
                    systemImage: session.isRunning ? "stop.fill" : "play.fill",
                    title: session.isRunning ? AppText.stop : AppText.start,
                    subtitle: session.isRunning ? AppText.menuBarRunningTitle : AppText.ready,
                    accentColor: session.isRunning ? QuickLatePalette.critical : QuickLatePalette.primary,
                    isSelected: !session.isRunning
                )
            }
            .buttonStyle(.plain)

            Button {
                toggleFloatingCaptions()
            } label: {
                IconPanelButtonLabel(
                    systemImage: isFloatingCaptionVisible ? "captions.bubble.fill" : "captions.bubble",
                    title: AppText.floatingCaptions,
                    subtitle: isFloatingCaptionVisible ? AppText.floatingCaptionPowerOn : AppText.floatingCaptionPowerOff,
                    accentColor: isFloatingCaptionVisible ? QuickLatePalette.success : QuickLatePalette.primary,
                    isSelected: isFloatingCaptionVisible
                )
            }
            .buttonStyle(.plain)
            .help(AppText.showFloatingCaptions)
            .accessibilityLabel(AppText.showFloatingCaptions)
            .accessibilityValue(isFloatingCaptionVisible ? AppText.floatingCaptionPowerOn : AppText.floatingCaptionPowerOff)

            Button {
                MainWindowPresenter.showMainWindow(openWindow: openWindow)
            } label: {
                IconPanelButtonLabel(
                    systemImage: "house",
                    title: AppText.home,
                    subtitle: nil,
                    accentColor: QuickLatePalette.primary
                )
            }
            .buttonStyle(.plain)
            .help(AppText.openMainWindow)

            Button {
                SettingsWindowPresenter.showSettingsWindow()
            } label: {
                IconPanelButtonLabel(
                    systemImage: "gearshape",
                    title: AppText.settings,
                    subtitle: nil,
                    accentColor: QuickLatePalette.primary
                )
            }
            .buttonStyle(.plain)
            .help(AppText.openSettings)
        }
    }

    private var displayModeGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            ControlSectionHeader(
                systemImage: "rectangle.split.2x1",
                title: AppText.floatingDisplay
            )

            HStack(spacing: 8) {
                ForEach(FloatingCaptionDisplayMode.allCases) { mode in
                    Button {
                        session.floatingCaptionDisplayMode = mode
                    } label: {
                        IconChoiceLabel(
                            systemImage: mode.systemImage,
                            title: compactDisplayTitle(for: mode),
                            isSelected: session.floatingCaptionDisplayMode == mode
                        )
                    }
                    .buttonStyle(.plain)
                    .help(mode.title)
                    .accessibilityLabel(mode.title)
                    .accessibilityValue(session.floatingCaptionDisplayMode == mode ? AppText.localized(english: "Selected", korean: "선택됨", japanese: "選択中", chineseSimplified: "已选择") : "")
                }
            }
        }
    }

    private var captionFormatControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            ControlSectionHeader(
                systemImage: "slider.horizontal.3",
                title: AppText.localized(english: "Caption Style", korean: "자막 스타일", japanese: "字幕スタイル", chineseSimplified: "字幕样式")
            )

            HStack(spacing: 8) {
                Menu {
                    ForEach(FloatingCaptionTextSize.allCases) { size in
                        Button(size.title) {
                            session.floatingCaptionTextSize = size
                        }
                    }
                } label: {
                    IconMenuLabel(
                        systemImage: "textformat.size",
                        title: AppText.localized(english: "Size", korean: "크기", japanese: "サイズ", chineseSimplified: "大小"),
                        value: session.floatingCaptionTextSize.title
                    )
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .help(AppText.floatingTextSize)

                Menu {
                    ForEach(FloatingCaptionLineCount.allCases) { lineCount in
                        Button(lineCount.title) {
                            session.floatingCaptionLineCount = lineCount
                        }
                    }
                } label: {
                    IconMenuLabel(
                        systemImage: "line.3.horizontal",
                        title: AppText.localized(english: "Lines", korean: "줄 수", japanese: "行数", chineseSimplified: "行数"),
                        value: session.floatingCaptionLineCount.title
                    )
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .help(AppText.floatingLineCount)
            }
        }
    }

    private var statusSymbolName: String {
        if session.isPaused {
            return "pause.circle.fill"
        }
        if session.isRunning {
            return "waveform.circle.fill"
        }
        return "captions.bubble.fill"
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

    private func toggleFloatingCaptions() {
        FloatingCaptionWindowController.toggle(session: session)
        syncFloatingCaptionVisibility()
    }

    private func toggleCapture() {
        if session.isRunning {
            session.stop()
        } else {
            session.requestStartFromWorkspace()
        }
    }

    private func syncFloatingCaptionVisibility() {
        isFloatingCaptionVisible = FloatingCaptionWindowController.isOpen
    }

    private func compactDisplayTitle(for mode: FloatingCaptionDisplayMode) -> String {
        switch mode {
        case .original:
            AppText.originalOnly
        case .originalAndTranslation:
            AppText.localized(english: "Both", korean: "원문+번역", japanese: "両方", chineseSimplified: "两者")
        case .translation:
            AppText.translationOnly
        }
    }
}

private struct ControlSectionHeader: View {
    let systemImage: String
    let title: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(QuickLatePalette.slate)
    }
}

private struct MenuBarAppInfoButton: View {
    let hasError: Bool

    var body: some View {
        Image(systemName: hasError ? "exclamationmark.circle.fill" : "info.circle")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(hasError ? QuickLatePalette.critical : QuickLatePalette.inkDeep)
            .frame(width: 30, height: 30)
            .background((hasError ? QuickLatePalette.critical : QuickLatePalette.slate).opacity(0.1), in: Circle())
            .overlay {
                Circle().strokeBorder((hasError ? QuickLatePalette.critical : QuickLatePalette.hairlineSoft).opacity(0.75), lineWidth: 1)
            }
    }
}

private struct MenuBarAppVersionInfo: View {
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Label(AppText.versionInfo, systemImage: "number")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QuickLatePalette.slate)
                Spacer(minLength: 0)
                Text(versionText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(QuickLatePalette.inkDeep)
                    .lineLimit(1)
            }

            Divider()

            if let errorMessage, !errorMessage.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label(AppText.latestErrorInfo, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(QuickLatePalette.critical)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(QuickLatePalette.slate)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            } else {
                Label(AppText.noErrorInfo, systemImage: "checkmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QuickLatePalette.success)
            }
        }
        .padding(10)
        .background(QuickLatePalette.surfaceSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct IconPanelButtonLabel: View {
    let systemImage: String
    let title: String
    let subtitle: String?
    let accentColor: Color
    var isSelected = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accentColor)
                .frame(width: 32, height: 32)
                .background(accentColor.opacity(0.12), in: Circle())

            VStack(spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QuickLatePalette.inkDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(QuickLatePalette.slate)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(isSelected ? accentColor.opacity(0.11) : QuickLatePalette.surfaceSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? accentColor.opacity(0.18) : QuickLatePalette.hairlineSoft, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct IconChoiceLabel: View {
    let systemImage: String
    let title: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))

            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(isSelected ? QuickLatePalette.onPrimary : QuickLatePalette.inkDeep)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 66)
        .background(isSelected ? QuickLatePalette.primary : QuickLatePalette.surfaceSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? QuickLatePalette.primary.opacity(0.22) : QuickLatePalette.hairlineSoft, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct IconMenuLabel: View {
    let systemImage: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(QuickLatePalette.primary)
                .frame(width: 32, height: 32)
                .background(QuickLatePalette.primarySoft, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QuickLatePalette.slate)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(QuickLatePalette.inkDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(QuickLatePalette.slate)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(QuickLatePalette.surfaceSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
