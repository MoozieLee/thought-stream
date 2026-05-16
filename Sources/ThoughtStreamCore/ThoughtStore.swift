import Foundation
import SQLite3

public struct ThoughtQuery: Sendable {
    public var limit: Int?
    public var offset: Int?
    public var from: Date?
    public var to: Date?
    public var search: String?
    public var tag: String?
    public var archived: Bool?
    public var source: String?
    public var channel: String?
    public var pinnedFirst: Bool
    public var order: SortOrder

    public enum SortOrder: Sendable {
        case ascending
        case descending
    }

    public init(
        limit: Int? = nil,
        offset: Int? = nil,
        from: Date? = nil,
        to: Date? = nil,
        search: String? = nil,
        tag: String? = nil,
        archived: Bool? = nil,
        source: String? = nil,
        channel: String? = nil,
        pinnedFirst: Bool = false,
        order: SortOrder = .ascending
    ) {
        self.limit = limit
        self.offset = offset
        self.from = from
        self.to = to
        self.search = search
        self.tag = tag
        self.archived = archived
        self.source = source
        self.channel = channel
        self.pinnedFirst = pinnedFirst
        self.order = order
    }
}

public struct ThoughtStats: Codable, Sendable {
    public let totalCount: Int
    public let firstEntryAt: Date?
    public let lastEntryAt: Date?
    public let activeDays: Int
}

public struct ThoughtDaySummary: Codable, Sendable {
    public let day: String
    public let count: Int
    public let firstEntryAt: Date?
    public let lastEntryAt: Date?
}

public struct ThoughtUpdate: Sendable {
    public var content: String?
    public var tags: [String]?
    public var archived: Bool?
    public var pinned: Bool?

    public init(
        content: String? = nil,
        tags: [String]? = nil,
        archived: Bool? = nil,
        pinned: Bool? = nil
    ) {
        self.content = content
        self.tags = tags
        self.archived = archived
        self.pinned = pinned
    }
}

public enum ThoughtStoreError: Error, LocalizedError {
    case openDatabase(String)
    case prepare(String)
    case step(String)
    case bind(String)
    case notFound(String)
    case invalidTag(String)
    case invalidUpdate(String)

    public var errorDescription: String? {
        switch self {
        case .openDatabase(let message): return "Failed to open database: \(message)"
        case .prepare(let message): return "Failed to prepare SQLite statement: \(message)"
        case .step(let message): return "SQLite step failed: \(message)"
        case .bind(let message): return "SQLite bind failed: \(message)"
        case .notFound(let message): return message
        case .invalidTag(let message): return message
        case .invalidUpdate(let message): return message
        }
    }
}

public final class ThoughtStore: @unchecked Sendable {
    public static let shared = try! ThoughtStore()

    public let databaseURL: URL
    private let db: OpaquePointer
    private let isoFormatter = ISO8601DateFormatter()

    public init(baseDirectory: URL? = nil) throws {
        let root = try Self.prepareBaseDirectory(baseDirectory)
        self.databaseURL = root.appendingPathComponent("thoughts.sqlite3", isDirectory: false)

        var database: OpaquePointer?
        if sqlite3_open(databaseURL.path, &database) != SQLITE_OK {
            throw ThoughtStoreError.openDatabase(Self.sqliteMessage(from: database))
        }
        guard let database else {
            throw ThoughtStoreError.openDatabase("Unknown SQLite error")
        }

        self.db = database
        sqlite3_busy_timeout(database, 2_000)
        self.isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try configure()
    }

    deinit {
        sqlite3_close(db)
    }

