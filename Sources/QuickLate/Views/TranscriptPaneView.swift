import AppKit
import SwiftUI

struct TranscriptPaneView: View {
    let title: String
    let subtitle: String
    let text: String
    let isTranslation: Bool
    let accentColor: Color
    let showFloatingCaptions: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 8, height: 8)
                        Text(title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(QuickLatePalette.textMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Button {
                    copyText()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 32, height: 32)
                        .background(accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(accentColor.opacity(0.28), lineWidth: 1)
                        }
                }
                .buttonStyle(TranscriptPaneIconButtonStyle())
                .help(AppText.copy)
                .accessibilityLabel(AppText.copy)
            }

            ScrollView {
                Text(text.isEmpty ? AppText.noCaptionsYet : text)
                    .font(isTranslation ? .title3.weight(.semibold) : .title3.weight(.medium))
                    .foregroundStyle(text.isEmpty ? QuickLatePalette.textMuted : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .lineSpacing(3)
                    .padding(.top, 6)
            }

            HStack(spacing: 10) {
                Button(AppText.copy, action: copyText)
                    .buttonStyle(TranscriptPaneTextButtonStyle(accentColor: accentColor, isPrimary: false))
                Button(AppText.floatingCaptions, action: showFloatingCaptions)
                    .buttonStyle(TranscriptPaneTextButtonStyle(accentColor: accentColor, isPrimary: true))
            }
            .controlSize(.small)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(QuickLatePalette.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(accentColor.opacity(isTranslation ? 0.28 : 0.22), lineWidth: 1)
        }
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
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.74 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct TranscriptPaneTextButtonStyle: ButtonStyle {
    let accentColor: Color
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(isPrimary ? .white : accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isPrimary ? accentColor.opacity(0.28) : Color.white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isPrimary ? accentColor.opacity(0.40) : Color.white.opacity(0.12), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
