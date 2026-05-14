import Foundation

extension String {
    func floatingCaptionTail(maxLines: Int) -> String {
        let maxLines = max(1, maxLines)
        let trimmedText = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return "" }
        let maxCharacters = maxLines * 72
        let captionText = trimmedText.floatingCaptionSentenceBreaks()
        let scanText = String(captionText.boundedSuffix(maxCharacters: maxCharacters * 3))

        let logicalLines = scanText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let tailText: String
        if logicalLines.count > maxLines {
            tailText = logicalLines.suffix(maxLines).joined(separator: "\n")
        } else {
            tailText = scanText
        }

        guard tailText.count > maxCharacters else { return tailText }

        return String(tailText.suffix(maxCharacters))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func boundedSuffix(maxCharacters: Int) -> Substring {
        guard maxCharacters > 0,
              let start = index(endIndex, offsetBy: -maxCharacters, limitedBy: startIndex)
        else {
            return self[startIndex..<endIndex]
        }

        return self[start..<endIndex]
    }

    private func floatingCaptionSentenceBreaks() -> String {
        replacingOccurrences(
            of: #"(?<!\d)\.\s+(?=\S)"#,
            with: ".\n",
            options: .regularExpression
        )
    }
}
