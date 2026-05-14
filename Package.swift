// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "QuickLate",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "QuickLate", targets: ["QuickLate"])
    ],
    targets: [
        .target(name: "QuickLateCore"),
        .executableTarget(
            name: "QuickLateE2E",
            dependencies: ["QuickLateCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .executableTarget(
            name: "QuickLate",
            dependencies: ["QuickLateCore"],
            linkerSettings: [
                .linkedFramework("AVFAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Security"),
                .linkedFramework("Speech"),
                .linkedFramework("Translation")
            ]
        ),
        .testTarget(
            name: "QuickLateCoreTests",
            dependencies: ["QuickLateCore"]
        )
    ]
)
