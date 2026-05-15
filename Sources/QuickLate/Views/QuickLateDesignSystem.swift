import AppKit
import SwiftUI

enum QuickLatePalette {
    static let canvas = Color(red: 0.055, green: 0.075, blue: 0.105)
    static let panel = Color(red: 0.075, green: 0.100, blue: 0.135)
    static let panelRaised = Color(red: 0.095, green: 0.125, blue: 0.165)
    static let border = Color.white.opacity(0.12)
    static let borderStrong = Color.white.opacity(0.20)
    static let textMuted = Color.white.opacity(0.68)

    static let brandBlue = Color(red: 0.24, green: 0.43, blue: 0.92)
    static let brandBlueMuted = Color(red: 0.18, green: 0.32, blue: 0.68)
    static let success = Color(red: 0.24, green: 0.68, blue: 0.45)
    static let attention = Color(red: 0.92, green: 0.54, blue: 0.20)

    static let originalAccent = brandBlue
    static let translationAccent = brandBlueMuted
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
                    .fill(QuickLatePalette.brandBlue)
                    .overlay {
                        Text("Q")
                            .font(.system(size: size * 0.52, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }

    private static func iconImage() -> NSImage? {
        Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            .flatMap(NSImage.init(contentsOf:))
            ?? NSImage(named: "AppIcon")
    }
}
