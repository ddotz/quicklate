import Foundation

public enum TranslationBenchmarkRunner {
    public static func jsonData(for results: [BenchmarkResult]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(results)
    }

    public static func writeJSON(results: [BenchmarkResult], to fileURL: URL) throws {
        try jsonData(for: results).write(to: fileURL, options: [.atomic])
    }

    public static func csvString(for results: [BenchmarkResult]) -> String {
        let header = "scenarioID,providerID,firstPartialLatencyMs,firstTranslationLatencyMs,refinementLatencyMs,fallbackRateEventCount,traceEventCount"
        let rows = results.map { result in
            let fallbackEventCount = result.traceEvents.filter { event in
                event.kind == .refinementRejected
                    || event.kind == .refinementTimedOut
                    || event.kind == .providerUnavailable
            }.count
            let columns: [String] = [
                csvEscaped(result.scenarioID),
                csvEscaped(result.providerID),
                result.firstPartialLatencyMs.map { String($0) } ?? "",
                result.firstTranslationLatencyMs.map { String($0) } ?? "",
                result.refinementLatencyMs.map { String($0) } ?? "",
                String(fallbackEventCount),
                String(result.traceEvents.count)
            ]
            return columns.joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    public static func writeCSV(results: [BenchmarkResult], to fileURL: URL) throws {
        try csvString(for: results).write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private static func csvEscaped(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
