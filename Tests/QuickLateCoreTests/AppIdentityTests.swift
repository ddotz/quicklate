import Testing
@testable import QuickLateCore

@Suite
struct AppIdentityTests {
    @Test
    func productNameIsQuickLate() {
        #expect(AppIdentity.productName == "QuickLate")
    }
}
