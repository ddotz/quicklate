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
                accentColor: state.requiresAttention ? QuickLatePalette.attention : QuickLatePalette.primary,
                showsAttention: state.requiresAttention,
                action: toggleExpanded
            )
            .help(AppText.setupStatus)
            .accessibilityLabel(AppText.setupStatus)

            RailIconButton(
                systemImage: "arrow.down.circle.fill",
                accentColor: QuickLatePalette.primary,
                showsAttention: false,
                action: download
            )
            .help(AppText.downloadModelAssets)
            .accessibilityLabel(AppText.downloadModelAssets)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
        .frame(width: 64)
        .background(QuickLatePalette.surface, in: RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXL, style: .continuous)
                .strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
        }
        .overlay(alignment: .trailing) {
            if state.shouldPeek {
                SetupRailPeekView(download: download)
                    .offset(x: -72)
            }
        }
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
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accentColor)
                .frame(width: 44, height: 44)
                .background(QuickLatePalette.primarySoft, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(accentColor.opacity(0.22), lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    if showsAttention {
                        Circle()
                            .fill(QuickLatePalette.attention)
                            .frame(width: 8, height: 8)
                            .offset(x: -4, y: 4)
                    }
                }
        }
        .buttonStyle(RailPressButtonStyle())
    }
}

private struct RailPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SetupRailPeekView: View {
    let download: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(QuickLatePalette.attention)
                    .frame(width: 8, height: 8)
                Text(AppText.languagePackNeeded)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(QuickLatePalette.inkDeep)
            }
            Text(AppText.downloadModelAssets)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(QuickLatePalette.slate)
            Button(AppText.downloadAndStart, action: download)
                .buttonStyle(PeekPrimaryButtonStyle())
        }
        .padding(24)
        .frame(width: 260, alignment: .leading)
        .background(QuickLatePalette.surface, in: RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXL, style: .continuous)
                .strokeBorder(QuickLatePalette.hairline, lineWidth: 1)
        }
    }
}

private struct PeekPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(QuickLatePalette.onPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(QuickLatePalette.primary, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
