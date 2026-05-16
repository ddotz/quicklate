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
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("QuickLate", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response)
        let metadata = try decodedRepositoryMetadata(from: data)
        guard let version = AppVersionMetadataParser.version(in: metadata) else {
            throw GitHubUpdateCheckError.invalidVersionMetadata
        }

        return GitHubReleaseInfo(
            tagName: version,
            name: "QuickLate \(version)",
            htmlURL: AppIdentity.githubRepositoryURL
        )
    }

    private func decodedRepositoryMetadata(from data: Data) throws -> String {
        let content: GitHubContentFile
        do {
            content = try JSONDecoder().decode(GitHubContentFile.self, from: data)
        } catch {
            throw GitHubUpdateCheckError.decodeFailed(error.localizedDescription)
        }

        let normalizedEncoding = content.encoding.lowercased()
        if normalizedEncoding == "base64" {
            let normalizedContent = content.content.filter { !$0.isWhitespace }
            guard let data = Data(base64Encoded: normalizedContent),
                  let text = String(data: data, encoding: .utf8)
            else {
                throw GitHubUpdateCheckError.invalidVersionMetadata
            }
            return text
        }

        if normalizedEncoding == "utf-8" || normalizedEncoding == "utf8" {
            return content.content
        }

        throw GitHubUpdateCheckError.invalidVersionMetadata
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

private struct GitHubContentFile: Decodable {
    let content: String
    let encoding: String
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
