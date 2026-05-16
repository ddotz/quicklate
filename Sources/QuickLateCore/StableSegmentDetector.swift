import Foundation

public struct StableSegmentDetectorConfiguration: Sendable, Equatable {
    public var unchangedThreshold: TimeInterval
    public var silenceFlushDelay: TimeInterval
    public var minimumCharacterCount: Int
    public var minimumWordCount: Int
    public var maximumCharacterCount: Int

    public init(
        unchangedThreshold: TimeInterval = 0.5,
        silenceFlushDelay: TimeInterval = 0.7,
        minimumCharacterCount: Int = 12,
        minimumWordCount: Int = 3,
        maximumCharacterCount: Int = 500
    ) {
        self.unchangedThreshold = unchangedThreshold
        self.silenceFlushDelay = silenceFlushDelay
        self.minimumCharacterCount = minimumCharacterCount
        self.minimumWordCount = minimumWordCount
        self.maximumCharacterCount = maximumCharacterCount
    }
}

public actor StableSegmentDetector {
    public typealias Configuration = StableSegmentDetectorConfiguration

    private struct PendingSegmentState: Sendable {
        var sourceText: String
        var revision: Int
        var firstSeenAt: Date
        var latestSeenAt: Date
    }

    private struct RevisionKey: Hashable, Sendable {
        var lineID: UUID
        var revision: Int
    }

    private let configuration: Configuration
    private var pendingByLineID: [UUID: PendingSegmentState] = [:]
    private var emittedRevisions: Set<RevisionKey> = []

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    public func ingest(
        sourceText: String,
        lineID: UUID,
        revision: Int,
        timestamp: Date
    ) -> StableSegmentDecision {
        let normalizedText = normalized(sourceText)
        guard qualifiesForRefinement(normalizedText) else {
            pendingByLineID.removeValue(forKey: lineID)
            return .none
        }

        let revisionKey = RevisionKey(lineID: lineID, revision: revision)
        guard !emittedRevisions.contains(revisionKey) else { return .none }

        if isPunctuationBoundary(normalizedText) {
            pendingByLineID[lineID] = PendingSegmentState(
                sourceText: normalizedText,
                revision: revision,
                firstSeenAt: timestamp,
                latestSeenAt: timestamp
            )
            return emit(.candidate, lineID: lineID, text: normalizedText, revision: revision, timestamp: timestamp, reason: .punctuationBoundary)
        }

        guard var pending = pendingByLineID[lineID],
              pending.revision == revision,
              pending.sourceText == normalizedText
        else {
            pendingByLineID[lineID] = PendingSegmentState(
                sourceText: normalizedText,
                revision: revision,
                firstSeenAt: timestamp,
                latestSeenAt: timestamp
            )
            return .none
        }

        pending.latestSeenAt = timestamp
        pendingByLineID[lineID] = pending

        guard timestamp.timeIntervalSince(pending.firstSeenAt) >= configuration.unchangedThreshold else {
            return .none
        }

        return emit(.candidate, lineID: lineID, text: normalizedText, revision: revision, timestamp: timestamp, reason: .unchangedForThreshold)
    }

    public func flush(
        lineID: UUID,
        timestamp: Date,
        reason: StableReason = .manualStopOrPause
    ) -> StableSegmentDecision {
        guard let pending = pendingByLineID[lineID] else { return .none }
        let normalizedText = normalized(pending.sourceText)
        guard qualifiesForRefinement(normalizedText) else {
            pendingByLineID.removeValue(forKey: lineID)
            return .none
        }

        let revisionKey = RevisionKey(lineID: lineID, revision: pending.revision)
        guard !emittedRevisions.contains(revisionKey) else { return .none }

        return emit(
            .committed,
            lineID: lineID,
            text: normalizedText,
            revision: pending.revision,
            timestamp: timestamp,
            reason: reason
        )
    }

    public func reset(lineID: UUID? = nil) {
        guard let lineID else {
            pendingByLineID.removeAll()
            emittedRevisions.removeAll()
            return
        }

        pendingByLineID.removeValue(forKey: lineID)
        emittedRevisions = emittedRevisions.filter { $0.lineID != lineID }
    }

    private enum EmissionKind {
        case candidate
        case committed
    }

    private func emit(
        _ kind: EmissionKind,
        lineID: UUID,
        text: String,
        revision: Int,
        timestamp: Date,
        reason: StableReason
    ) -> StableSegmentDecision {
        emittedRevisions.insert(RevisionKey(lineID: lineID, revision: revision))
        let segment = StableSourceSegment(
            lineID: lineID,
            sourceText: text,
            revision: revision,
            detectedAt: timestamp,
            reason: reason
        )

        switch kind {
        case .candidate:
            return .candidate(segment)
        case .committed:
            return .committed(segment)
        }
    }

    private func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func qualifiesForRefinement(_ text: String) -> Bool {
        guard !text.isEmpty, text.count <= configuration.maximumCharacterCount else { return false }
        if text.count >= configuration.minimumCharacterCount { return true }
        return wordCount(in: text) >= configuration.minimumWordCount
    }

    private func wordCount(in text: String) -> Int {
        text.split { character in
            character.isWhitespace || character.isPunctuation
        }.count
    }

    private func isPunctuationBoundary(_ text: String) -> Bool {
        guard let lastCharacter = text.last else { return false }
        return ".!?。！？".contains(lastCharacter)
    }
}

public enum StableSegmentDecision: Sendable, Equatable {
    case none
    case candidate(StableSourceSegment)
    case committed(StableSourceSegment)
}

public struct StableSourceSegment: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let lineID: UUID
    public let sourceText: String
    public let revision: Int
    public let detectedAt: Date
    public let reason: StableReason

    public init(
        id: UUID = UUID(),
        lineID: UUID,
        sourceText: String,
        revision: Int,
        detectedAt: Date,
        reason: StableReason
    ) {
        self.id = id
        self.lineID = lineID
        self.sourceText = sourceText
        self.revision = revision
        self.detectedAt = detectedAt
        self.reason = reason
    }
}

public enum StableReason: String, Sendable, Codable, Equatable {
    case unchangedForThreshold
    case punctuationBoundary
    case silenceBoundary
    case paragraphBreak
    case manualStopOrPause
}
