import Foundation
import QuickLateCore

struct GitHubUpdateChecker {
    private let releaseURL: URL
    private let versionMetadataURL: URL
    private let urlSession: URLSession

    init(
        releaseURL: URL = AppIdentity.githubLatestReleaseAPIURL,
        versionMetadataURL: URL = AppIdentity.githubVersionMetadataURL,
        urlSession: URLSession = .shared
    ) {
        self.releaseURL = releaseURL
        self.versionMetadataURL = versionMetadataURL
        self.urlSession = urlSession
    }

    func latestRelease() async throws -> GitHubReleaseInfo {
        do {
            return try await latestGitHubRelease()
        } catch GitHubUpdateCheckError.httpStatus(404) {
            return try await repositoryVersionMetadata()
        }
    }

    private func latestGitHubRelease() async throws -> GitHubReleaseInfo {
        var request = URLRequest(url: releaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("QuickLate", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response)

        do {
            return try JSONDecoder().decode(GitHubReleaseInfo.self, from: data)
        } catch {
            throw GitHubUpdateCheckError.decodeFailed(error.localizedDescription)
        }
    }

    private func repositoryVersionMetadata() async throws -> GitHubReleaseInfo {
        var request = URLRequest(url: versionMetadataURL)
        request.setValue("text/plain", forHTTPHeaderField: "Accept")
        request.setValue("QuickLate", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response)
        guard let metadata = String(data: data, encoding: .utf8),
              let version = AppVersionMetadataParser.version(in: metadata)
        else {
            throw GitHubUpdateCheckError.invalidVersionMetadata
        }

        return GitHubReleaseInfo(
            tagName: version,
            name: "QuickLate \(version)",
            htmlURL: AppIdentity.githubRepositoryURL
        )
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubUpdateCheckError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GitHubUpdateCheckError.httpStatus(httpResponse.statusCode)
        }
    }
}

enum GitHubUpdateCheckError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case decodeFailed(String)
    case invalidVersionMetadata

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            AppText.updateCheckInvalidResponse
        case let .httpStatus(statusCode):
            AppText.updateCheckHTTPFailed(statusCode: statusCode)
        case let .decodeFailed(message):
            AppText.updateCheckDecodeFailed(message)
        case .invalidVersionMetadata:
            AppText.updateCheckInvalidReleaseVersion
        }
    }
}
