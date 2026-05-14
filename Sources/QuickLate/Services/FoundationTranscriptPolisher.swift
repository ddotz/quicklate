import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

actor FoundationTranscriptPolisher {
    private static let maxChunkCharacters = 2_800

    func polishTranscript(_ text: String) async throws -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return "" }

#if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw FoundationTranscriptPolisherError.unavailable(String(describing: model.availability))
        }

        var polishedChunks: [String] = []
        for chunk in Self.chunks(from: trimmedText) {
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(to: Self.prompt(for: chunk))
            let polishedChunk = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            polishedChunks.append(polishedChunk.isEmpty ? chunk : polishedChunk)
        }

        return polishedChunks.joined(separator: "\n\n")
#else
        throw FoundationTranscriptPolisherError.frameworkUnavailable
#endif
    }

    private static func chunks(from text: String) -> [String] {
        var chunks: [String] = []
        var current = ""

        for paragraph in text.components(separatedBy: "\n\n") {
            let paragraph = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraph.isEmpty else { continue }

            if paragraph.count > maxChunkCharacters {
                appendCurrentChunk(&current, to: &chunks)
                chunks.append(contentsOf: splitLongParagraph(paragraph))
                continue
            }

            if current.count + paragraph.count + 2 > maxChunkCharacters {
                appendCurrentChunk(&current, to: &chunks)
            }

            if current.isEmpty {
                current = paragraph
            } else {
                current += "\n\n" + paragraph
            }
        }

        appendCurrentChunk(&current, to: &chunks)
        return chunks
    }

    private static func appendCurrentChunk(_ current: inout String, to chunks: inout [String]) {
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        chunks.append(trimmed)
        current = ""
    }

    private static func splitLongParagraph(_ paragraph: String) -> [String] {
        var chunks: [String] = []
        var current = ""

        for line in paragraph.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if current.count + line.count + 1 > maxChunkCharacters {
                appendCurrentChunk(&current, to: &chunks)
            }

            if current.isEmpty {
                current = line
            } else {
                current += "\n" + line
            }
        }

        appendCurrentChunk(&current, to: &chunks)
        return chunks
    }

#if canImport(FoundationModels)
    private static let instructions = """
    You clean up saved live transcript text. Preserve the original language, meaning, order, names, numbers, and technical terms. Do not summarize. Do not translate. Fix obvious speech-to-text word errors, casing, punctuation, spacing, repeated filler fragments, and stutters only when the correction is clear. Return only the cleaned transcript text.
    """

    private static func prompt(for text: String) -> String {
        """
        Clean this transcript text. Return only the cleaned text.

        \(text)
        """
    }
#endif
}

enum FoundationTranscriptPolisherError: LocalizedError {
    case frameworkUnavailable
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .frameworkUnavailable:
            AppText.foundationModelCleanupFrameworkUnavailable
        case let .unavailable(reason):
            AppText.foundationModelCleanupUnavailable(reason)
        }
    }
}
