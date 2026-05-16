import Foundation
import Testing
@testable import QuickLateCore

@Suite
struct TranslationBenchmarkRunnerTests {
    @Test
    func benchmarkRunnerExportsJsonAndCsvWithoutRawAudio() throws {
        let result = BenchmarkResult(
            scenarioID: "meeting-en-ko",
            providerID: "apple-fast-translation",
            firstPartialLatencyMs: 100,
            firstTranslationLatencyMs: 180,
            refinementLatencyMs: nil,
            outputTranscript: "",
            outputTranslation: "",
            traceEvents: []
        )

        let jsonData = try TranslationBenchmarkRunner.jsonData(for: [result])
        let json = String(decoding: jsonData, as: UTF8.self)
        let csv = TranslationBenchmarkRunner.csvString(for: [result])

        #expect(json.contains("meeting-en-ko"))
        #expect(!json.contains("rawAudio"))
        #expect(csv.contains("scenarioID,providerID,firstPartialLatencyMs,firstTranslationLatencyMs,refinementLatencyMs"))
        #expect(csv.contains("meeting-en-ko,apple-fast-translation,100,180,"))
    }
}
