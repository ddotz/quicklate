import Foundation

public enum TranslationRefinementProviderID: String, CaseIterable, Identifiable, Codable, Sendable {
    case off
    case foundationModels
    case mlxLocalLLM

    public var id: String { rawValue }

    public var providerRuntimeID: String {
        switch self {
        case .off:
            "noop-refinement"
        case .foundationModels:
            "foundation-models-refiner"
        case .mlxLocalLLM:
            "mlx-local-llm"
        }
    }
}

public enum TranslationRefinementAggressiveness: String, CaseIterable, Identifiable, Codable, Sendable {
    case conservative
    case balanced
    case quality

    public var id: String { rawValue }

    public var policy: TranslationRefinementPolicy {
        switch self {
        case .conservative:
            TranslationRefinementPolicy(
                stableDelaySeconds: 0.8,
                timeoutSeconds: 1.2,
                maximumConcurrentRefinements: 1,
                replacementSimilaritySkipThreshold: 0.92
            )
        case .balanced:
            TranslationRefinementPolicy(
                stableDelaySeconds: 0.5,
                timeoutSeconds: 1.8,
                maximumConcurrentRefinements: 1,
                replacementSimilaritySkipThreshold: 0.96
            )
        case .quality:
            TranslationRefinementPolicy(
                stableDelaySeconds: 0.3,
                timeoutSeconds: 3.0,
                maximumConcurrentRefinements: 1,
                replacementSimilaritySkipThreshold: 0.98
            )
        }
    }
}

public struct TranslationRefinementPolicy: Codable, Sendable, Equatable {
    public let stableDelaySeconds: TimeInterval
    public let timeoutSeconds: TimeInterval
    public let maximumConcurrentRefinements: Int
    public let replacementSimilaritySkipThreshold: Double

    public init(
        stableDelaySeconds: TimeInterval,
        timeoutSeconds: TimeInterval,
        maximumConcurrentRefinements: Int,
        replacementSimilaritySkipThreshold: Double
    ) {
        self.stableDelaySeconds = stableDelaySeconds
        self.timeoutSeconds = timeoutSeconds
        self.maximumConcurrentRefinements = maximumConcurrentRefinements
        self.replacementSimilaritySkipThreshold = replacementSimilaritySkipThreshold
    }
}

public struct TranslationContextBuilderConfiguration: Sendable, Equatable {
    public var recentUnitLimit: Int
    public var maxSourceContextCharacters: Int
    public var maxTargetContextCharacters: Int
    public var maxGlossaryEntries: Int

    public init(
        recentUnitLimit: Int = 5,
        maxSourceContextCharacters: Int = 1_200,
        maxTargetContextCharacters: Int = 1_200,
        maxGlossaryEntries: Int = 50
    ) {
        self.recentUnitLimit = recentUnitLimit
        self.maxSourceContextCharacters = maxSourceContextCharacters
        self.maxTargetContextCharacters = maxTargetContextCharacters
        self.maxGlossaryEntries = maxGlossaryEntries
    }
}

public struct TranslationContextBuilder: Sendable {
    public let configuration: TranslationContextBuilderConfiguration

    public init(configuration: TranslationContextBuilderConfiguration = .init()) {
        self.configuration = configuration
    }

    public func build(
        previousUnits: [TranslationUnit],
        currentSource: String,
        glossaryEntries: [TranslationGlossaryEntry]
    ) -> TranslationContextWindow {
        let orderedUnits = previousUnits
            .filter { $0.sourceText != currentSource }
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(configuration.recentUnitLimit)

        let sourceUnits = boundedRecentStrings(
            orderedUnits.map(\.sourceText),
            maxCharacters: configuration.maxSourceContextCharacters
        )
        let targetUnits = boundedRecentStrings(
            orderedUnits.compactMap { $0.refinedTranslation ?? $0.provisionalTranslation },
            maxCharacters: configuration.maxTargetContextCharacters
        )
        let glossary = Array(glossaryEntries.prefix(configuration.maxGlossaryEntries))

        return TranslationContextWindow(
            previousSourceUnits: sourceUnits,
            previousTargetUnits: targetUnits,
            currentSource: currentSource,
            glossaryEntries: glossary
        )
    }

