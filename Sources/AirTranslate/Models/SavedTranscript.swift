import Foundation

struct SavedTranscript: Identifiable, Equatable {
    let id: String
    var title: String
    var sourceText: String
    var updatedAt: Date

    init(
        fileName: String,
        sourceText: String,
        updatedAt: Date
    ) {
        self.id = fileName
        self.title = SavedTranscript.title(from: sourceText, fallback: fileName)
        self.sourceText = sourceText
        self.updatedAt = updatedAt
    }

    private static func title(from text: String, fallback: String) -> String {
        let title = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let title, !title.isEmpty else {
            return fallback.replacingOccurrences(of: ".txt", with: "")
        }

        return String(title.prefix(48))
    }
}
