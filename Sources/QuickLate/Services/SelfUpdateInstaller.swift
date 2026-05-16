import AppKit
import Foundation
import QuickLateCore

@MainActor
struct SelfUpdateInstaller {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func stageAndLaunchInstall(packageURL: URL, latestVersion: String) throws {
        let currentAppURL = try currentAppBundleURL()
        let expectedBundleIdentifier = try bundleIdentifier(in: currentAppURL)
        try assertTargetIsWritable(currentAppURL)

        let updateRoot = packageURL.deletingLastPathComponent()
        let stagedAppURL = try stagedAppBundle(from: packageURL, in: updateRoot)
        let stagedBundleIdentifier = try bundleIdentifier(in: stagedAppURL)
        guard stagedBundleIdentifier == expectedBundleIdentifier else {
            throw SelfUpdateInstallerError.bundleIdentifierMismatch
        }
        let stagedVersion = try bundleShortVersion(in: stagedAppURL)
        guard AppReleaseVersion(stagedVersion) == AppReleaseVersion(latestVersion) else {
            throw SelfUpdateInstallerError.versionMismatch(expected: latestVersion, actual: stagedVersion)
        }

        let plan = SelfUpdateInstallPlan(
            currentProcessID: ProcessInfo.processInfo.processIdentifier,
            currentAppBundleURL: currentAppURL,
            stagedAppBundleURL: stagedAppURL,
            backupAppBundleURL: backupURL(for: currentAppURL)
        )
        let scriptURL = updateRoot.appendingPathComponent("install-quicklate-update.sh")
        try writeInstallerScript(plan.installerScript, to: scriptURL)
        try launchInstallerScript(scriptURL)
        NSApp.terminate(nil)
    }

    private func currentAppBundleURL() throws -> URL {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else {
            throw SelfUpdateInstallerError.currentBundleUnavailable
        }
        return bundleURL
    }

    private func assertTargetIsWritable(_ appURL: URL) throws {
        let parentURL = appURL.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: parentURL.path) else {
            throw SelfUpdateInstallerError.targetNotWritable(parentURL.path)
        }
    }

    private func stagedAppBundle(from packageURL: URL, in updateRoot: URL) throws -> URL {
        let extractRoot = updateRoot.appendingPathComponent("extracted", isDirectory: true)
        if fileManager.fileExists(atPath: extractRoot.path) {
            try fileManager.removeItem(at: extractRoot)
        }
        try fileManager.createDirectory(at: extractRoot, withIntermediateDirectories: true)

        switch packageURL.pathExtension.lowercased() {
        case "zip":
            try run("/usr/bin/ditto", arguments: ["-x", "-k", packageURL.path, extractRoot.path])
            return try findQuickLateApp(in: extractRoot)
        case "dmg":
            return try stageAppFromDiskImage(packageURL, updateRoot: updateRoot, extractRoot: extractRoot)
        default:
            throw SelfUpdateInstallerError.unsupportedPackage
        }
    }

    private func stageAppFromDiskImage(
        _ packageURL: URL,
        updateRoot: URL,
        extractRoot: URL
    ) throws -> URL {
        let mountPoint = updateRoot.appendingPathComponent("mount", isDirectory: true)
        try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        try run("/usr/bin/hdiutil", arguments: [
            "attach",
            "-nobrowse",
            "-readonly",
            "-mountpoint",
            mountPoint.path,
            packageURL.path
        ])
        defer {
            try? run("/usr/bin/hdiutil", arguments: ["detach", mountPoint.path, "-quiet"])
        }

        let mountedAppURL = try findQuickLateApp(in: mountPoint)
        let stagedAppURL = extractRoot.appendingPathComponent("QuickLate.app", isDirectory: true)
        try run("/usr/bin/ditto", arguments: [mountedAppURL.path, stagedAppURL.path])
        return stagedAppURL
    }

    private func findQuickLateApp(in directoryURL: URL) throws -> URL {
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw SelfUpdateInstallerError.packageDoesNotContainApp
        }

        for case let candidateURL as URL in enumerator {
            if candidateURL.lastPathComponent == "QuickLate.app" {
                return candidateURL
            }
        }

        throw SelfUpdateInstallerError.packageDoesNotContainApp
    }

    private func bundleIdentifier(in appURL: URL) throws -> String {
        let infoPlistURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        guard let bundle = Bundle(url: appURL),
              let bundleIdentifier = bundle.bundleIdentifier,
              fileManager.fileExists(atPath: infoPlistURL.path)
        else {
            throw SelfUpdateInstallerError.invalidAppBundle
        }
        return bundleIdentifier
    }

    private func bundleShortVersion(in appURL: URL) throws -> String {
        guard let bundle = Bundle(url: appURL),
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !version.isEmpty
        else {
            throw SelfUpdateInstallerError.invalidAppBundle
        }
        return version
    }

    private func backupURL(for currentAppURL: URL) -> URL {
        currentAppURL
            .deletingLastPathComponent()
            .appendingPathComponent(".QuickLate.app.backup-\(UUID().uuidString)", isDirectory: true)
    }

    private func writeInstallerScript(_ script: String, to scriptURL: URL) throws {
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    private func launchInstallerScript(_ scriptURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path]
        try process.run()
    }

    private func run(_ executablePath: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            throw SelfUpdateInstallerError.commandFailed(executablePath, output)
        }
    }
}

enum SelfUpdateInstallerError: LocalizedError {
    case currentBundleUnavailable
    case targetNotWritable(String)
    case unsupportedPackage
    case packageDoesNotContainApp
    case invalidAppBundle
    case bundleIdentifierMismatch
    case versionMismatch(expected: String, actual: String)
    case commandFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .currentBundleUnavailable:
            AppText.selfUpdateCurrentBundleUnavailable
        case let .targetNotWritable(path):
            AppText.selfUpdateTargetNotWritable(path)
        case .unsupportedPackage:
            AppText.selfUpdateUnsupportedPackage
        case .packageDoesNotContainApp:
            AppText.selfUpdatePackageDoesNotContainApp
        case .invalidAppBundle:
            AppText.selfUpdateInvalidAppBundle
        case .bundleIdentifierMismatch:
            AppText.selfUpdateBundleIdentifierMismatch
        case let .versionMismatch(expected, actual):
            AppText.selfUpdateVersionMismatch(expected: expected, actual: actual)
        case let .commandFailed(_, output):
            AppText.selfUpdateCommandFailed(output)
        }
    }
}
