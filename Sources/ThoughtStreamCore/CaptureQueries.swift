import Foundation

public enum CaptureSlashCommand: Equatable, Sendable {
    case tail(limit: Int?)
    case search(query: String)
    case today
    case tag(tag: String)
    case archive
    case hide
    case help
    case exit
    case exactCommand(String)
}

public enum CaptureSlashCommandParseResult: Equatable, Sendable {
    case notCommand
    case invalid
    case handled(CaptureSlashCommand)
}

public enum CaptureResultCommand: Equatable, Sendable {
    case tail(limit: Int?)
    case search(query: String)
    case today
    case tag(tag: String)
    case archive
    case help
}

public enum CaptureSlashCommandParser {
    public static let availableCommands = ["/tail", "/search", "/today", "/tag", "/archive", "/hide", "/help", "/exit"]

    public static func autocompleteSuggestion(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/"), !trimmed.contains(" ") else { return nil }
        return availableCommands.first { command in
            command != trimmed && command.hasPrefix(trimmed)
        }
    }

    public static func parse(_ text: String) -> CaptureSlashCommandParseResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else {
            return .notCommand
        }

        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let command = parts.first else {
            return .notCommand
        }

        switch command {
        case "/exit":
            return parts.count == 1 ? .handled(.exit) : .invalid
        case "/help":
            return parts.count == 1 ? .handled(.help) : .invalid
        case "/today":
            return parts.count == 1 ? .handled(.today) : .invalid
        case "/search":
            let query = parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return query.isEmpty ? .invalid : .handled(.search(query: query))
        case "/tag":
            guard parts.count == 2 else { return .invalid }
            let tag = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidInlineTag(tag) else { return .invalid }
            return .handled(.tag(tag: tag))
        case "/archive":
            return parts.count == 1 ? .handled(.archive) : .invalid
        case "/hide":
            return parts.count == 1 ? .handled(.hide) : .invalid
        case "/tail":
            if parts.count == 1 {
                return .handled(.tail(limit: nil))
            }
            guard parts.count == 2 else { return .invalid }

            let argument = parts[1]
            if let limit = Int(argument), limit > 0 {
                return .handled(.tail(limit: limit))
            }

            let prefix = "limit:"
            if argument.hasPrefix(prefix) {
                let raw = String(argument.dropFirst(prefix.count))
                if let limit = Int(raw), limit > 0 {
                    return .handled(.tail(limit: limit))
                }
            }
            return .invalid
        default:
            return .notCommand
        }
    }

    public static func inlineErrorMessage(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }

        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let command = parts.first else { return nil }

        switch command {
        case "/tail":
            if parts.count <= 1 { return nil }
            if parts.count > 2 { return "Use /tail, /tail 20, or /tail limit:20" }
            let argument = parts[1]
            if Int(argument).map({ $0 > 0 }) == true { return nil }
            if argument.hasPrefix("limit:") {
                let raw = String(argument.dropFirst("limit:".count))
                return Int(raw).map({ $0 > 0 }) == true ? nil : "Tail limit must be a positive number"
            }
            return "Use /tail, /tail 20, or /tail limit:20"
        case "/search":
            return parts.count > 1 ? nil : "Search needs a query"
        case "/today":
            return parts.count == 1 ? nil : "Use /today without extra text"
        case "/tag":
            guard parts.count > 1 else { return "Tag needs a single token like /tag work" }
            guard parts.count == 2 else { return "Tag accepts one token like /tag work" }
            return isValidInlineTag(parts[1]) ? nil : "Tags must be a single token like work or code-review"
        case "/archive":
            return parts.count == 1 ? nil : "Use /archive without extra text"
        case "/hide":
            return parts.count == 1 ? nil : "Use /hide without extra text"
        case "/help":
            return parts.count == 1 ? nil : "Use /help without extra text"
        case "/exit":
            return parts.count == 1 ? nil : "Use /exit without extra text"
        default:
            return "Unknown command"
        }
    }

    public static func isValidInlineTag(_ tag: String) -> Bool {
        guard !tag.isEmpty else { return false }
        return tag.range(of: #"^[\p{L}\p{N}_-]+$"#, options: .regularExpression) != nil
    }
}

