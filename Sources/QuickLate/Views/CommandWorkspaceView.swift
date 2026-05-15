import SwiftUI

struct CommandWorkspaceView: View {
    @State private var viewModel: WorkspaceViewModel
    @State private var isFloatingCaptionVisible = FloatingCaptionWindowController.isOpen

    init(session: TranslationSessionStore) {
        _viewModel = State(initialValue: WorkspaceViewModel(session: session))
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 18) {
                topBar
                HStack(spacing: 18) {
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
        .padding(22)
        .onAppear(perform: syncFloatingCaptionVisibility)
        .onReceive(NotificationCenter.default.publisher(for: FloatingCaptionWindowController.visibilityDidChangeNotification)) { _ in
            syncFloatingCaptionVisibility()
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            QuickLateAppIconView(size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppText.liveTranslationWorkspace)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(viewModel.session.languageSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(QuickLatePalette.textMuted)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(action: showFloatingCaptions) {
                    TopBarSecondaryActionLabel(
                        title: AppText.floatingCaptions,
                        systemImage: isFloatingCaptionVisible ? "captions.bubble.fill" : "captions.bubble",
                        accentColor: isFloatingCaptionVisible ? QuickLatePalette.success : QuickLatePalette.brandCyan
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
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            QuickLatePalette.brandBlue.opacity(0.20),
                            QuickLatePalette.surfaceRaised,
                            QuickLatePalette.brandViolet.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            QuickLatePalette.brandCyan.opacity(0.46),
                            QuickLatePalette.borderStrong,
                            QuickLatePalette.brandViolet.opacity(0.32)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )
        }
        .shadow(color: QuickLatePalette.brandBlue.opacity(0.18), radius: 28, y: 16)
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
            QuickLatePalette.brandBlue
        case .wait:
            QuickLatePalette.attention
        case .start:
            viewModel.session.isRunning ? .red : QuickLatePalette.brandBlue
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
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.34), lineWidth: 1)
            }
    }
}

private struct TopBarPrimaryActionLabel: View {
    let title: String
    let systemImage: String
    let accentColor: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accentColor, QuickLatePalette.brandIndigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.26), lineWidth: 1)
            }
            .shadow(color: accentColor.opacity(0.32), radius: 18, y: 8)
    }
}

private struct TopBarPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? 0.04 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
