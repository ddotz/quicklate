import Foundation

@MainActor
struct GitHubUpdatePackageDownloader {
    private let urlSession: URLSession
    private let fileManager: FileManager

    init(urlSession: URLSession = .shared, fileManager: FileManager = .default) {
        self.urlSession = urlSession
        self.fileManager = fileManager
    }

    func downloadPackage(from packageURL: URL, latestVersion: String) async throws -> URL {
        var request = URLRequest(url: packageURL)
        request.setValue("QuickLate", forHTTPHeaderField: "User-Agent")

        let (temporaryURL, response) = try await urlSession.download(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubUpdateDownloadError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GitHubUpdateDownloadError.httpStatus(httpResponse.statusCode)
        }

        let destinationURL = try destinationURL(for: packageURL, latestVersion: latestVersion)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    private func destinationURL(for packageURL: URL, latestVersion: String) throws -> URL {
        let updateRoot = fileManager.temporaryDirectory
            .appendingPathComponent("QuickLate-SelfUpdate-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: updateRoot, withIntermediateDirectories: true)

        let extensionName = packageURL.pathExtension.isEmpty ? "zip" : packageURL.pathExtension
        let fileName = "QuickLate-\(latestVersion).\(extensionName)"
        return updateRoot.appendingPathComponent(fileName)
    }
}

enum GitHubUpdateDownloadError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            AppText.updateDownloadInvalidResponse
        case let .httpStatus(statusCode):
            AppText.updateDownloadHTTPFailed(statusCode: statusCode)
        }
    }
}
