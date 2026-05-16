import Foundation

public enum TranslationValidationResult: Sendable, Equatable {
    case accepted
    case rejected(reason: TranslationValidationFailureReason)
}

public enum TranslationValidationFailureReason: String, Sendable, Codable, Equatable {
    case empty
    case tooLong
    case containsPromptLeak
    case repeatsSourceVerbatim
    case wrongLanguageLikely
    case glossaryViolation
    case duplicateOfPreviousContext
}

public enum TranslationResultValidator {
    private static let promptLeakPrefixes = [
        "translation:",
        "translated:",
        "here is",
        "here's",
        "번역:",
        "번역문:",
        "설명:",
        "대안 번역"
    ]

    public static func validate(
        refinedText: String,
        sourceText: String,
        previousTargetContext: String,
        targetLanguageID: String,
        glossary: [TranslationGlossaryEntry]
    ) -> TranslationValidationResult {
        let output = normalize(refinedText)
        let source = normalize(sourceText)
        let previousTarget = normalize(previousTargetContext)

        guard !output.isEmpty else { return .rejected(reason: .empty) }
        guard output.count <= maximumOutputLength(forSource: source) else { return .rejected(reason: .tooLong) }
        guard !containsPromptLeak(output) else { return .rejected(reason: .containsPromptLeak) }
        guard !repeatsSourceVerbatim(output: output, source: source) else {
            return .rejected(reason: .repeatsSourceVerbatim)
        }
        guard !duplicatesPreviousContext(output: output, previousTargetContext: previousTarget) else {
            return .rejected(reason: .duplicateOfPreviousContext)
        }
        guard !isWrongLanguageLikely(output: output, targetLanguageID: targetLanguageID) else {
            return .rejected(reason: .wrongLanguageLikely)
        }
        guard !violatesHardGlossary(output: output, source: source, glossary: glossary) else {
            return .rejected(reason: .glossaryViolation)
        }

        return .accepted
    }

    private static func maximumOutputLength(forSource source: String) -> Int {
        max(120, source.count * 4 + 40)
    }

    private static func containsPromptLeak(_ output: String) -> Bool {
        let lowered = output.lowercased()
        return promptLeakPrefixes.contains { lowered.hasPrefix($0) }
    }

    private static func repeatsSourceVerbatim(output: String, source: String) -> Bool {
        guard source.count >= 12 else { return false }
        return comparable(output) == comparable(source)
    }

    private static func duplicatesPreviousContext(output: String, previousTargetContext: String) -> Bool {
        guard output.count >= 12, !previousTargetContext.isEmpty else { return false }
        return comparable(output) == comparable(previousTargetContext)
    }

    private static func isWrongLanguageLikely(output: String, targetLanguageID: String) -> Bool {
        let normalizedTarget = targetLanguageID.lowercased()
        if normalizedTarget.hasPrefix("ko") {
            return koreanCharacterRatio(in: output) < 0.18 && latinCharacterRatio(in: output) > 0.55 && output.count >= 24
        }

        return false
    }

    private static func violatesHardGlossary(
        output: String,
        source: String,
        glossary: [TranslationGlossaryEntry]
    ) -> Bool {
        glossary.contains { entry in
            guard entry.isHardRule else { return false }
            let sourceTerm = entry.sourceTerm.trimmingCharacters(in: .whitespacesAndNewlines)
            let targetTerm = entry.targetTerm.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sourceTerm.isEmpty, !targetTerm.isEmpty else { return false }
            guard contains(sourceTerm, in: source) else { return false }
            return !contains(targetTerm, in: output)
        }
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func comparable(_ text: String) -> String {
        normalize(text)
            .lowercased()
    }

    private static func contains(_ needle: String, in haystack: String) -> Bool {
        haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static func koreanCharacterRatio(in text: String) -> Double {
        characterRatio(in: text) { scalar in
            (0xAC00...0xD7A3).contains(Int(scalar.value))
                || (0x1100...0x11FF).contains(Int(scalar.value))
                || (0x3130...0x318F).contains(Int(scalar.value))
        }
    }

    private static func latinCharacterRatio(in text: String) -> Double {
        characterRatio(in: text) { scalar in
            ("a"..."z").contains(Character(scalar).lowercased())
        }
    }

    private static func characterRatio(
        in text: String,
        matching predicate: (UnicodeScalar) -> Bool
    ) -> Double {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return 0 }
        let matched = letters.filter(predicate).count
        return Double(matched) / Double(letters.count)
    }
}
