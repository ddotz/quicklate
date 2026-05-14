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
