import Foundation
import Testing
@testable import QuickLateCore

@Suite
struct UpdateAvailabilityTests {
    @Test
    func detectsNewerGitHubReleaseWithVPrefix() throws {
        let releaseURL = try #require(URL(string: "https://github.com/ddotz/quicklate/releases/tag/v1.2.0"))
        let release = GitHubReleaseInfo(
            tagName: "v1.2.0",
            name: "QuickLate 1.2.0",
            htmlURL: releaseURL
        )

        #expect(AppUpdatePolicy.availability(
            currentVersion: "1.1.9",
            release: release
        ) == .updateAvailable(
            currentVersion: "1.1.9",
            latestVersion: "1.2.0",
            releaseURL: releaseURL
        ))
    }

    @Test
    func comparesNumericComponentsInsteadOfStrings() throws {
        let releaseURL = try #require(URL(string: "https://github.com/ddotz/quicklate/releases/tag/v1.0.10"))
        let release = GitHubReleaseInfo(
            tagName: "1.0.10",
            name: "QuickLate 1.0.10",
            htmlURL: releaseURL
        )

        #expect(AppUpdatePolicy.availability(
            currentVersion: "1.0.2",
            release: release
        ) == .updateAvailable(
            currentVersion: "1.0.2",
            latestVersion: "1.0.10",
            releaseURL: releaseURL
        ))
    }

    @Test
    func reportsUpToDateForSameOrOlderRelease() throws {
        let releaseURL = try #require(URL(string: "https://github.com/ddotz/quicklate/releases/tag/v1.2.0"))
        let release = GitHubReleaseInfo(
            tagName: "v1.2.0",
            name: "QuickLate 1.2.0",
            htmlURL: releaseURL
        )

        #expect(AppUpdatePolicy.availability(
            currentVersion: "1.2.0",
            release: release
        ) == .upToDate(
            currentVersion: "1.2.0",
            latestVersion: "1.2.0",
            releaseURL: releaseURL
        ))
        #expect(AppUpdatePolicy.availability(
            currentVersion: "1.3.0",
            release: release
        ) == .upToDate(
            currentVersion: "1.3.0",
            latestVersion: "1.2.0",
            releaseURL: releaseURL
        ))
    }

    @Test
    func rejectsReleaseTagsWithoutVersionNumbers() throws {
        let releaseURL = try #require(URL(string: "https://github.com/ddotz/quicklate/releases/tag/latest"))
        let release = GitHubReleaseInfo(
            tagName: "latest",
            name: "Latest build",
            htmlURL: releaseURL
        )

        #expect(AppUpdatePolicy.availability(
            currentVersion: "1.2.0",
            release: release
        ) == .unavailable(reason: .invalidReleaseVersion))
    }

    @Test
    func parsesRepositoryVersionMetadataShellDefault() {
        let metadata = #"VERSION="${VERSION:-0.2.0}""#

        #expect(AppVersionMetadataParser.version(in: metadata) == "0.2.0")
    }

    @Test
    func decodesGitHubReleaseWhenNameIsNull() throws {
        let json = #"{"tag_name":"v1.2.0","name":null,"html_url":"https://github.com/ddotz/quicklate/releases/tag/v1.2.0"}"#
            .data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubReleaseInfo.self, from: json)

        #expect(release.name == "v1.2.0")
    }

    @Test
    func selectsQuickLateZipAssetForUpdatePackage() throws {
        let json = #"""
        {
          "tag_name": "v1.3.0",
          "name": "QuickLate 1.3.0",
          "html_url": "https://github.com/ddotz/quicklate/releases/tag/v1.3.0",
          "assets": [
            {
              "name": "notes.txt",
              "browser_download_url": "https://github.com/ddotz/quicklate/releases/download/v1.3.0/notes.txt",
              "size": 128
            },
            {
              "name": "QuickLate-1.3.0.zip",
              "browser_download_url": "https://github.com/ddotz/quicklate/releases/download/v1.3.0/QuickLate-1.3.0.zip",
              "size": 3181255
            }
          ]
        }
        """#.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubReleaseInfo.self, from: json)

        #expect(release.primaryUpdatePackageURL?.absoluteString == "https://github.com/ddotz/quicklate/releases/download/v1.3.0/QuickLate-1.3.0.zip")
    }
}
