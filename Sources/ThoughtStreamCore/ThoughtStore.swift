import Foundation
import SQLite3

public struct ThoughtQuery: Sendable {
    public var limit: Int?
    public var offset: Int?
    public var from: Date?
    public var to: Date?
    public var search: String?
    public var source: String?
    public var channel: String?
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
        source: String? = nil,
        channel: String? = nil,
        order: SortOrder = .ascending
    ) {
        self.limit = limit
        self.offset = offset
        self.from = from
        self.to = to
        self.search = search
        self.source = source
        self.channel = channel
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

public enum ThoughtStoreError: Error, LocalizedError {
    case openDatabase(String)
    case prepare(String)
    case step(String)
    case bind(String)

    public var errorDescription: String? {
        switch self {
        case .openDatabase(let message): return "Failed to open database: \(message)"
        case .prepare(let message): return "Failed to prepare SQLite statement: \(message)"
        case .step(let message): return "SQLite step failed: \(message)"
        case .bind(let message): return "SQLite bind failed: \(message)"
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
        createdAt: Date = Date()
    ) throws -> Thought {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Thought(content: "", createdAt: createdAt, source: source, channel: channel)
        }

        let thought = Thought(content: trimmed, createdAt: createdAt, source: source, channel: channel)
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let insertSQL = """
            INSERT INTO thoughts (id, content, created_at, day, source, channel)
            VALUES (?, ?, ?, ?, ?, ?);
            """
            let statement = try prepare(insertSQL)
            defer { sqlite3_finalize(statement) }

            try bind(text: thought.id, at: 1, in: statement)
            try bind(text: thought.content, at: 2, in: statement)
            try bind(text: isoFormatter.string(from: thought.createdAt), at: 3, in: statement)
            try bind(text: thought.day, at: 4, in: statement)
            try bind(text: thought.source, at: 5, in: statement)
            try bind(text: thought.channel, at: 6, in: statement)

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
        SELECT thoughts.id, thoughts.content, thoughts.created_at, thoughts.day, thoughts.source, thoughts.channel
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
        sql += " ORDER BY thoughts.created_at " + (query.order == .ascending ? "ASC" : "DESC")
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
                let dayRaw = sqlite3_column_text(statement, 3),
                let sourceRaw = sqlite3_column_text(statement, 4),
                let channelRaw = sqlite3_column_text(statement, 5)
            else {
                continue
            }

            let createdAtString = String(cString: createdAtRaw)
            let createdAt = isoFormatter.date(from: createdAtString) ?? Date.distantPast

            thoughts.append(
                Thought(
                    id: String(cString: idRaw),
                    content: String(cString: contentRaw),
                    createdAt: createdAt,
                    day: String(cString: dayRaw),
                    source: String(cString: sourceRaw),
                    channel: String(cString: channelRaw)
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
                day TEXT NOT NULL,
                source TEXT NOT NULL,
                channel TEXT NOT NULL
            );
            """
        )
        try execute("CREATE INDEX IF NOT EXISTS idx_thoughts_created_at ON thoughts(created_at);")
        try execute("CREATE INDEX IF NOT EXISTS idx_thoughts_day ON thoughts(day);")
        try execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS thoughts_fts
            USING fts5(content, tokenize='unicode61');
            """
        )
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

    private static func sqliteMessage(from db: OpaquePointer?) -> String {
        guard let db, let message = sqlite3_errmsg(db) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
