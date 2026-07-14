import Foundation

enum HeadlineFormatter {
    static func casual(_ rawTitle: String, maxLength: Int = 52) -> String {
        let normalized = normalizeWhitespace(in: rawTitle)
        let withoutSource = removeSourceSuffix(from: normalized)
        let softened = softenTone(in: withoutSource)
        let cleaned = removeTrailingPunctuation(from: softened)

        guard !cleaned.isEmpty else { return "Quick news update" }
        return clamp(cleaned, maxLength: maxLength)
    }

    private static func normalizeWhitespace(in text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeSourceSuffix(from title: String) -> String {
        for separator in [" - ", " | ", " — "] {
            if let range = title.range(of: separator) {
                return String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return title
    }

    private static func softenTone(in title: String) -> String {
        var updated = title

        let replacements: [(String, String)] = [
            ("(?i)\\braises\\b", "just raised"),
            ("(?i)\\bannounces\\b", "just announced"),
            ("(?i)\\blaunches\\b", "just launched"),
            ("(?i)\\bacquires\\b", "just bought"),
            ("(?i)\\bto expand\\b", "to grow"),
            ("(?i)\\binfrastructure\\b", "tech"),
            ("(?i)\\baccording to\\b", "per"),
            ("(?i)\\bamid\\b", "as"),
            ("(?i)\\breports\\b", "says"),
            ("(?i)\\bseries\\s+[A-Z]\\b", "funding round")
        ]

        for (pattern, replacement) in replacements {
            updated = updated.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }

        return normalizeWhitespace(in: updated)
    }

    private static func removeTrailingPunctuation(from text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = trimmed.last, [".", "!", "?", ":", ";"].contains(String(last)) {
            trimmed.removeLast()
        }
        return trimmed
    }

    private static func clamp(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }

        let limitIndex = text.index(text.startIndex, offsetBy: maxLength)
        var prefix = String(text[..<limitIndex])

        if let lastSpace = prefix.lastIndex(of: " "), prefix.distance(from: prefix.startIndex, to: lastSpace) >= 38 {
            prefix = String(prefix[..<lastSpace])
        }

        return prefix.trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
