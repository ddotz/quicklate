import Foundation

public actor TranslationGlossaryStore {
    private let fileURL: URL
    private var cachedEntries: [TranslationGlossaryEntry]?

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func entries() async throws -> [TranslationGlossaryEntry] {
        try await loadEntries()
    }

    public func entries(sourceLanguageID: String, targetLanguageID: String) async throws -> [TranslationGlossaryEntry] {
        try await loadEntries().filter { entry in
            let sourceMatches = entry.sourceLanguageID == nil || entry.sourceLanguageID == sourceLanguageID
            let targetMatches = entry.targetLanguageID == nil || entry.targetLanguageID == targetLanguageID
            return sourceMatches && targetMatches
        }
    }

    public func upsert(_ entry: TranslationGlossaryEntry) async throws {
        var entries = try await loadEntries()
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        entries.sort { lhs, rhs in
            lhs.sourceTerm.localizedCaseInsensitiveCompare(rhs.sourceTerm) == .orderedAscending
        }
        try await save(entries)
    }

    public func delete(id: UUID) async throws {
        var entries = try await loadEntries()
        entries.removeAll { $0.id == id }
        try await save(entries)
    }

    public func deleteAll() async throws {
        try await save([])
    }

    private func loadEntries() async throws -> [TranslationGlossaryEntry] {
        if let cachedEntries { return cachedEntries }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cachedEntries = []
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let entries = try JSONDecoder.iso8601Decoder.decode([TranslationGlossaryEntry].self, from: data)
        cachedEntries = entries
        return entries
    }

    private func save(_ entries: [TranslationGlossaryEntry]) async throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.sortedPrettyPrinted.encode(entries)
        try data.write(to: fileURL, options: [.atomic])
        cachedEntries = entries
    }
}

private extension JSONEncoder {
    static var sortedPrettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var iso8601Decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
