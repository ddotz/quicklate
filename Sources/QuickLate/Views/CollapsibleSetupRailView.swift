import QuickLateCore
import SwiftUI

struct CollapsibleSetupRailView: View {
    let state: SetupRailState
    let download: () -> Void
    let toggleExpanded: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: toggleExpanded) {
                Image(systemName: "slider.horizontal.3")
                    .font(.callout.weight(.semibold))
                    .frame(width: 40, height: 38)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if state.requiresAttention {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 7, height: 7)
                                .offset(x: -5, y: 5)
                        }
                    }
            }
            .buttonStyle(.plain)
            .help(AppText.setupStatus)
            .accessibilityLabel(AppText.setupStatus)

            Button(action: download) {
                Image(systemName: "arrow.down.circle")
                    .frame(width: 40, height: 34)
            }
            .buttonStyle(.plain)
            .help(AppText.downloadModelAssets)
            .accessibilityLabel(AppText.downloadModelAssets)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .frame(width: 56)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .trailing) {
            if state.shouldPeek {
                SetupRailPeekView(download: download)
                    .offset(x: -64)
            }
        }
    }
}

private struct SetupRailPeekView: View {
    let download: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppText.languagePackNeeded)
                .font(.headline)
            Text(AppText.downloadModelAssets)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(AppText.downloadAndStart, action: download)
        }
        .padding(14)
        .frame(width: 244, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 24, y: 12)
    }
}
