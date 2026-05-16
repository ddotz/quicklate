import Foundation

public enum TranslationPhase: String, Codable, Sendable, Equatable {
    case none
    case provisional
    case stableCandidate
    case refining
    case refined
    case failed
}

public struct TranslationMetadata: Codable, Sendable, Equatable {
    public var phase: TranslationPhase
    public var provisionalText: String?
    public var refinedText: String?
    public var translatedSourceRevision: Int
    public var providerID: String?
    public var refinedAt: Date?
    public var failureReason: String?

    public init(
        phase: TranslationPhase = .none,
        provisionalText: String? = nil,
        refinedText: String? = nil,
        translatedSourceRevision: Int = 0,
        providerID: String? = nil,
        refinedAt: Date? = nil,
        failureReason: String? = nil
    ) {
        self.phase = phase
        self.provisionalText = provisionalText
        self.refinedText = refinedText
        self.translatedSourceRevision = translatedSourceRevision
        self.providerID = providerID
        self.refinedAt = refinedAt
        self.failureReason = failureReason
    }
}

public struct TranslationGlossaryEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var sourceTerm: String
    public var targetTerm: String
    public var note: String?
    public var isHardRule: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        sourceTerm: String,
        targetTerm: String,
        note: String? = nil,
        isHardRule: Bool,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceTerm = sourceTerm
        self.targetTerm = targetTerm
        self.note = note
        self.isHardRule = isHardRule
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum TranslationRequestMode: String, Codable, Sendable, Equatable {
    case provisional
    case contextualRefinement
}

public struct TranslationProviderRequest: Sendable, Equatable {
    public let sourceText: String
    public let sourceLanguageID: String
    public let targetLanguageID: String
    public let previousSourceContext: String
    public let previousTargetContext: String
    public let glossary: [TranslationGlossaryEntry]
    public let mode: TranslationRequestMode

    public init(
        sourceText: String,
        sourceLanguageID: String,
        targetLanguageID: String,
        previousSourceContext: String,
        previousTargetContext: String,
        glossary: [TranslationGlossaryEntry],
        mode: TranslationRequestMode
    ) {
        self.sourceText = sourceText
        self.sourceLanguageID = sourceLanguageID
        self.targetLanguageID = targetLanguageID
        self.previousSourceContext = previousSourceContext
        self.previousTargetContext = previousTargetContext
        self.glossary = glossary
        self.mode = mode
    }
}

public struct TranslationProviderResponse: Sendable, Equatable {
    public let translatedText: String
    public let providerID: String
    public let latencyMilliseconds: Int
    public let isFinalQuality: Bool

    public init(
        translatedText: String,
        providerID: String,
        latencyMilliseconds: Int,
        isFinalQuality: Bool
    ) {
        self.translatedText = translatedText
        self.providerID = providerID
        self.latencyMilliseconds = latencyMilliseconds
        self.isFinalQuality = isFinalQuality
    }
}

public protocol TranslationProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    func prepare(sourceLanguageID: String, targetLanguageID: String) async throws
    func translate(_ request: TranslationProviderRequest) async throws -> TranslationProviderResponse
}

public enum TranslationProviderError: LocalizedError, Sendable, Equatable {
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case let .unavailable(reason):
            reason
        }
    }
}

public struct NoOpRefinementProvider: TranslationProvider {
    public let id = "noop-refinement"
    public let displayName = "Refinement Off"

    public init() {}

    public func prepare(sourceLanguageID _: String, targetLanguageID _: String) async throws {}

    public func translate(_ request: TranslationProviderRequest) async throws -> TranslationProviderResponse {
        guard request.mode == .provisional else {
            throw TranslationProviderError.unavailable("Contextual refinement is disabled.")
        }

        return TranslationProviderResponse(
            translatedText: request.sourceText,
            providerID: id,
            latencyMilliseconds: 0,
            isFinalQuality: false
        )
    }
}

public struct TranslationUnit: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let lineID: UUID
    public let sourceText: String
    public let sourceRevision: Int
    public let sourceLanguageID: String
    public let targetLanguageID: String
    public var provisionalTranslation: String?
    public var refinedTranslation: String?
    public var phase: TranslationPhase
    public var createdAt: Date
    public var stableAt: Date?
    public var refinedAt: Date?

    public init(
        id: UUID = UUID(),
        lineID: UUID,
        sourceText: String,
        sourceRevision: Int,
        sourceLanguageID: String,
        targetLanguageID: String,
        provisionalTranslation: String? = nil,
        refinedTranslation: String? = nil,
        phase: TranslationPhase = .none,
        createdAt: Date = Date(),
        stableAt: Date? = nil,
        refinedAt: Date? = nil
    ) {
        self.id = id
        self.lineID = lineID
        self.sourceText = sourceText
        self.sourceRevision = sourceRevision
        self.sourceLanguageID = sourceLanguageID
        self.targetLanguageID = targetLanguageID
        self.provisionalTranslation = provisionalTranslation
        self.refinedTranslation = refinedTranslation
        self.phase = phase
        self.createdAt = createdAt
        self.stableAt = stableAt
        self.refinedAt = refinedAt
    }
}

public struct TranslationContextWindow: Sendable, Equatable {
    public let previousSourceUnits: [String]
    public let previousTargetUnits: [String]
    public let currentSource: String
    public let glossaryEntries: [TranslationGlossaryEntry]

    public init(
        previousSourceUnits: [String],
        previousTargetUnits: [String],
        currentSource: String,
        glossaryEntries: [TranslationGlossaryEntry]
    ) {
        self.previousSourceUnits = previousSourceUnits
        self.previousTargetUnits = previousTargetUnits
        self.currentSource = currentSource
        self.glossaryEntries = glossaryEntries
    }
}

public struct RealtimeTranslationTraceEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let kind: RealtimeTranslationTraceKind
    public let providerID: String?
    public let lineID: UUID?
    public let revision: Int?
    public let sourceCharacterCount: Int
    public let latencyMilliseconds: Int?
    public let failureReason: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: RealtimeTranslationTraceKind,
        providerID: String? = nil,
        lineID: UUID? = nil,
        revision: Int? = nil,
        sourceCharacterCount: Int = 0,
        latencyMilliseconds: Int? = nil,
        failureReason: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.providerID = providerID
        self.lineID = lineID
        self.revision = revision
        self.sourceCharacterCount = sourceCharacterCount
        self.latencyMilliseconds = latencyMilliseconds
        self.failureReason = failureReason
    }
}

public enum RealtimeTranslationTraceKind: String, Codable, Sendable, Equatable {
    case asrPartialReceived
    case provisionalTranslationRequested
    case provisionalTranslationApplied
    case stableSegmentDetected
    case refinementRequested
    case refinementAccepted
    case refinementRejected
    case refinementTimedOut
    case providerUnavailable
}