public enum CaptureResultQueryBuilder {
    public static func thoughtQuery(
        for command: CaptureResultCommand,
        offset: Int,
        pageSize: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ThoughtQuery {
        let fetchLimit: Int
        switch command {
        case .tail(let limit):
            fetchLimit = min(pageSize, limit ?? pageSize)
        default:
            fetchLimit = pageSize
        }

        switch command {
        case .tail:
            return ThoughtQueryPresets.recent(
                limit: fetchLimit,
                offset: offset,
                archived: false,
                source: "human",
                channel: "gui",
                pinnedFirst: true,
                order: .descending
            )
        case .search(let query):
            return ThoughtQueryPresets.search(
                query,
                limit: fetchLimit,
                offset: offset,
                archived: false,
                source: "human",
                channel: "gui",
                pinnedFirst: true,
                order: .descending
            )
        case .today:
            return ThoughtQueryPresets.today(
                limit: fetchLimit,
                offset: offset,
                archived: false,
                source: "human",
                channel: "gui",
                pinnedFirst: true,
                order: .descending,
                now: now,
                calendar: calendar
            )
        case .tag(let tag):
            return ThoughtQueryPresets.tag(
                tag,
                limit: fetchLimit,
                offset: offset,
                archived: false,
                source: "human",
                channel: "gui",
                pinnedFirst: true,
                order: .descending
            )
        case .archive:
            return ThoughtQueryPresets.archived(
                limit: fetchLimit,
                offset: offset,
                source: "human",
                channel: "gui",
                pinnedFirst: true,
                order: .descending
            )
        case .help:
            return ThoughtQuery()
        }
    }

    public static func hasMoreResults(
        for command: CaptureResultCommand,
        fetchedCount: Int,
        offset: Int,
        pageSize: Int
    ) -> Bool {
        switch command {
        case .tail(let limit):
            let fetchLimit = min(pageSize, limit ?? pageSize)
            if let limit {
                return fetchedCount == fetchLimit && offset + fetchedCount < limit
            }
            return fetchedCount == fetchLimit
        case .search, .today, .tag, .archive:
            return fetchedCount == pageSize
        case .help:
            return false
        }
    }

    public static func emptyStateText(for command: CaptureResultCommand) -> String {
        switch command {
        case .tail:
            return "No notes yet"
        case .search(let query):
            return "No matching notes for \"\(query)\""
        case .today:
            return "Nothing captured today"
        case .tag(let tag):
            return "No notes tagged #\(tag)"
        case .archive:
            return "No archived notes"
        case .help:
            return "No commands yet"
        }
    }

    public static func headerText(for command: CaptureResultCommand) -> String {
        switch command {
        case .tail(let limit):
            if let limit {
                return "Recent notes · \(limit)"
            }
            return "Recent notes"
        case .search(let query):
            return "Search: \(query)"
        case .today:
            return "Today"
        case .tag(let tag):
            return "Tag: #\(tag)"
        case .archive:
            return "Archived notes"
        case .help:
            return "Commands"
        }
    }

    public static func contextualHeaderText(
        for command: CaptureResultCommand,
        loadedCount: Int,
        hasMore: Bool
    ) -> String {
        let base = headerText(for: command)
        guard command != .help else { return base }
        guard loadedCount > 0 else { return base }

        let countText: String
        if hasMore {
            countText = "\(loadedCount)+"
        } else if loadedCount == 1 {
            countText = "1 note"
        } else {
            countText = "\(loadedCount) notes"
        }

        return "\(base) · \(countText)"
    }
}

public enum ThoughtQueryPresets {
    public static func recent(
        limit: Int? = nil,
        offset: Int? = nil,
        from: Date? = nil,
        to: Date? = nil,
        archived: Bool? = nil,
        source: String? = nil,
        channel: String? = nil,
        pinnedFirst: Bool = false,
        order: ThoughtQuery.SortOrder = .descending
    ) -> ThoughtQuery {
        ThoughtQuery(
            limit: limit,
            offset: offset,
            from: from,
            to: to,
            archived: archived,
            source: source,
            channel: channel,
            pinnedFirst: pinnedFirst,
            order: order
        )
    }

    public static func search(
        _ query: String,
        limit: Int? = nil,
        offset: Int? = nil,
        from: Date? = nil,
        to: Date? = nil,
        archived: Bool? = nil,
        source: String? = nil,
        channel: String? = nil,
        pinnedFirst: Bool = false,
        order: ThoughtQuery.SortOrder = .descending
    ) -> ThoughtQuery {
        ThoughtQuery(
            limit: limit,
            offset: offset,
            from: from,
            to: to,
            search: query,
            archived: archived,
            source: source,
            channel: channel,
            pinnedFirst: pinnedFirst,
            order: order
        )
    }

    public static func today(
        limit: Int? = nil,
        offset: Int? = nil,
        archived: Bool? = nil,
        source: String? = nil,
        channel: String? = nil,
        pinnedFirst: Bool = false,
        order: ThoughtQuery.SortOrder = .descending,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ThoughtQuery {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return ThoughtQuery(
            limit: limit,
            offset: offset,
            from: start,
            to: end,
            archived: archived,
            source: source,
            channel: channel,
            pinnedFirst: pinnedFirst,
            order: order
        )
    }

    public static func tag(
        _ tag: String,
        limit: Int? = nil,
        offset: Int? = nil,
        from: Date? = nil,
        to: Date? = nil,
        archived: Bool? = nil,
        source: String? = nil,
        channel: String? = nil,
        pinnedFirst: Bool = false,
        order: ThoughtQuery.SortOrder = .descending
    ) -> ThoughtQuery {
        ThoughtQuery(
            limit: limit,
            offset: offset,
            from: from,
            to: to,
            tag: tag,
            archived: archived,
            source: source,
            channel: channel,
            pinnedFirst: pinnedFirst,
            order: order
        )
    }

    public static func archived(
        limit: Int? = nil,
        offset: Int? = nil,
        from: Date? = nil,
        to: Date? = nil,
        source: String? = nil,
        channel: String? = nil,
        pinnedFirst: Bool = false,
        order: ThoughtQuery.SortOrder = .descending
    ) -> ThoughtQuery {
        ThoughtQuery(
            limit: limit,
            offset: offset,
            from: from,
            to: to,
            archived: true,
            source: source,
            channel: channel,
            pinnedFirst: pinnedFirst,
            order: order
        )
    }
}
