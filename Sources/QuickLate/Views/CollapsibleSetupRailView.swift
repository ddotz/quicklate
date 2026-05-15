import QuickLateCore
import SwiftUI

struct CollapsibleSetupRailView: View {
    let state: SetupRailState
    let download: () -> Void
    let toggleExpanded: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            RailIconButton(
                systemImage: "slider.horizontal.3",
                accentColor: state.requiresAttention ? QuickLatePalette.attention : QuickLatePalette.brandCyan,
                showsAttention: state.requiresAttention,
                action: toggleExpanded
            )
            .help(AppText.setupStatus)
            .accessibilityLabel(AppText.setupStatus)

            RailIconButton(
                systemImage: "arrow.down.circle.fill",
                accentColor: QuickLatePalette.brandBlue,
                showsAttention: false,
                action: download
            )
            .help(AppText.downloadModelAssets)
            .accessibilityLabel(AppText.downloadModelAssets)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .frame(width: 58)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            QuickLatePalette.surfaceRaised,
                            QuickLatePalette.brandBlue.opacity(0.10),
                            QuickLatePalette.surfaceDeep
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(QuickLatePalette.border, lineWidth: 1)
        }
        .overlay(alignment: .trailing) {
            if state.shouldPeek {
                SetupRailPeekView(download: download)
                    .offset(x: -66)
            }
        }
        .shadow(color: QuickLatePalette.brandBlue.opacity(0.14), radius: 24, y: 12)
    }
}

private struct RailIconButton: View {
    let systemImage: String
    let accentColor: Color
    let showsAttention: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: 42, height: 38)
                .background(accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(accentColor.opacity(0.30), lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    if showsAttention {
                        Circle()
                            .fill(QuickLatePalette.attention)
                            .frame(width: 8, height: 8)
                            .shadow(color: QuickLatePalette.attention.opacity(0.65), radius: 7)
                            .offset(x: -5, y: 5)
                    }
                }
        }
        .buttonStyle(RailPressButtonStyle())
    }
}

private struct RailPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

private struct SetupRailPeekView: View {
    let download: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Circle()
                    .fill(QuickLatePalette.attention)
                    .frame(width: 8, height: 8)
                Text(AppText.languagePackNeeded)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Text(AppText.downloadModelAssets)
                .font(.caption.weight(.medium))
                .foregroundStyle(QuickLatePalette.textMuted)
            Button(AppText.downloadAndStart, action: download)
                .buttonStyle(PeekPrimaryButtonStyle())
        }
        .padding(15)
        .frame(width: 250, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [QuickLatePalette.attention.opacity(0.16), QuickLatePalette.surfaceRaised, QuickLatePalette.surfaceDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(QuickLatePalette.attention.opacity(0.34), lineWidth: 1)
        }
        .shadow(color: QuickLatePalette.attention.opacity(0.18), radius: 26, y: 14)
    }
}

private struct PeekPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                LinearGradient(
                    colors: [QuickLatePalette.brandBlue, QuickLatePalette.brandIndigo],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
