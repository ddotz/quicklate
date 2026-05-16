import Foundation
import Testing
@testable import QuickLateCore

@Suite
struct SelfUpdateInstallPlanTests {
    @Test
    func installScriptWaitsForCurrentProcessReplacesAppAndRelaunches() throws {
        let plan = SelfUpdateInstallPlan(
            currentProcessID: 4242,
            currentAppBundleURL: URL(fileURLWithPath: "/Applications/QuickLate.app"),
            stagedAppBundleURL: URL(fileURLWithPath: "/tmp/QuickLate Self Update/Staged/QuickLate.app"),
            backupAppBundleURL: URL(fileURLWithPath: "/Applications/.QuickLate.app.backup")
        )

        let script = plan.installerScript

        #expect(script.contains("APP_PID=4242"))
        #expect(script.contains("while /bin/kill -0 \"$APP_PID\""))
        #expect(script.contains("/bin/mv \"$CURRENT_APP\" \"$BACKUP_APP\""))
        #expect(script.contains("/usr/bin/ditto \"$STAGED_APP\" \"$CURRENT_APP\""))
        #expect(script.contains("/usr/bin/open \"$CURRENT_APP\""))
    }

    @Test
    func installScriptSingleQuotesPathsSafely() throws {
        let plan = SelfUpdateInstallPlan(
            currentProcessID: 7,
            currentAppBundleURL: URL(fileURLWithPath: "/Applications/QuickLate Bob's.app"),
            stagedAppBundleURL: URL(fileURLWithPath: "/tmp/staged/QuickLate Bob's.app"),
            backupAppBundleURL: URL(fileURLWithPath: "/Applications/.QuickLate Bob's.backup")
        )

        let script = plan.installerScript

        #expect(script.contains("CURRENT_APP='/Applications/QuickLate Bob'\\''s.app'"))
        #expect(script.contains("STAGED_APP='/tmp/staged/QuickLate Bob'\\''s.app'"))
        #expect(script.contains("BACKUP_APP='/Applications/.QuickLate Bob'\\''s.backup'"))
    }

    @Test
    func installScriptReplacesCurrentBundleWhenRelaunchIsSkipped() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("QuickLateSelfUpdateScript-\(UUID().uuidString)", isDirectory: true)
        let currentParentURL = rootURL.appendingPathComponent("current", isDirectory: true)
        let currentAppURL = currentParentURL.appendingPathComponent("QuickLate.app", isDirectory: true)
        let updateRootURL = rootURL.appendingPathComponent("update", isDirectory: true)
        let stagedAppURL = updateRootURL
            .appendingPathComponent("extracted", isDirectory: true)
            .appendingPathComponent("QuickLate.app", isDirectory: true)
        let backupAppURL = currentParentURL.appendingPathComponent(".QuickLate.app.backup", isDirectory: true)
        let scriptURL = rootURL.appendingPathComponent("install.sh")
        defer { try? fileManager.removeItem(at: rootURL) }

        try fileManager.createDirectory(
            at: currentAppURL.appendingPathComponent("Contents", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: stagedAppURL.appendingPathComponent("Contents", isDirectory: true),
            withIntermediateDirectories: true
        )
        try "old".write(
            to: currentAppURL.appendingPathComponent("Contents/marker.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "new".write(
            to: stagedAppURL.appendingPathComponent("Contents/marker.txt"),
            atomically: true,
            encoding: .utf8
        )

        let plan = SelfUpdateInstallPlan(
            currentProcessID: 999_999,
            currentAppBundleURL: currentAppURL,
            stagedAppBundleURL: stagedAppURL,
            backupAppBundleURL: backupAppURL
        )
        try plan.installerScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path]
        process.environment = [
            "QUICKLATE_SELF_UPDATE_SKIP_RELAUNCH": "1",
            "TMPDIR": rootURL.path + "/"
        ]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            Issue.record("installer script failed: \(output)")
        }

        let marker = try String(
            contentsOf: currentAppURL.appendingPathComponent("Contents/marker.txt"),
            encoding: .utf8
        )
        #expect(process.terminationStatus == 0)
        #expect(marker == "new")
        #expect(!fileManager.fileExists(atPath: backupAppURL.path))
        #expect(!fileManager.fileExists(atPath: updateRootURL.path))
    }
}
