import Foundation

public struct SelfUpdateInstallPlan: Equatable, Sendable {
    public let currentProcessID: Int32
    public let currentAppBundleURL: URL
    public let stagedAppBundleURL: URL
    public let backupAppBundleURL: URL

    public init(
        currentProcessID: Int32,
        currentAppBundleURL: URL,
        stagedAppBundleURL: URL,
        backupAppBundleURL: URL
    ) {
        self.currentProcessID = currentProcessID
        self.currentAppBundleURL = currentAppBundleURL
        self.stagedAppBundleURL = stagedAppBundleURL
        self.backupAppBundleURL = backupAppBundleURL
    }

    public var installerScript: String {
        let currentApp = ShellEscaper.singleQuoted(currentAppBundleURL.path)
        let stagedApp = ShellEscaper.singleQuoted(stagedAppBundleURL.path)
        let backupApp = ShellEscaper.singleQuoted(backupAppBundleURL.path)

        return """
        #!/bin/zsh
        set -euo pipefail

        APP_PID=\(currentProcessID)
        CURRENT_APP=\(currentApp)
        STAGED_APP=\(stagedApp)
        BACKUP_APP=\(backupApp)
        LOG_FILE="${TMPDIR:-/tmp}/quicklate-self-update.log"

        exec >>"$LOG_FILE" 2>&1

        restore_backup() {
          if [[ ! -e "$CURRENT_APP" && -e "$BACKUP_APP" ]]; then
            /bin/mv "$BACKUP_APP" "$CURRENT_APP"
          fi
        }
        trap restore_backup ERR

        while /bin/kill -0 "$APP_PID" 2>/dev/null; do
          /bin/sleep 0.2
        done

        /bin/rm -rf "$BACKUP_APP"
        if [[ -e "$CURRENT_APP" ]]; then
          /bin/mv "$CURRENT_APP" "$BACKUP_APP"
        fi

        /usr/bin/ditto "$STAGED_APP" "$CURRENT_APP"
        /usr/bin/xattr -dr com.apple.quarantine "$CURRENT_APP" 2>/dev/null || true
        if [[ "${QUICKLATE_SELF_UPDATE_SKIP_RELAUNCH:-0}" != "1" ]]; then
          /usr/bin/open "$CURRENT_APP"
        fi
        /bin/rm -rf "$BACKUP_APP"
        /bin/rm -rf "$(/usr/bin/dirname "$(/usr/bin/dirname "$STAGED_APP")")"
        /bin/rm -f "$0"
        """
    }
}

private enum ShellEscaper {
    static func singleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
