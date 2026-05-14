import Testing
@testable import QuickLateCore

@Suite
struct TranscriptTextProcessorTests {
    @Test
    func recentCommittedReplayReturnsOnlyNewTail() {
        let committed = """
        And every day we completed nearly 10 feature requests from the critters routine.
        All right Chad this is my last slide.
        """
        let incoming = """
        And every day, we completed nearly 10 feature requests from the critters routine.
        All right, Chad, this is my last slide.
        I'm yeah, I think we'll be ready.
        """

        let replay = TranscriptTextProcessor.incomingTailAfterRecentCommittedReplay(
            incoming,
            committedText: committed,
            languageID: "en-US"
        )

        #expect(replay?.committedText == """
        And every day, we completed nearly 10 feature requests from the critters routine.
        All right, Chad, this is my last slide.
        """)
        #expect(replay?.tailText == "I'm yeah, I think we'll be ready.")
    }

    @Test
    func recentReplayDoesNotCrossParagraphBoundary() {
        let committed = """
        And every day we completed nearly 10 feature requests

        All right Chad this is my last slide
        """
        let incoming = """
        And every day we completed nearly 10 feature requests
        All right Chad this is my last slide
        I'm yeah, I think we'll be ready
        """

        let replay = TranscriptTextProcessor.incomingTailAfterRecentCommittedReplay(
            incoming,
            committedText: committed,
            languageID: "en-US"
        )

        #expect(replay == nil)
    }

    @Test
    func currentPartialRevisionAcceptsWordCompletion() {
        #expect(TranscriptTextProcessor.isRevisionOfCurrentPartial(
            current: "T",
            incoming: "Typically, this kind of loop can truly take anywhere"
        ))
        #expect(TranscriptTextProcessor.isRevisionOfCurrentPartial(
            current: "So to sum",
            incoming: "So to summarize on my piece here"
        ))
    }

    @Test
    func repeatedPartialAfterParagraphBreakCanBeRealSpeech() {
        let committed = """
        Previous line
        All right Chad this is my last slide
        """
        let repeated = "All right Chad this is my last slide"

        #expect(!TranscriptTextProcessor.shouldAppendCommittedPartial(
            repeated,
            to: committed,
            pendingParagraphBreak: false
        ))
        #expect(TranscriptTextProcessor.shouldAppendCommittedPartial(
            repeated,
            to: committed,
            pendingParagraphBreak: true
        ))
    }

    @Test
    func displayTailKeepsRecentTextAtLineBoundary() {
        let text = """
        First line that can be hidden
        Second line that should stay visible
        Third line that should also stay visible
        """

        #expect(TranscriptTextProcessor.displayTail(
            from: text,
            maxCharacters: 75
        ) == """
        ...
        Second line that should stay visible
        Third line that should also stay visible
        """)
    }

    @Test
    func displayTailFallsBackToCharacterBoundary() {
        let text = "abcdefghijklmnopqrstuvwxyz"

        #expect(TranscriptTextProcessor.displayTail(
            from: text,
            maxCharacters: 8
        ) == """
        ...
        stuvwxyz
        """)
    }
}
