import Foundation

public struct Thought: Identifiable, Codable, Sendable {
    public let id: String
    public let content: String
    public let createdAt: Date
    public let updatedAt: Date
    public let day: String
    public let source: String
    public let channel: String
    public let tags: [String]
    public let archived: Bool
    public let pinned: Bool

    public init(
        id: String = UUID().uuidString.lowercased(),
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        day: String? = nil,
        source: String = "human",
        channel: String = "gui",
        tags: [String] = [],
        archived: Bool = false,
        pinned: Bool = false
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.day = day ?? Self.makeDayString(from: createdAt)
        self.source = source
        self.channel = channel
        self.tags = tags
        self.archived = archived
        self.pinned = pinned
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