    public func addThought(
        content: String,
        source: String = "human",
        channel: String = "gui",
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        tags: [String] = [],
        archived: Bool = false,
        pinned: Bool = false
    ) throws -> Thought {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitTags = try validateExplicitTags(tags)
        let mergedTags = ThoughtTagParser.merge(explicitTags, ThoughtTagParser.extract(from: trimmed))

        guard !trimmed.isEmpty else {
            return Thought(
                content: "",
                createdAt: createdAt,
                updatedAt: updatedAt,
                source: source,
                channel: channel,
                tags: mergedTags,
                archived: archived,
                pinned: pinned
            )
        }

        let thought = Thought(
            content: trimmed,
            createdAt: createdAt,
            updatedAt: updatedAt,
            source: source,
            channel: channel,
            tags: mergedTags,
            archived: archived,
            pinned: pinned
        )
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let insertSQL = """
            INSERT INTO thoughts (id, content, created_at, updated_at, day, source, channel, tags_json, archived, pinned)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            let statement = try prepare(insertSQL)
            defer { sqlite3_finalize(statement) }

            try bind(text: thought.id, at: 1, in: statement)
            try bind(text: thought.content, at: 2, in: statement)
            try bind(text: isoFormatter.string(from: thought.createdAt), at: 3, in: statement)
            try bind(text: isoFormatter.string(from: thought.updatedAt), at: 4, in: statement)
            try bind(text: thought.day, at: 5, in: statement)
            try bind(text: thought.source, at: 6, in: statement)
            try bind(text: thought.channel, at: 7, in: statement)
            try bind(text: Self.tagsJSONString(from: thought.tags), at: 8, in: statement)
            sqlite3_bind_int(statement, 9, thought.archived ? 1 : 0)
            sqlite3_bind_int(statement, 10, thought.pinned ? 1 : 0)

            try stepUntilDone(statement)

            try execute(
                "INSERT INTO thoughts_fts(rowid, content) VALUES (last_insert_rowid(), ?);",
                bindings: [thought.content]
            )
            try execute("COMMIT;")
            return thought
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    public func fetchThoughts(query: ThoughtQuery = ThoughtQuery()) throws -> [Thought] {
        var sql = """
        SELECT thoughts.id, thoughts.content, thoughts.created_at, thoughts.updated_at, thoughts.day, thoughts.source, thoughts.channel, thoughts.tags_json, thoughts.archived, thoughts.pinned
        FROM thoughts
        """
        var predicates: [String] = []
        var bindings: [String] = []

        if let search = query.search?.trimmingCharacters(in: .whitespacesAndNewlines), !search.isEmpty {
            sql += " JOIN thoughts_fts ON thoughts_fts.rowid = thoughts.rowid "
            predicates.append("thoughts_fts MATCH ?")
            bindings.append(ftsEscaped(search))
        }
        if let tag = query.tag?.trimmingCharacters(in: .whitespacesAndNewlines), !tag.isEmpty {
            predicates.append("EXISTS (SELECT 1 FROM json_each(thoughts.tags_json) WHERE json_each.value = ?)")
            bindings.append(tag)
        }
        if let archived = query.archived {
            predicates.append("thoughts.archived = ?")
            bindings.append(archived ? "1" : "0")
        }
        if let from = query.from {
            predicates.append("thoughts.created_at >= ?")
            bindings.append(isoFormatter.string(from: from))
        }
        if let to = query.to {
            predicates.append("thoughts.created_at <= ?")
            bindings.append(isoFormatter.string(from: to))
        }
        if let source = query.source?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty {
            predicates.append("thoughts.source = ?")
            bindings.append(source)
        }
        if let channel = query.channel?.trimmingCharacters(in: .whitespacesAndNewlines), !channel.isEmpty {
            predicates.append("thoughts.channel = ?")
            bindings.append(channel)
        }
        if !predicates.isEmpty {
            sql += " WHERE " + predicates.joined(separator: " AND ")
        }
        if query.pinnedFirst {
            sql += " ORDER BY thoughts.pinned DESC, thoughts.created_at " + (query.order == .ascending ? "ASC" : "DESC")
        } else {
            sql += " ORDER BY thoughts.created_at " + (query.order == .ascending ? "ASC" : "DESC")
        }
        if let limit = query.limit {
            sql += " LIMIT \(max(0, limit))"
        }
        if let offset = query.offset, offset > 0 {
            if query.limit == nil {
                sql += " LIMIT -1"
            }
            sql += " OFFSET \(offset)"
        }
        sql += ";"

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        for (index, binding) in bindings.enumerated() {
            try bind(text: binding, at: Int32(index + 1), in: statement)
        }

        var thoughts: [Thought] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idRaw = sqlite3_column_text(statement, 0),
                let contentRaw = sqlite3_column_text(statement, 1),
                let createdAtRaw = sqlite3_column_text(statement, 2),
                let updatedAtRaw = sqlite3_column_text(statement, 3),
                let dayRaw = sqlite3_column_text(statement, 4),
                let sourceRaw = sqlite3_column_text(statement, 5),
                let channelRaw = sqlite3_column_text(statement, 6)
            else {
                continue
            }

            let createdAtString = String(cString: createdAtRaw)
            let createdAt = isoFormatter.date(from: createdAtString) ?? Date.distantPast
            let updatedAtString = String(cString: updatedAtRaw)
            let updatedAt = isoFormatter.date(from: updatedAtString) ?? createdAt
            let tags = sqlite3_column_text(statement, 7).map { Self.tags(from: String(cString: $0)) } ?? []
            let archived = sqlite3_column_int(statement, 8) != 0
            let pinned = sqlite3_column_int(statement, 9) != 0

            thoughts.append(
                Thought(
                    id: String(cString: idRaw),
                    content: String(cString: contentRaw),
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    day: String(cString: dayRaw),
                    source: String(cString: sourceRaw),
                    channel: String(cString: channelRaw),
                    tags: tags,
                    archived: archived,
                    pinned: pinned
                )
            )
        }
        return thoughts
    }

    public func fetchRecentThoughts(
        limit: Int = 50,
        source: String? = nil,
        channel: String? = nil
    ) throws -> [Thought] {
        try fetchThoughts(
            query: ThoughtQuery(
                limit: limit,
                source: source,
                channel: channel,
                order: .descending
            )
        )
    }

    public func fetchTags(prefix: String? = nil, limit: Int = 50) throws -> [String] {
        let statement = try prepare("SELECT tags_json FROM thoughts WHERE tags_json != '[]';")
        defer { sqlite3_finalize(statement) }

        var counts: [String: Int] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let tagsRaw = sqlite3_column_text(statement, 0) else { continue }
            for tag in Self.tags(from: String(cString: tagsRaw)) {
                counts[tag, default: 0] += 1
            }
        }

        let normalizedPrefix = prefix?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return counts.keys
            .filter { tag in
                guard let normalizedPrefix, !normalizedPrefix.isEmpty else { return true }
                return tag.lowercased().hasPrefix(normalizedPrefix)
            }
            .sorted {
                let lhsCount = counts[$0, default: 0]
                let rhsCount = counts[$1, default: 0]
                if lhsCount == rhsCount {
                    return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
                }
                return lhsCount > rhsCount
            }
            .prefix(max(0, limit))
            .map(\.self)
    }

    @discardableResult
    public func updateThought(
        id: String,
        update: ThoughtUpdate,
        updatedAt: Date = Date()
    ) throws -> Thought {
        let existing = try fetchThought(id: id)

        let nextContent: String
        let inlineTags: [String]
        if let content = update.content {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw ThoughtStoreError.invalidUpdate("Thought content cannot be empty.")
            }
            nextContent = trimmed
            inlineTags = ThoughtTagParser.extract(from: trimmed)
        } else {
            nextContent = existing.content
            inlineTags = []
        }

        let baseTags: [String]
        if let explicitTags = update.tags {
            baseTags = try validateExplicitTags(explicitTags)
        } else {
            baseTags = existing.tags
        }
        let nextTags = ThoughtTagParser.merge(baseTags, inlineTags)
        let nextArchived = update.archived ?? existing.archived
        let nextPinned = update.pinned ?? existing.pinned

        let hasChanges =
            nextContent != existing.content ||
            nextTags != existing.tags ||
            nextArchived != existing.archived ||
            nextPinned != existing.pinned

        guard hasChanges else {
            return existing
        }

        let nextThought = Thought(
            id: existing.id,
            content: nextContent,
            createdAt: existing.createdAt,
            updatedAt: updatedAt,
            day: existing.day,
            source: existing.source,
            channel: existing.channel,
            tags: nextTags,
            archived: nextArchived,
            pinned: nextPinned
        )

        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let updateSQL = """
            UPDATE thoughts
            SET content = ?, updated_at = ?, tags_json = ?, archived = ?, pinned = ?
            WHERE id = ?;
            """
            let statement = try prepare(updateSQL)
            defer { sqlite3_finalize(statement) }

            try bind(text: nextThought.content, at: 1, in: statement)
            try bind(text: isoFormatter.string(from: nextThought.updatedAt), at: 2, in: statement)
            try bind(text: Self.tagsJSONString(from: nextThought.tags), at: 3, in: statement)
            sqlite3_bind_int(statement, 4, nextThought.archived ? 1 : 0)
            sqlite3_bind_int(statement, 5, nextThought.pinned ? 1 : 0)
            try bind(text: nextThought.id, at: 6, in: statement)

            try stepUntilDone(statement)

            try execute(
                """
                UPDATE thoughts_fts
                SET content = ?
                WHERE rowid = (SELECT rowid FROM thoughts WHERE id = ?);
                """,
                bindings: [nextThought.content, nextThought.id]
            )
            try execute("COMMIT;")
            return nextThought
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    public func fetchThought(id: String) throws -> Thought {
        let sql = """
        SELECT thoughts.id, thoughts.content, thoughts.created_at, thoughts.updated_at, thoughts.day, thoughts.source, thoughts.channel, thoughts.tags_json, thoughts.archived, thoughts.pinned
        FROM thoughts
        WHERE thoughts.id = ?
        LIMIT 1;
        """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(text: id, at: 1, in: statement)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let idRaw = sqlite3_column_text(statement, 0),
              let contentRaw = sqlite3_column_text(statement, 1),
              let createdAtRaw = sqlite3_column_text(statement, 2),
              let updatedAtRaw = sqlite3_column_text(statement, 3),
              let dayRaw = sqlite3_column_text(statement, 4),
              let sourceRaw = sqlite3_column_text(statement, 5),
              let channelRaw = sqlite3_column_text(statement, 6) else {
            throw ThoughtStoreError.notFound("Thought not found: \(id)")
        }

        let createdAt = isoFormatter.date(from: String(cString: createdAtRaw)) ?? Date.distantPast
        let updatedAt = isoFormatter.date(from: String(cString: updatedAtRaw)) ?? createdAt
        let tags = sqlite3_column_text(statement, 7).map { Self.tags(from: String(cString: $0)) } ?? []
        let archived = sqlite3_column_int(statement, 8) != 0
        let pinned = sqlite3_column_int(statement, 9) != 0

        return Thought(
            id: String(cString: idRaw),
            content: String(cString: contentRaw),
            createdAt: createdAt,
            updatedAt: updatedAt,
            day: String(cString: dayRaw),
            source: String(cString: sourceRaw),
            channel: String(cString: channelRaw),
            tags: tags,
            archived: archived,
            pinned: pinned
        )
    }

    @discardableResult
    public func deleteThought(id: String) throws -> Thought {
        let existing = try fetchThought(id: id)

        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try execute("DELETE FROM thoughts_fts WHERE rowid = (SELECT rowid FROM thoughts WHERE id = ?);", bindings: [id])
            try execute("DELETE FROM thoughts WHERE id = ?;", bindings: [id])
            try execute("COMMIT;")
            return existing
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    public func fetchStats() throws -> ThoughtStats {
        let sql = """
        SELECT COUNT(*), MIN(created_at), MAX(created_at), COUNT(DISTINCT day)
        FROM thoughts;
        """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw ThoughtStoreError.step(Self.sqliteMessage(from: db))
        }

        let total = Int(sqlite3_column_int(statement, 0))
        let first = sqlite3_column_text(statement, 1).flatMap { isoFormatter.date(from: String(cString: $0)) }
        let last = sqlite3_column_text(statement, 2).flatMap { isoFormatter.date(from: String(cString: $0)) }
        let activeDays = Int(sqlite3_column_int(statement, 3))

        return ThoughtStats(totalCount: total, firstEntryAt: first, lastEntryAt: last, activeDays: activeDays)
    }

    public func fetchDaySummaries(query: ThoughtQuery = ThoughtQuery()) throws -> [ThoughtDaySummary] {
        var sql = """
        SELECT thoughts.day, COUNT(*), MIN(thoughts.created_at), MAX(thoughts.created_at)
        FROM thoughts
        """
        var predicates: [String] = []
        var bindings: [String] = []

        if let search = query.search?.trimmingCharacters(in: .whitespacesAndNewlines), !search.isEmpty {
            sql += " JOIN thoughts_fts ON thoughts_fts.rowid = thoughts.rowid "
            predicates.append("thoughts_fts MATCH ?")
            bindings.append(ftsEscaped(search))
        }
        if let from = query.from {
            predicates.append("thoughts.created_at >= ?")
            bindings.append(isoFormatter.string(from: from))
        }
        if let to = query.to {
            predicates.append("thoughts.created_at <= ?")
            bindings.append(isoFormatter.string(from: to))
        }
        if let source = query.source?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty {
            predicates.append("thoughts.source = ?")
            bindings.append(source)
        }
        if let channel = query.channel?.trimmingCharacters(in: .whitespacesAndNewlines), !channel.isEmpty {
            predicates.append("thoughts.channel = ?")
            bindings.append(channel)
        }
        if !predicates.isEmpty {
            sql += " WHERE " + predicates.joined(separator: " AND ")
        }
        sql += " GROUP BY thoughts.day"
        sql += " ORDER BY thoughts.day " + (query.order == .ascending ? "ASC" : "DESC")
        if let limit = query.limit {
            sql += " LIMIT \(max(0, limit))"
        }
        if let offset = query.offset, offset > 0 {
            if query.limit == nil {
                sql += " LIMIT -1"
            }
            sql += " OFFSET \(offset)"
        }
        sql += ";"

        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        for (index, binding) in bindings.enumerated() {
            try bind(text: binding, at: Int32(index + 1), in: statement)
        }

        var summaries: [ThoughtDaySummary] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let dayRaw = sqlite3_column_text(statement, 0) else {
                continue
            }
            let first = sqlite3_column_text(statement, 2).flatMap { isoFormatter.date(from: String(cString: $0)) }
            let last = sqlite3_column_text(statement, 3).flatMap { isoFormatter.date(from: String(cString: $0)) }
            summaries.append(
                ThoughtDaySummary(
                    day: String(cString: dayRaw),
                    count: Int(sqlite3_column_int(statement, 1)),
                    firstEntryAt: first,
                    lastEntryAt: last
                )
            )
        }
        return summaries
    }

    private func configure() throws {
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA synchronous = NORMAL;")
        try execute("PRAGMA busy_timeout = 2000;")
        try execute(
            """
            CREATE TABLE IF NOT EXISTS thoughts (
                rowid INTEGER PRIMARY KEY AUTOINCREMENT,
                id TEXT NOT NULL UNIQUE,
                content TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                day TEXT NOT NULL,
                source TEXT NOT NULL,
                channel TEXT NOT NULL,
                tags_json TEXT NOT NULL DEFAULT '[]',
                archived INTEGER NOT NULL DEFAULT 0,
                pinned INTEGER NOT NULL DEFAULT 0
            );
            """
        )
        try migrateSchemaIfNeeded()
        try execute("CREATE INDEX IF NOT EXISTS idx_thoughts_created_at ON thoughts(created_at);")
        try execute("CREATE INDEX IF NOT EXISTS idx_thoughts_updated_at ON thoughts(updated_at);")
        try execute("CREATE INDEX IF NOT EXISTS idx_thoughts_day ON thoughts(day);")
        try execute("CREATE INDEX IF NOT EXISTS idx_thoughts_archived ON thoughts(archived);")
        try execute("CREATE INDEX IF NOT EXISTS idx_thoughts_pinned ON thoughts(pinned);")
        try execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS thoughts_fts
            USING fts5(content, tokenize='unicode61');
            """
        )
    }

    private func migrateSchemaIfNeeded() throws {
        let columns = try fetchThoughtColumnNames()
        if !columns.contains("updated_at") {
            try execute("ALTER TABLE thoughts ADD COLUMN updated_at TEXT;")
            try execute("UPDATE thoughts SET updated_at = created_at WHERE updated_at IS NULL OR updated_at = '';")
        }
        if !columns.contains("tags_json") {
            try execute("ALTER TABLE thoughts ADD COLUMN tags_json TEXT NOT NULL DEFAULT '[]';")
        }
        if !columns.contains("archived") {
            try execute("ALTER TABLE thoughts ADD COLUMN archived INTEGER NOT NULL DEFAULT 0;")
        }
        if !columns.contains("pinned") {
            try execute("ALTER TABLE thoughts ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0;")
        }
    }

    private func fetchThoughtColumnNames() throws -> Set<String> {
        let statement = try prepare("PRAGMA table_info(thoughts);")
        defer { sqlite3_finalize(statement) }

        var columns = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let nameRaw = sqlite3_column_text(statement, 1) else { continue }
            columns.insert(String(cString: nameRaw))
        }
        return columns
    }

    private func validateExplicitTags(_ tags: [String]) throws -> [String] {
        let normalized = ThoughtTagParser.normalizeExplicitTags(tags)
        let invalidTags = ThoughtTagParser.invalidTags(in: normalized)
        guard invalidTags.isEmpty else {
            throw ThoughtStoreError.invalidTag(
                "Tags cannot contain spaces or special phrase syntax. Use single-token tags like `#code-review`."
            )
        }
        return normalized
    }

    private static func prepareBaseDirectory(_ input: URL?) throws -> URL {
        if let input {
            try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
            return input
        }

        let environment = ProcessInfo.processInfo.environment
        if let override = environment["THOUGHT_STREAM_HOME"], !override.isEmpty {
            let directory = URL(fileURLWithPath: override, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }

        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = appSupport.appendingPathComponent("ThoughtStream", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            let fallback = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
                .appendingPathComponent(".thought-stream", isDirectory: true)
            try FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
            return fallback
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw ThoughtStoreError.prepare(Self.sqliteMessage(from: db))
        }
        return statement
    }

    private func execute(_ sql: String, bindings: [String] = []) throws {
        for attempt in 0..<5 {
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }
            for (index, binding) in bindings.enumerated() {
                try bind(text: binding, at: Int32(index + 1), in: statement)
            }
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE || result == SQLITE_ROW {
                return
            }
            if (result == SQLITE_BUSY || result == SQLITE_LOCKED), attempt < 4 {
                sqlite3_reset(statement)
                Thread.sleep(forTimeInterval: 0.1 * Double(attempt + 1))
                continue
            }
            throw ThoughtStoreError.step(Self.sqliteMessage(from: db))
        }
        throw ThoughtStoreError.step(Self.sqliteMessage(from: db))
    }

    private func bind(text: String, at index: Int32, in statement: OpaquePointer?) throws {
        if sqlite3_bind_text(statement, index, text, -1, SQLITE_TRANSIENT) != SQLITE_OK {
            throw ThoughtStoreError.bind(Self.sqliteMessage(from: db))
        }
    }

    private func stepUntilDone(_ statement: OpaquePointer?) throws {
        for attempt in 0..<5 {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE || result == SQLITE_ROW {
                return
            }
            if (result == SQLITE_BUSY || result == SQLITE_LOCKED), attempt < 4 {
                sqlite3_reset(statement)
                Thread.sleep(forTimeInterval: 0.1 * Double(attempt + 1))
                continue
            }
            throw ThoughtStoreError.step(Self.sqliteMessage(from: db))
        }
        throw ThoughtStoreError.step(Self.sqliteMessage(from: db))
    }

    private func ftsEscaped(_ search: String) -> String {
        let collapsed = search
            .split(whereSeparator: \.isWhitespace)
            .map { token in "\"\(token.replacing("\"", with: "\"\""))\"" }
            .joined(separator: " ")
        return collapsed.isEmpty ? search : collapsed
    }

    private static func tagsJSONString(from tags: [String]) -> String {
        guard
            let data = try? JSONEncoder().encode(tags),
            let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return string
    }

    private static func tags(from json: String) -> [String] {
        guard
            let data = json.data(using: .utf8),
            let tags = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return tags
    }

    private static func sqliteMessage(from db: OpaquePointer?) -> String {
        guard let db, let message = sqlite3_errmsg(db) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
