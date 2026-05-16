import Foundation

public struct GitHubReleaseAsset: Decodable, Equatable, Sendable {
    public let name: String
    public let browserDownloadURL: URL
    public let size: Int

    public init(name: String, browserDownloadURL: URL, size: Int) {
        self.name = name
        self.browserDownloadURL = browserDownloadURL
        self.size = size
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}

public struct GitHubReleaseInfo: Decodable, Equatable, Sendable {
    public let tagName: String
    public let name: String
    public let htmlURL: URL
    public let assets: [GitHubReleaseAsset]

    public init(
        tagName: String,
        name: String,
        htmlURL: URL,
        assets: [GitHubReleaseAsset] = []
    ) {
        self.tagName = tagName
        self.name = name
        self.htmlURL = htmlURL
        self.assets = assets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tagName = try container.decode(String.self, forKey: .tagName)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? tagName
        htmlURL = try container.decode(URL.self, forKey: .htmlURL)
        assets = try container.decodeIfPresent([GitHubReleaseAsset].self, forKey: .assets) ?? []
    }

    public var primaryUpdatePackageURL: URL? {
        primaryUpdatePackageAsset?.browserDownloadURL
    }

    public var primaryUpdatePackageAsset: GitHubReleaseAsset? {
        let packageAssets = assets.filter { asset in
            let lowercasedName = asset.name.lowercased()
            let isSupportedPackage = lowercasedName.hasSuffix(".zip") || lowercasedName.hasSuffix(".dmg")
            return isSupportedPackage && lowercasedName.contains("quicklate")
        }

        return packageAssets.sorted { lhs, rhs in
            let lhsName = lhs.name.lowercased()
            let rhsName = rhs.name.lowercased()
            if lhsName.hasSuffix(".zip") != rhsName.hasSuffix(".zip") {
                return lhsName.hasSuffix(".zip")
            }
            return lhs.name < rhs.name
        }.first
    }

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case assets
    }
}

public enum UpdateUnavailableReason: Equatable, Sendable {
    case invalidCurrentVersion
    case invalidReleaseVersion
}

public enum AppUpdateAvailability: Equatable, Sendable {
    case updateAvailable(currentVersion: String, latestVersion: String, releaseURL: URL)
    case upToDate(currentVersion: String, latestVersion: String, releaseURL: URL)
    case unavailable(reason: UpdateUnavailableReason)

    public var releaseURL: URL? {
        switch self {
        case let .updateAvailable(_, _, releaseURL), let .upToDate(_, _, releaseURL):
            releaseURL
        case .unavailable:
            nil
        }
    }
}

public enum AppVersionMetadataParser {
    public static func version(in metadata: String) -> String? {
        for line in metadata.split(whereSeparator: \.isNewline) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.hasPrefix("VERSION=") else { continue }

            if let defaultRange = trimmedLine.range(of: "${VERSION:-") {
                let suffix = trimmedLine[defaultRange.upperBound...]
                let version = suffix.prefix { character in
                    character != "}" && character != "\"" && !character.isWhitespace
                }
                return validVersion(String(version))
            }

            let rawValue = trimmedLine
                .dropFirst("VERSION=".count)
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'"))
            return validVersion(String(rawValue))
        }

        return nil
    }

    private static func validVersion(_ value: String) -> String? {
        AppReleaseVersion(value) == nil ? nil : value
    }
}

public enum AppUpdatePolicy {
    public static func availability(
        currentVersion: String,
        release: GitHubReleaseInfo
    ) -> AppUpdateAvailability {
        guard let current = AppReleaseVersion(currentVersion) else {
            return .unavailable(reason: .invalidCurrentVersion)
        }
        guard let latest = AppReleaseVersion(release.tagName) else {
            return .unavailable(reason: .invalidReleaseVersion)
        }

        if current < latest {
            return .updateAvailable(
                currentVersion: currentVersion,
                latestVersion: latest.displayString,
                releaseURL: release.htmlURL
            )
        }

        return .upToDate(
            currentVersion: currentVersion,
            latestVersion: latest.displayString,
            releaseURL: release.htmlURL
        )
    }
}

public struct AppReleaseVersion: Comparable, Equatable, Sendable {
    private let components: [Int]

    public init?(_ rawValue: String) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("v") {
            value.removeFirst()
        }

        let parsedComponents = value
            .split(separator: ".")
            .compactMap { component -> Int? in
                let numericPrefix = component.prefix { $0.isNumber }
                guard !numericPrefix.isEmpty else { return nil }
                return Int(numericPrefix)
            }

        guard !parsedComponents.isEmpty else { return nil }
        components = parsedComponents
    }

    public var displayString: String {
        components.map(String.init).joined(separator: ".")
    }

    public static func < (lhs: AppReleaseVersion, rhs: AppReleaseVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}
