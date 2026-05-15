import AppKit
import SwiftUI

enum QuickLatePalette {
    static let ink = Color(red: 0.055, green: 0.065, blue: 0.105)
    static let midnight = Color(red: 0.045, green: 0.095, blue: 0.185)
    static let blueBlack = Color(red: 0.035, green: 0.055, blue: 0.105)
    static let surface = Color.white.opacity(0.075)
    static let surfaceRaised = Color.white.opacity(0.115)
    static let surfaceDeep = Color.black.opacity(0.22)
    static let border = Color.white.opacity(0.145)
    static let borderStrong = Color.white.opacity(0.24)
    static let textMuted = Color.white.opacity(0.68)

    static let brandBlue = Color(red: 0.26, green: 0.48, blue: 1.0)
    static let brandCyan = Color(red: 0.20, green: 0.76, blue: 0.98)
    static let brandViolet = Color(red: 0.56, green: 0.38, blue: 1.0)
    static let brandIndigo = Color(red: 0.30, green: 0.32, blue: 0.95)
    static let success = Color(red: 0.22, green: 0.78, blue: 0.53)
    static let attention = Color(red: 1.0, green: 0.62, blue: 0.20)

    static let originalAccent = brandCyan
    static let translationAccent = brandViolet
}

struct QuickLateStageBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    QuickLatePalette.ink,
                    QuickLatePalette.midnight,
                    QuickLatePalette.blueBlack
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [QuickLatePalette.brandBlue.opacity(0.34), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 560
            )
            .offset(x: -160, y: -140)

            RadialGradient(
                colors: [QuickLatePalette.brandViolet.opacity(0.24), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 620
            )
            .offset(x: 180, y: 170)

            RadialGradient(
                colors: [QuickLatePalette.brandCyan.opacity(0.13), .clear],
                center: .center,
                startRadius: 80,
                endRadius: 640
            )
            .offset(x: -20, y: 60)
        }
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
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [QuickLatePalette.brandCyan, QuickLatePalette.brandBlue, QuickLatePalette.brandViolet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Text("Q")
                            .font(.system(size: size * 0.52, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .shadow(color: QuickLatePalette.brandBlue.opacity(0.30), radius: 12, y: 6)
    }

    private static func iconImage() -> NSImage? {
        Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            .flatMap(NSImage.init(contentsOf:))
            ?? NSImage(named: "AppIcon")
    }
}
