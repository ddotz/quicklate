import Foundation
import Testing
@testable import QuickLateCore

@Suite
struct StableSegmentDetectorTests {
    @Test
    func unchangedTextEmitsOnceAfterThreshold() async {
        let detector = StableSegmentDetector(
            configuration: .init(unchangedThreshold: 0.5, minimumCharacterCount: 12, minimumWordCount: 3)
        )
        let lineID = UUID()
        let start = Date(timeIntervalSince1970: 100)

        let first = await detector.ingest(
            sourceText: "This is a stable sentence",
            lineID: lineID,
            revision: 1,
            timestamp: start
        )
        let early = await detector.ingest(
            sourceText: "This is a stable sentence",
            lineID: lineID,
            revision: 1,
            timestamp: start.addingTimeInterval(0.3)
        )
        let stable = await detector.ingest(
            sourceText: "This is a stable sentence",
            lineID: lineID,
            revision: 1,
            timestamp: start.addingTimeInterval(0.6)
        )
        let duplicate = await detector.ingest(
            sourceText: "This is a stable sentence",
            lineID: lineID,
            revision: 1,
            timestamp: start.addingTimeInterval(1.2)
        )

        #expect(first == .none)
        #expect(early == .none)
        #expect(stable.segment?.sourceText == "This is a stable sentence")
        #expect(stable.segment?.lineID == lineID)
        #expect(stable.segment?.revision == 1)
        #expect(stable.segment?.reason == .unchangedForThreshold)
        #expect(duplicate == .none)
    }

    @Test
    func changingPartialDoesNotEmitBeforeThreshold() async {
        let detector = StableSegmentDetector(
            configuration: .init(unchangedThreshold: 0.5, minimumCharacterCount: 12, minimumWordCount: 3)
        )
        let lineID = UUID()
        let start = Date(timeIntervalSince1970: 200)

        _ = await detector.ingest(
            sourceText: "This partial keeps moving",
            lineID: lineID,
            revision: 1,
            timestamp: start
        )
        let changed = await detector.ingest(
            sourceText: "This partial keeps moving forward",
            lineID: lineID,
            revision: 2,
            timestamp: start.addingTimeInterval(0.4)
        )

        #expect(changed == .none)
    }

    @Test
    func punctuationBoundaryEmitsCandidateWithoutWaiting() async {
        let detector = StableSegmentDetector(
            configuration: .init(unchangedThreshold: 0.5, minimumCharacterCount: 12, minimumWordCount: 3)
        )
        let lineID = UUID()
        let now = Date(timeIntervalSince1970: 300)

        let decision = await detector.ingest(
            sourceText: "This sentence is complete.",
            lineID: lineID,
            revision: 7,
            timestamp: now
        )

        #expect(decision.segment?.sourceText == "This sentence is complete.")
        #expect(decision.segment?.revision == 7)
        #expect(decision.segment?.reason == .punctuationBoundary)
    }

    @Test
    func flushCommitsPendingSegmentForPauseOrStop() async {
        let detector = StableSegmentDetector(
            configuration: .init(unchangedThreshold: 0.5, minimumCharacterCount: 12, minimumWordCount: 3)
        )
        let lineID = UUID()
        let start = Date(timeIntervalSince1970: 400)

        _ = await detector.ingest(
            sourceText: "Flush this pending sentence",
            lineID: lineID,
            revision: 3,
            timestamp: start
        )
        let flushed = await detector.flush(
            lineID: lineID,
            timestamp: start.addingTimeInterval(0.1),
            reason: .manualStopOrPause
        )
        let duplicateFlush = await detector.flush(
            lineID: lineID,
            timestamp: start.addingTimeInterval(0.2),
            reason: .manualStopOrPause
        )

        #expect(flushed.segment?.sourceText == "Flush this pending sentence")
        #expect(flushed.segment?.revision == 3)
        #expect(flushed.segment?.reason == .manualStopOrPause)
        #expect(duplicateFlush == .none)
    }

    @Test
    func shortSegmentsAreIgnored() async {
        let detector = StableSegmentDetector(
            configuration: .init(unchangedThreshold: 0.5, minimumCharacterCount: 12, minimumWordCount: 3)
        )
        let lineID = UUID()
        let now = Date(timeIntervalSince1970: 500)

        let decision = await detector.ingest(
            sourceText: "Too short.",
            lineID: lineID,
            revision: 1,
            timestamp: now.addingTimeInterval(1)
        )
        let flushed = await detector.flush(
            lineID: lineID,
            timestamp: now.addingTimeInterval(2),
            reason: .manualStopOrPause
        )

        #expect(decision == .none)
        #expect(flushed == .none)
    }
}

private extension StableSegmentDecision {
    var segment: StableSourceSegment? {
        switch self {
        case .none:
            nil
        case let .candidate(segment), let .committed(segment):
            segment
        }
    }
}
