import Testing
@testable import QuickLateCore

@Suite
struct WorkspaceStartActionPolicyTests {
    @Test
    func installedAssetsStartCapture() {
        #expect(WorkspaceStartActionPolicy.route(for: .start) == .startCapture)
    }

    @Test
    func missingOrFailedAssetsDownloadAndStart() {
        #expect(WorkspaceStartActionPolicy.route(for: .downloadAndStart) == .downloadAssetsAndStart)
        #expect(WorkspaceStartActionPolicy.route(for: .retryDownload) == .downloadAssetsAndStart)
    }

    @Test
    func unavailableAssetsOpenSystemSettings() {
        #expect(WorkspaceStartActionPolicy.route(for: .openSystemSettings) == .openSystemSettings)
    }

    @Test
    func permissionFailureRequestsPermissionAgain() {
        #expect(WorkspaceStartActionPolicy.recoveryRoute(for: .permissionRequired) == .requestPermissionsAgain)
    }

    @Test
    func otherStartFailureShowsErrorOnly() {
        #expect(WorkspaceStartActionPolicy.recoveryRoute(for: .other) == .showError)
    }

    @Test
    func waitingAndUnsupportedStatesDoNotStartCapture() {
        #expect(WorkspaceStartActionPolicy.route(for: .wait) == .wait)
        #expect(WorkspaceStartActionPolicy.route(for: .changeLanguagePair) == .changeLanguagePair)
    }

    @Test
    func pendingStartContinuesToDownloadWhenRefreshFindsMissingAssets() {
        let state = AssetPreflightState(
            speech: .installed,
            translation: .downloadRequired,
            startIntent: .startAfterDownload
        )

        #expect(WorkspaceStartActionPolicy.continuationRouteAfterAvailabilityRefresh(for: state) == .downloadAssetsAndStart)
    }

    @Test
    func pendingStartContinuesToStartWhenRefreshFindsInstalledAssets() {
        let state = AssetPreflightState(
            speech: .installed,
            translation: .installed,
            startIntent: .startAfterDownload
        )

        #expect(WorkspaceStartActionPolicy.continuationRouteAfterAvailabilityRefresh(for: state) == .startCapture)
    }

    @Test
    func availabilityRefreshDoesNotAutoContinueWithoutPendingStartIntent() {
        let state = AssetPreflightState(
            speech: .installed,
            translation: .downloadRequired,
            startIntent: .none
        )

        #expect(WorkspaceStartActionPolicy.continuationRouteAfterAvailabilityRefresh(for: state) == nil)
    }
}
