import AppKit
import SwiftUI

enum QuickLatePalette {
    static let canvas = light(0xF3F7FB)
    static let canvasTop = light(0xFAFCFF)
    static let surface = light(0xFFFFFF)
    static let surfaceSoft = light(0xEEF4FA)
    static let surfaceRaised = light(0xFFFFFF)
    static let hairline = light(0xD7E0EA)
    static let hairlineSoft = light(0xE7EEF6)

    static let inkDeep = light(0x101A2B)
    static let ink = light(0x172335)
    static let slate = light(0x5D6878)
    static let steel = light(0x8792A1)
    static let onPrimary = Color.white

    static let primary = light(0x0A63D8)
    static let primaryDeep = light(0x17253A)
    static let primarySoft = light(0xEAF3FF)
    static let oculusPurple = light(0x6D68D8)

    static let success = light(0x148A4F)
    static let attention = light(0x9A6200)
    static let warning = light(0xF5C84B)
    static let critical = light(0xC93434)

    static let originalAccent = primary
    static let translationAccent = primaryDeep

    private static func light(_ hex: UInt32) -> Color {
        Color(nsColor: nsColor(hex: hex))
    }

    private static func nsColor(hex: UInt32) -> NSColor {
        NSColor(
            calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum QuickLateMetric {
    static let radiusXL: CGFloat = 16
    static let radiusXXL: CGFloat = 24
    static let radiusXXXL: CGFloat = 32
    static let pill: CGFloat = 100
}

struct QuickLateViewDensityMetrics {
    let workspaceTitleFontSize: CGFloat
    let transcriptTitleFontSize: CGFloat
    let transcriptSubtitleFontSize: CGFloat
    let transcriptBodyFontSize: CGFloat
    let emptyStateFontSize: CGFloat
    let primaryButtonFontSize: CGFloat
    let languageChipFontSize: CGFloat
    let languageChipLineLimit: Int
    let languageChipMinimumScaleFactor: CGFloat
    let topBarControlRowSpacing: CGFloat
    let workspaceColumnSpacing: CGFloat

    static let comfortableDesktop = QuickLateViewDensityMetrics(
        workspaceTitleFontSize: 24,
        transcriptTitleFontSize: 18,
        transcriptSubtitleFontSize: 13,
        transcriptBodyFontSize: 20,
        emptyStateFontSize: 20,
        primaryButtonFontSize: 13,
        languageChipFontSize: 12,
        languageChipLineLimit: 1,
        languageChipMinimumScaleFactor: 0.82,
        topBarControlRowSpacing: 18,
        workspaceColumnSpacing: 32
    )
}

struct QuickLateStageBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [QuickLatePalette.canvasTop, QuickLatePalette.canvas],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [QuickLatePalette.primarySoft.opacity(0.82), .clear],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 620
            )
            .blendMode(.multiply)

            RadialGradient(
                colors: [Color.white.opacity(0.95), .clear],
                center: .bottomLeading,
                startRadius: 36,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct QuickLateAppIconView: View {
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let icon = Self.iconImage() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(QuickLatePalette.primary)
                    .overlay {
                        Text("Q")
                            .font(.system(size: size * 0.52, weight: .black, design: .rounded))
                            .foregroundStyle(QuickLatePalette.onPrimary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }

    private static func iconImage() -> NSImage? {
        Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            .flatMap(NSImage.init(contentsOf:))
            ?? NSImage(named: "AppIcon")
    }
}

struct QuickLateWordmarkView: View {
    var body: some View {
        HStack(spacing: 9) {
            QuickLateAppIconView(size: 30)
            Text(AppText.appName)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(QuickLatePalette.inkDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
    }
}
