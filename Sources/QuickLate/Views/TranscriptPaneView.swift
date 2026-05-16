import AppKit
import SwiftUI

private let transcriptDensity = QuickLateViewDensityMetrics.comfortableDesktop

struct TranscriptPaneView: View {
    let title: String
    let subtitle: String
    let text: String
    let isTranslation: Bool
    let accentColor: Color

    private var transcriptBodyFont: Font {
        let size = text.isEmpty ? transcriptDensity.emptyStateFontSize : transcriptDensity.transcriptBodyFontSize
        return .system(
            size: size,
            weight: isTranslation ? .semibold : .medium,
            design: .rounded
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 8, height: 8)
                        Text(title)
                            .font(.system(size: transcriptDensity.transcriptTitleFontSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(QuickLatePalette.inkDeep)
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)
                    }
                    Text(subtitle)
                        .font(.system(size: transcriptDensity.transcriptSubtitleFontSize, weight: .regular))
                        .foregroundStyle(QuickLatePalette.slate)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                Spacer(minLength: 0)
                Button {
                    copyText()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 36, height: 36)
                        .background(QuickLatePalette.primarySoft, in: Circle())
                }
                .buttonStyle(TranscriptPaneIconButtonStyle())
                .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
                .help(AppText.copy)
                .accessibilityLabel(AppText.copy)
            }

            ScrollView {
                Text(text.isEmpty ? AppText.noCaptionsYet : text)
                    .font(transcriptBodyFont)
                    .foregroundStyle(text.isEmpty ? QuickLatePalette.steel : QuickLatePalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .lineSpacing(6)
                    .padding(.top, 10)
            }

        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(QuickLatePalette.surfaceRaised, in: RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXXL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXXL, style: .continuous)
                .strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
        }
        .shadow(color: QuickLatePalette.primaryDeep.opacity(0.06), radius: 28, x: 0, y: 18)
    }

    private func copyText() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trimmedText, forType: .string)
    }
}

private struct TranscriptPaneIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}
