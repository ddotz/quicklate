import AppKit
import CoreGraphics
import Foundation
import QuickLateCore

private enum ExpectedActivationPolicy: String {
    case accessory
    case regular
}

private enum ExpectedMainWindow: String {
    case absent
    case present
}

private struct ProbeOptions {
    var appName = "QuickLate"
    var bundleID = "dev.appcaster.QuickLate"
    var expectedPolicy: ExpectedActivationPolicy?
    var expectedMainWindow: ExpectedMainWindow?
    var readyFile: String?
    var expectedEvent: String?
    var timeout: TimeInterval = 10
    var minWindowWidth: Double = 800
    var minWindowHeight: Double = 500
    var reportPath: String?
}

private struct WindowSnapshot: Codable {
    let id: UInt32
    let owner: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

private struct ProbeSnapshot: Codable {
    let passed: Bool
    let appName: String
    let bundleID: String
    let pid: Int32?
    let activationPolicy: String?
    let expectedActivationPolicy: String?
    let mainWindowCount: Int
    let expectedMainWindow: String?
    let readyEvents: [String]
    let expectedReadyEvent: String?
    let windows: [WindowSnapshot]
    let diagnostics: [String]
}

private enum ProbeError: Error, CustomStringConvertible {
    case usage(String)

    var description: String {
        switch self {
        case let .usage(message):
            message
        }
    }
}

private func parseOptions(_ args: [String]) throws -> ProbeOptions {
    guard args.first == "probe" else {
        throw ProbeError.usage("usage: QuickLateE2E probe [--expect-policy accessory|regular] [--expect-main-window absent|present]")
    }

    var options = ProbeOptions()
    var index = 1
    while index < args.count {
        let key = args[index]
        func value() throws -> String {
            guard index + 1 < args.count else {
                throw ProbeError.usage("missing value for \(key)")
            }
            index += 1
            return args[index]
        }

        switch key {
        case "--app-name":
            options.appName = try value()
        case "--bundle-id":
            options.bundleID = try value()
        case "--expect-policy":
            let raw = try value()
            guard let policy = ExpectedActivationPolicy(rawValue: raw) else {
                throw ProbeError.usage("invalid policy: \(raw)")
            }
            options.expectedPolicy = policy
        case "--expect-main-window":
            let raw = try value()
            guard let expectation = ExpectedMainWindow(rawValue: raw) else {
                throw ProbeError.usage("invalid main-window expectation: \(raw)")
            }
            options.expectedMainWindow = expectation
        case "--ready-file":
            options.readyFile = try value()
        case "--expect-event":
            options.expectedEvent = try value()
        case "--timeout":
            guard let seconds = TimeInterval(try value()) else {
                throw ProbeError.usage("invalid timeout")
            }
            options.timeout = seconds
        case "--min-window-width":
            guard let width = Double(try value()) else {
                throw ProbeError.usage("invalid min window width")
            }
            options.minWindowWidth = width
        case "--min-window-height":
            guard let height = Double(try value()) else {
                throw ProbeError.usage("invalid min window height")
            }
            options.minWindowHeight = height
        case "--report":
            options.reportPath = try value()
        default:
            throw ProbeError.usage("unknown option: \(key)")
        }
        index += 1
    }

    return options
}

private func runningApplication(bundleID: String, appName: String) -> NSRunningApplication? {
    let bundleMatches = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    if let app = bundleMatches.first(where: { !$0.isTerminated }) {
        return app
    }

    return NSWorkspace.shared.runningApplications.first {
        !$0.isTerminated && ($0.localizedName == appName || $0.bundleIdentifier == bundleID)
    }
}

private func activationPolicyName(_ policy: NSApplication.ActivationPolicy) -> String {
    switch policy {
    case .regular:
        "regular"
    case .accessory:
        "accessory"
    case .prohibited:
        "prohibited"
    @unknown default:
        "unknown"
    }
}

private func mainWindows(appName: String, minWidth: Double, minHeight: Double) -> [WindowSnapshot] {
    let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
    return windows.compactMap { window in
        guard let owner = window[kCGWindowOwnerName as String] as? String,
              owner == appName,
              let id = window[kCGWindowNumber as String] as? UInt32,
              let layer = window[kCGWindowLayer as String] as? Int,
              layer == 0,
              let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
              bounds.width >= minWidth,
              bounds.height >= minHeight else {
            return nil
        }
        return WindowSnapshot(
            id: id,
            owner: owner,
            x: bounds.origin.x,
            y: bounds.origin.y,
            width: bounds.width,
            height: bounds.height
        )
    }
}

private func readyEvents(at path: String?) -> [String] {
    guard let path,
          let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        return []
    }
    return E2EReadinessLog.decodeLines(text).map(\.name)
}

private func snapshot(options: ProbeOptions) -> ProbeSnapshot {
    let app = runningApplication(bundleID: options.bundleID, appName: options.appName)
    let policy = app.map { activationPolicyName($0.activationPolicy) }
    let windows = mainWindows(
        appName: options.appName,
        minWidth: options.minWindowWidth,
        minHeight: options.minWindowHeight
    )
    let events = readyEvents(at: options.readyFile)
    var diagnostics: [String] = []

    if app == nil {
        diagnostics.append("QuickLate process was not found")
    }
    if let expected = options.expectedPolicy, policy != expected.rawValue {
        diagnostics.append("activation policy was \(policy ?? "missing"), expected \(expected.rawValue)")
    }
    if let expected = options.expectedMainWindow {
        switch expected {
        case .absent where !windows.isEmpty:
            diagnostics.append("expected no main workspace window, found \(windows.count)")
        case .present where windows.isEmpty:
            diagnostics.append("expected a visible main workspace window, found none")
        default:
            break
        }
    }
    if let expectedEvent = options.expectedEvent, !events.contains(expectedEvent) {
        diagnostics.append("ready event \(expectedEvent) was not observed")
    }

    return ProbeSnapshot(
        passed: app != nil && diagnostics.isEmpty,
        appName: options.appName,
        bundleID: options.bundleID,
        pid: app?.processIdentifier,
        activationPolicy: policy,
        expectedActivationPolicy: options.expectedPolicy?.rawValue,
        mainWindowCount: windows.count,
        expectedMainWindow: options.expectedMainWindow?.rawValue,
        readyEvents: events,
        expectedReadyEvent: options.expectedEvent,
        windows: windows,
        diagnostics: diagnostics
    )
}

private func writeReport(_ snapshot: ProbeSnapshot, path: String?) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(snapshot)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))

    guard let path else { return }
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
}

private func run() throws -> Int32 {
    let options = try parseOptions(Array(CommandLine.arguments.dropFirst()))
    let deadline = Date().addingTimeInterval(options.timeout)
    var lastSnapshot = snapshot(options: options)

    while Date() < deadline {
        lastSnapshot = snapshot(options: options)
        if lastSnapshot.passed {
            try writeReport(lastSnapshot, path: options.reportPath)
            return 0
        }
        Thread.sleep(forTimeInterval: 0.2)
    }

    try writeReport(lastSnapshot, path: options.reportPath)
    return 1
}

do {
    exit(try run())
} catch {
    fputs("QuickLateE2E error: \(error)\n", stderr)
    exit(2)
}
