import Foundation

public enum ThoughtDateParser {
    public static func parse(_ raw: String) -> Date? {
        if let relative = parseRelative(raw) {
            return relative
        }

        for formatter in makeFormatters() {
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        return nil
    }

    private static func parseRelative(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 2 else { return nil }

        let suffix = trimmed.last!
        let magnitudeRaw = String(trimmed.dropLast())
        guard let magnitude = Int(magnitudeRaw) else { return nil }

        let seconds: TimeInterval
        switch suffix {
        case "m": seconds = Double(magnitude) * 60
        case "h": seconds = Double(magnitude) * 3600
        case "d": seconds = Double(magnitude) * 86400
        case "w": seconds = Double(magnitude) * 604800
        default: return nil
        }
        return Date().addingTimeInterval(-seconds)
    }

    private static func makeFormatters() -> [DateFormatter] {
        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ]
        return patterns.map {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = $0
            return formatter
        }
    }
}
