import SwiftUI

struct ContentView: View {
    @Bindable var session: TranslationSessionStore

    var body: some View {
        ZStack(alignment: .top) {
            QuickLateStageBackground()

            CommandWorkspaceView(session: session)

            if let toastMessage = session.toastMessage {
                ToastMessageView(message: toastMessage)
                    .padding(.top, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.84), value: session.toastSequence)
        .animation(.easeOut(duration: 0.18), value: session.toastMessage)
    }
}

private struct ToastMessageView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(QuickLatePalette.panelRaised, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(QuickLatePalette.borderStrong)
            }
            .accessibilityAddTraits(.updatesFrequently)
    }
}