    private func boundedRecentStrings(_ strings: [String], maxCharacters: Int) -> [String] {
        guard maxCharacters > 0 else { return [] }

        var selected: [String] = []
        var total = 0
        for value in strings.reversed() {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard total + trimmed.count <= maxCharacters else {
                continue
            }

            selected.append(trimmed)
            total += trimmed.count
        }

        return selected.reversed()
    }
}

public enum TranslationPromptBuilder {
    public static func prompt(request: TranslationProviderRequest) -> String {
        let glossaryLines = request.glossary.isEmpty
            ? "- none"
            : request.glossary.map { entry in
                "- \(entry.sourceTerm) => \(entry.targetTerm)\(entry.isHardRule ? " (hard)" : "")"
            }.joined(separator: "\n")

        return """
        Role: realtime subtitle translator.
        Target language: \(request.targetLanguageID)

        Rules:
        - Translate only CURRENT_SOURCE.
        - Previous source context is reference only.
        - Previous target context is reference only.
        - Do not explain, annotate, summarize, or output alternatives.
        - Preserve names, numbers, code, APIs, and glossary hard rules.
        - If target is Korean, use natural Korean subtitle style and keep technical terms in English when common.

        PREVIOUS_SOURCE_CONTEXT:
        \(request.previousSourceContext.isEmpty ? "(none)" : request.previousSourceContext)

        PREVIOUS_TARGET_CONTEXT:
        \(request.previousTargetContext.isEmpty ? "(none)" : request.previousTargetContext)

        GLOSSARY:
        \(glossaryLines)

        CURRENT_SOURCE:
        \(request.sourceText)
        """
    }
}

public enum ContextualRefinementEnqueueResult: Sendable, Equatable {
    case accepted(StableSourceSegment)
    case duplicate
}

public actor ContextualRefinementScheduler {
    private struct SegmentKey: Hashable, Sendable {
        var lineID: UUID
        var revision: Int
    }

    private var requestedKeys: Set<SegmentKey> = []

    public init() {}

    public func enqueue(_ segment: StableSourceSegment) -> ContextualRefinementEnqueueResult {
        let key = SegmentKey(lineID: segment.lineID, revision: segment.revision)
        guard !requestedKeys.contains(key) else { return .duplicate }
        requestedKeys.insert(key)
        return .accepted(segment)
    }

    public func cancel(lineID: UUID) {
        requestedKeys = requestedKeys.filter { $0.lineID != lineID }
    }

    public func cancelAll() {
        requestedKeys.removeAll()
    }
}

public struct BenchmarkScenario: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let audioFileURL: URL
    public let sourceLanguageID: String
    public let targetLanguageID: String
    public let referenceTranscript: String?
    public let referenceTranslation: String?

    public init(
        id: String,
        audioFileURL: URL,
        sourceLanguageID: String,
        targetLanguageID: String,
        referenceTranscript: String?,
        referenceTranslation: String?
    ) {
        self.id = id
        self.audioFileURL = audioFileURL
        self.sourceLanguageID = sourceLanguageID
        self.targetLanguageID = targetLanguageID
        self.referenceTranscript = referenceTranscript
        self.referenceTranslation = referenceTranslation
    }
}

public struct BenchmarkResult: Codable, Sendable, Equatable {
    public let scenarioID: String
    public let providerID: String
    public let firstPartialLatencyMs: Int?
    public let firstTranslationLatencyMs: Int?
    public let refinementLatencyMs: Int?
    public let outputTranscript: String
    public let outputTranslation: String
    public let traceEvents: [RealtimeTranslationTraceEvent]

    public init(
        scenarioID: String,
        providerID: String,
        firstPartialLatencyMs: Int?,
        firstTranslationLatencyMs: Int?,
        refinementLatencyMs: Int?,
        outputTranscript: String,
        outputTranslation: String,
        traceEvents: [RealtimeTranslationTraceEvent]
    ) {
        self.scenarioID = scenarioID
        self.providerID = providerID
        self.firstPartialLatencyMs = firstPartialLatencyMs
        self.firstTranslationLatencyMs = firstTranslationLatencyMs
        self.refinementLatencyMs = refinementLatencyMs
        self.outputTranscript = outputTranscript
        self.outputTranslation = outputTranslation
        self.traceEvents = traceEvents
    }
}
