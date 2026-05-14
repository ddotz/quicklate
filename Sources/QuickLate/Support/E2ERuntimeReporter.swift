import Foundation
import QuickLateCore

enum E2ERuntimeReporter {
    private static let readyFileEnvironmentKey = "QUICKLATE_E2E_READY_FILE"

    static func report(_ name: String, fields: [String: String] = [:]) {
        guard let path = ProcessInfo.processInfo.environment[readyFileEnvironmentKey], !path.isEmpty else {
            return
        }

        var eventFields = fields
        eventFields["pid"] = String(ProcessInfo.processInfo.processIdentifier)
        let event = E2EReadinessEvent(name: name, fields: eventFields)

        do {
            let line = try E2EReadinessLog.encodeLine(event) + "\n"
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                if let data = line.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
                try handle.close()
            } else {
                try line.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            NSLog("QuickLate E2E readiness report failed: %@", error.localizedDescription)
        }
    }
}
