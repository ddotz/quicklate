import AppKit
import SwiftUI

enum QuickLatePalette {
    static let canvas = adaptive(light: 0xFFFFFF, dark: 0x0A0F14)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x121A23)
    static let surfaceSoft = adaptive(light: 0xF5F6F8, dark: 0x17212B)
    static let surfaceRaised = adaptive(light: 0xFFFFFF, dark: 0x182330)
    static let hairline = adaptive(light: 0xD9DEE7, dark: 0x334051)
    static let hairlineSoft = adaptive(light: 0xE8ECF2, dark: 0x263241)

    static let inkDeep = adaptive(light: 0x0A1317, dark: 0xF6F8FB)
    static let ink = adaptive(light: 0x1C2A33, dark: 0xE4EAF2)
    static let slate = adaptive(light: 0x53616D, dark: 0xB8C2CE)
    static let steel = adaptive(light: 0x74808A, dark: 0x8F9BA8)
    static let onPrimary = Color.white

    static let primary = adaptive(light: 0x0143B5, dark: 0x5B7CFF)
    static let primaryDeep = adaptive(light: 0x002A73, dark: 0x9AAEFF)
    static let primarySoft = adaptive(light: 0xE8F0FF, dark: 0x172B5F)
    static let oculusPurple = adaptive(light: 0x6155D9, dark: 0xA59CFF)

    static let success = adaptive(light: 0x148A4F, dark: 0x4BD082)
    static let attention = adaptive(light: 0xC76B10, dark: 0xFFB15C)
    static let warning = adaptive(light: 0xFFD747, dark: 0xFFD747)
    static let critical = adaptive(light: 0xC93434, dark: 0xFF6B6B)

    static let originalAccent = primary
    static let translationAccent = primaryDeep

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? nsColor(hex: dark)
                : nsColor(hex: light)
        })
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

struct QuickLateStageBackground: View {
    var body: some View {
        QuickLatePalette.canvas
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
        HStack(spacing: 10) {
            QuickLateAppIconView(size: 34)
            Text(AppText.appName)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(QuickLatePalette.inkDeep)
        }
    }
}
