import Testing
@testable import QuickLateCore

@Suite
struct AppIdentityTests {
    @Test
    func productNameIsQuickLate() {
        #expect(AppIdentity.productName == "QuickLate")
    }

    @Test
    func githubReleaseEndpointTargetsQuickLateRepository() {
        #expect(AppIdentity.githubOwner == "ddotz")
        #expect(AppIdentity.githubRepository == "quicklate")
        #expect(AppIdentity.githubLatestReleaseAPIURL.absoluteString == "https://api.github.com/repos/ddotz/quicklate/releases/latest")
        #expect(AppIdentity.githubVersionMetadataURL.absoluteString == "https://raw.githubusercontent.com/ddotz/quicklate/main/script/app_metadata.sh")
    }
}
