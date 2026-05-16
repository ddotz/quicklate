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

            if state.preflight.showsDownloadProgress {
                ProgressView()
                    .progressViewStyle(.linear)
                    .controlSize(.small)
                    .tint(QuickLatePalette.primary)
                    .frame(width: 42)
                    .accessibilityLabel(AppText.languagePackDownloadInProgress)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
        .frame(width: 58)
        .background(QuickLatePalette.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXL, style: .continuous)
                .strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
        }
        .shadow(color: QuickLatePalette.primaryDeep.opacity(0.08), radius: 24, x: 0, y: 14)
        .overlay(alignment: .trailing) {
            if state.preflight.showsDownloadProgress {
                SetupRailProgressPeekView()
                    .offset(x: -12, y: 6)
            } else if state.shouldPeek {
                SetupRailPeekView(download: download)
                    .offset(x: -12, y: 6)
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
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(accentColor)
                .frame(width: 42, height: 42)
                .background(QuickLatePalette.primarySoft, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.92), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(QuickLatePalette.attention)
                    .frame(width: 8, height: 8)
                Text(AppText.languagePackNeeded)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(QuickLatePalette.inkDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            Text(AppText.downloadModelAssets)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(QuickLatePalette.slate)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
            Button(AppText.downloadAndStart, action: download)
                .buttonStyle(PeekPrimaryButtonStyle())
        }
        .padding(18)
        .frame(width: 224, alignment: .leading)
        .background(QuickLatePalette.surface, in: RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXL, style: .continuous)
                .strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
        }
        .shadow(color: QuickLatePalette.primaryDeep.opacity(0.12), radius: 24, x: 0, y: 16)
    }
}

private struct SetupRailProgressPeekView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(AppText.languagePackDownloadInProgress)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(QuickLatePalette.inkDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            ProgressView()
                .progressViewStyle(.linear)
                .controlSize(.small)
                .tint(QuickLatePalette.primary)
        }
        .padding(18)
        .frame(width: 224, alignment: .leading)
        .background(QuickLatePalette.surface, in: RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: QuickLateMetric.radiusXXL, style: .continuous)
                .strokeBorder(QuickLatePalette.hairlineSoft, lineWidth: 1)
        }
        .shadow(color: QuickLatePalette.primaryDeep.opacity(0.12), radius: 24, x: 0, y: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppText.languagePackDownloadInProgress)
    }
}

private struct PeekPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(QuickLatePalette.onPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(QuickLatePalette.primary, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
