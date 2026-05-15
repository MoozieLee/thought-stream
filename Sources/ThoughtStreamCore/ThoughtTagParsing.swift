import Foundation

enum ThoughtTagParser {
    static func extract(from content: String) -> [String] {
        let nsContent = content as NSString
        let fullRange = NSRange(location: 0, length: nsContent.length)
        guard let tokenRegex = try? NSRegularExpression(pattern: #"(?:(?<=^)|(?<=\s))#([\p{L}\p{N}_-]+)"#) else {
            return []
        }

        let tags = tokenRegex.matches(in: content, range: fullRange).compactMap { match -> String? in
            guard match.numberOfRanges > 1 else { return nil }
            let candidate = nsContent.substring(with: match.range(at: 1))
            return isValidTag(candidate) ? candidate : nil
        }
        return deduplicated(tags)
    }

    static func merge(_ lhs: [String], _ rhs: [String]) -> [String] {
        deduplicated(lhs + rhs)
    }

    static func normalizeExplicitTags(_ tags: [String]) -> [String] {
        tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    static func invalidTags(in tags: [String]) -> [String] {
        normalizeExplicitTags(tags).filter { !isValidTag($0) }
    }

    private static func isValidTag(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar) ||
            CharacterSet.letters.contains(scalar) ||
            scalar == "_" ||
            scalar == "-"
        }
    }

    private static func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            ordered.append(value)
        }
        return ordered
    }
}
