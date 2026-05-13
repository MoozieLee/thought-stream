import Foundation

public struct Thought: Identifiable, Codable, Sendable {
    public let id: String
    public let content: String
    public let createdAt: Date
    public let day: String
    public let source: String
    public let channel: String

    public init(
        id: String = UUID().uuidString.lowercased(),
        content: String,
        createdAt: Date = Date(),
        day: String? = nil,
        source: String = "human",
        channel: String = "gui"
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.day = day ?? Self.makeDayString(from: createdAt)
        self.source = source
        self.channel = channel
    }

    private static func makeDayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
