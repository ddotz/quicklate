import Foundation
import Testing
@testable import QuickLateCore

@Suite
struct TranslationGlossaryStoreTests {
    @Test
    func glossaryStorePersistsCrudOperations() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quicklate-glossary-tests-")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("glossary.json")
        let store = TranslationGlossaryStore(fileURL: fileURL)
        let entry = TranslationGlossaryEntry(
            sourceTerm: "latency",
            targetTerm: "레이턴시",
            note: "technical term",
            isHardRule: true,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )

        try await store.upsert(entry)
        #expect(try await store.entries().map(\.sourceTerm) == ["latency"])

        var updated = entry
        updated.targetTerm = "지연 시간"
        try await store.upsert(updated)
        #expect(try await store.entries().first?.targetTerm == "지연 시간")

        let reloaded = TranslationGlossaryStore(fileURL: fileURL)
        #expect(try await reloaded.entries().first?.note == "technical term")

        try await reloaded.delete(id: entry.id)
        #expect(try await reloaded.entries().isEmpty)
    }

    @Test
    func glossaryStoreFiltersByLanguagePairWhenPresent() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quicklate-glossary-tests-")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = TranslationGlossaryStore(fileURL: directory.appendingPathComponent("glossary.json"))
        try await store.upsert(TranslationGlossaryEntry(
            sourceTerm: "token",
            targetTerm: "토큰",
            sourceLanguageID: "en-US",
            targetLanguageID: "ko-KR",
            isHardRule: false
        ))
        try await store.upsert(TranslationGlossaryEntry(
            sourceTerm: "model",
            targetTerm: "model",
            sourceLanguageID: "en-US",
            targetLanguageID: "ja-JP",
            isHardRule: false
        ))

        let entries = try await store.entries(sourceLanguageID: "en-US", targetLanguageID: "ko-KR")

        #expect(entries.map(\.sourceTerm) == ["token"])
    }
}
