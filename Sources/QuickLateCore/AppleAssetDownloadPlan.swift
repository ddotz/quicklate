public enum AppleAssetModel: Equatable, Sendable {
    case combined
    case speechOnly
    case translationOnly
}

public enum AppleAssetDownloadRoute: Equatable, Sendable {
    case speechAssetInventory
    case swiftUITranslationTask
}

public struct AppleAssetDownloadPlan: Equatable, Sendable {
    public let routes: [AppleAssetDownloadRoute]
    public let modelsToMarkDownloading: [AppleAssetModel]

    public init(
        model: AppleAssetModel,
        speech: AssetInstallState,
        translation: AssetInstallState
    ) {
        var routes: [AppleAssetDownloadRoute] = []
        switch model {
        case .combined:
            if speech.allowsDownloadRequest {
                routes.append(.speechAssetInventory)
            }
            if translation.allowsDownloadRequest {
                routes.append(.swiftUITranslationTask)
            }
        case .speechOnly:
            if speech.allowsDownloadRequest {
                routes.append(.speechAssetInventory)
            }
        case .translationOnly:
            if translation.allowsDownloadRequest {
                routes.append(.swiftUITranslationTask)
            }
        }

        self.routes = routes
        self.modelsToMarkDownloading = Self.modelsToMarkDownloading(requestedModel: model, routes: routes)
    }

    private static func modelsToMarkDownloading(
        requestedModel: AppleAssetModel,
        routes: [AppleAssetDownloadRoute]
    ) -> [AppleAssetModel] {
        guard !routes.isEmpty else { return [] }

        var models: [AppleAssetModel] = []
        if requestedModel != .combined {
            models.append(.combined)
        }
        models.append(requestedModel)

        if requestedModel == .combined {
            if routes.contains(.speechAssetInventory) {
                models.append(.speechOnly)
            }
            if routes.contains(.swiftUITranslationTask) {
                models.append(.translationOnly)
            }
        }

        return models
    }
}
