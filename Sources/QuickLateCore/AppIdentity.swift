import Foundation

public enum AppIdentity {
    public static let productName = "QuickLate"
    public static let githubOwner = "ddotz"
    public static let githubRepository = "quicklate"
    public static let githubRepositoryURL = URL(string: "https://github.com/ddotz/quicklate")!
    public static let githubLatestReleaseAPIURL = URL(string: "https://api.github.com/repos/ddotz/quicklate/releases/latest")!
    public static let githubVersionMetadataURL = URL(string: "https://api.github.com/repos/ddotz/quicklate/contents/script/app_metadata.sh?ref=main")!
}
