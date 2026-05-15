import SwiftUI

struct CommandWorkspaceView: View {
    @State private var viewModel: WorkspaceViewModel
    @State private var isFloatingCaptionVisible = FloatingCaptionWindowController.isOpen

    init(session: TranslationSessionStore) {
        _viewModel = State(initialValue: WorkspaceViewModel(session: session))
    }

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 24) {
                topBar
                HStack(spacing: 24) {
                    TranscriptPaneView(
                        title: AppText.original,
                        subtitle: AppText.originalDescription,
                        text: viewModel.session.visibleTranscript(),
                        isTranslation: false,
                        accentColor: QuickLatePalette.originalAccent,
                        showFloatingCaptions: showFloatingCaptions
                    )
                    TranscriptPaneView(
                        title: AppText.translation,
                        subtitle: AppText.translationDescription,
                        text: viewModel.session.visibleTranslatedText(),
                        isTranslation: true,
                        accentColor: QuickLatePalette.translationAccent,
                        showFloatingCaptions: showFloatingCaptions
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
        .padding(32)
        .onAppear(perform: syncFloatingCaptionVisibility)
        .onReceive(NotificationCenter.default.publisher(for: FloatingCaptionWindowController.visibilityDidChangeNotification)) { _ in
            syncFloatingCaptionVisibility()
        }
    }

    private var topBar: some View {
        HStack(spacing: 20) {
            QuickLateWordmarkView()

            VStack(alignment: .leading, spacing: 4) {
                Text(AppText.liveTranslationWorkspace)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(QuickLatePalette.inkDeep)
                Text(viewModel.session.languageSummary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(QuickLatePalette.slate)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
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
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(QuickLatePalette.surface, in: RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXXL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXXL, style: .continuous)
                .strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
        }
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
        case .downloadAndStart, .retryDownload, .changeLanguagePair, .openSystemSettings:
            QuickLatePalette.primary
        case .wait:
            QuickLatePalette.attention
        case .start:
            viewModel.session.isRunning ? QuickLatePalette.critical : QuickLatePalette.primary
        }
    }

    private func showFloatingCaptions() {
        FloatingCaptionWindowController.toggle(session: viewModel.session)
        syncFloatingCaptionVisibility()
    }

    private func syncFloatingCaptionVisibility() {
        isFloatingCaptionVisible = FloatingCaptionWindowController.isOpen
    }
}

private struct TopBarSecondaryActionLabel: View {
    let title: String
    let systemImage: String
    let accentColor: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(QuickLatePalette.inkDeep)
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(.clear, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(QuickLatePalette.inkDeep, lineWidth: 2)
            }
    }
}

private struct TopBarPrimaryActionLabel: View {
    let title: String
    let systemImage: String
    let accentColor: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(QuickLatePalette.onPrimary)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(accentColor, in: Capsule())
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
