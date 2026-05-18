import Foundation
import SQLite3
import Testing
@testable import ThoughtStreamCore

struct ThoughtStoreQueryTests {
    @Test
    func configStorageRootOverridesDefaultLocation() throws {
        let configured = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: configured) }

        var config = ThoughtStreamConfig()
        config.storageRoot = configured.path
        try config.save()
        defer { try? FileManager.default.removeItem(at: ThoughtStreamConfig.configURL) }

        let resolved = try ThoughtStore.resolveBaseDirectory()
        #expect(resolved.standardizedFileURL == configured.standardizedFileURL)
    }

    @Test
    func explicitBaseDirectoryTakesPrecedenceOverConfigRoot() throws {
        let explicit = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let configured = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: explicit)
            try? FileManager.default.removeItem(at: configured)
        }

        var config = ThoughtStreamConfig()
        config.storageRoot = configured.path
        try config.save()
        defer { try? FileManager.default.removeItem(at: ThoughtStreamConfig.configURL) }

        let resolved = try ThoughtStore.resolveBaseDirectory(explicitBaseDirectory: explicit)
        #expect(resolved.standardizedFileURL == explicit.standardizedFileURL)
    }

    @Test
    func resolveBaseDirectoryDefaultsToApplicationSupport() throws {
        let resolved = try ThoughtStore.resolveBaseDirectory()
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("ThoughtStream", isDirectory: true)
        #expect(resolved.standardizedFileURL == appSupport.standardizedFileURL)
    }

    @Test
    func recentQueriesExcludeArchivedAndSortPinnedFirst() throws {
        let fixture = try StoreFixture()
        defer { fixture.cleanup() }

        let base = fixture.makeDate(year: 2026, month: 5, day: 16, hour: 9, minute: 0)
        _ = try fixture.store.addThought(content: "normal older", createdAt: base)
        _ = try fixture.store.addThought(content: "pinned newest", createdAt: base.addingTimeInterval(60), pinned: true)
        _ = try fixture.store.addThought(content: "archived newest", createdAt: base.addingTimeInterval(120), archived: true)

        let thoughts = try fixture.store.fetchThoughts(
            query: ThoughtQuery(
                limit: 10,
                archived: false,
                source: "human",
                channel: "gui",
                pinnedFirst: true,
                order: .descending
            )
        )

        #expect(thoughts.map(\.content) == ["pinned newest", "normal older"])
    }

    @Test
    func searchQueriesPageWithLimitAndOffset() throws {
        let fixture = try StoreFixture()
        defer { fixture.cleanup() }

        let base = fixture.makeDate(year: 2026, month: 5, day: 16, hour: 10, minute: 0)
        for index in 0..<5 {
            _ = try fixture.store.addThought(
                content: "search target \(index)",
                createdAt: base.addingTimeInterval(TimeInterval(index * 60))
            )
        }

        let firstPage = try fixture.store.fetchThoughts(
            query: ThoughtQuery(
                limit: 2,
                offset: 0,
                search: "search target",
                archived: false,
                source: "human",
                channel: "gui",
                order: .descending
            )
        )
        let secondPage = try fixture.store.fetchThoughts(
            query: ThoughtQuery(
                limit: 2,
                offset: 2,
                search: "search target",
                archived: false,
                source: "human",
                channel: "gui",
                order: .descending
            )
        )

        #expect(firstPage.map(\.content) == ["search target 4", "search target 3"])
        #expect(secondPage.map(\.content) == ["search target 2", "search target 1"])
    }

    @Test
    func searchSupportsPrefixMatchesWithinWords() throws {
        let fixture = try StoreFixture()
        defer { fixture.cleanup() }

        let base = fixture.makeDate(year: 2026, month: 5, day: 16, hour: 10, minute: 30)
        _ = try fixture.store.addThought(content: "important follow-up", createdAt: base)
        _ = try fixture.store.addThought(content: "import pipeline notes", createdAt: base.addingTimeInterval(60))
        _ = try fixture.store.addThought(content: "completely unrelated", createdAt: base.addingTimeInterval(120))

        let thoughts = try fixture.store.fetchThoughts(
            query: ThoughtQuery(
                search: "import",
                archived: false,
                source: "human",
                channel: "gui",
                order: .ascending
            )
        )

        #expect(thoughts.map(\.content) == ["important follow-up", "import pipeline notes"])
    }

    @Test
    func searchSupportsSubstringMatchesWithinWords() throws {
        let fixture = try StoreFixture()
        defer { fixture.cleanup() }

        let base = fixture.makeDate(year: 2026, month: 5, day: 16, hour: 10, minute: 45)
        _ = try fixture.store.addThought(content: "important follow-up", createdAt: base)
        _ = try fixture.store.addThought(content: "transport checklist", createdAt: base.addingTimeInterval(60))
        _ = try fixture.store.addThought(content: "completely unrelated", createdAt: base.addingTimeInterval(120))

        let thoughts = try fixture.store.fetchThoughts(
            query: ThoughtQuery(
                search: "port",
                archived: false,
                source: "human",
                channel: "gui",
                order: .ascending
            )
        )

        #expect(thoughts.map(\.content) == ["important follow-up", "transport checklist"])
    }

    @Test
    func openingLegacyStoreUpgradesSearchIndexTokenizer() throws {
        let fixture = try LegacyStoreFixture()
        defer { fixture.cleanup() }

        let store = try ThoughtStore(baseDirectory: fixture.root)
        let thoughts = try store.fetchThoughts(
            query: ThoughtQuery(
                search: "port",
                archived: false,
                source: "human",
                channel: "gui",
                order: .ascending
            )
        )

        #expect(thoughts.map(\.content) == ["important follow-up"])
    }

    @Test
    func savingNewThoughtRefreshesRecentOrder() throws {
        let fixture = try StoreFixture()
        defer { fixture.cleanup() }

        let base = fixture.makeDate(year: 2026, month: 5, day: 16, hour: 11, minute: 0)
        _ = try fixture.store.addThought(content: "first", createdAt: base)
        _ = try fixture.store.addThought(content: "second", createdAt: base.addingTimeInterval(60))

        let initial = try fixture.store.fetchRecentThoughts(limit: 5, source: "human", channel: "gui")
        #expect(initial.map(\.content) == ["second", "first"])

        _ = try fixture.store.addThought(content: "third", createdAt: base.addingTimeInterval(120))
        let refreshed = try fixture.store.fetchRecentThoughts(limit: 5, source: "human", channel: "gui")
        #expect(refreshed.map(\.content) == ["third", "second", "first"])
    }

    @Test
    func todayWindowMatchesOnlyCurrentDayEntries() throws {
        let fixture = try StoreFixture()
        defer { fixture.cleanup() }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let now = fixture.makeDate(year: 2026, month: 5, day: 16, hour: 14, minute: 0, timeZone: calendar.timeZone)
        let start = calendar.startOfDay(for: now)
        let previousDay = start.addingTimeInterval(-60)
        let sameDay = start.addingTimeInterval(3600)

        _ = try fixture.store.addThought(content: "yesterday", createdAt: previousDay)
        _ = try fixture.store.addThought(content: "today", createdAt: sameDay)

        let query = CaptureResultQueryBuilder.thoughtQuery(
            for: .today,
            offset: 0,
            pageSize: 50,
            now: now,
            calendar: calendar
        )
        let thoughts = try fixture.store.fetchThoughts(query: query)
        #expect(thoughts.map(\.content) == ["today"])
    }

    @Test
    func todayWindowExcludesNextMidnightBoundary() throws {
        let fixture = try StoreFixture()
        defer { fixture.cleanup() }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let now = fixture.makeDate(year: 2026, month: 5, day: 16, hour: 14, minute: 0, timeZone: calendar.timeZone)
        let start = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: start)!
        let sameDay = nextMidnight.addingTimeInterval(-60)

        _ = try fixture.store.addThought(content: "today late", createdAt: sameDay)
        _ = try fixture.store.addThought(content: "tomorrow midnight", createdAt: nextMidnight)

        let query = CaptureResultQueryBuilder.thoughtQuery(
            for: .today,
            offset: 0,
            pageSize: 50,
            now: now,
            calendar: calendar
        )
        let thoughts = try fixture.store.fetchThoughts(query: query)
        #expect(thoughts.map(\.content) == ["today late"])
    }

    @Test
    func upperBoundDateFilterIsExclusive() throws {
        let fixture = try StoreFixture()
        defer { fixture.cleanup() }

        let to = fixture.makeDate(year: 2026, month: 5, day: 17, hour: 0, minute: 0)
        _ = try fixture.store.addThought(content: "included", createdAt: to.addingTimeInterval(-1))
        _ = try fixture.store.addThought(content: "excluded", createdAt: to)

        let thoughts = try fixture.store.fetchThoughts(
            query: ThoughtQuery(
                to: to,
                source: "human",
                channel: "gui",
                order: .ascending
            )
        )

        #expect(thoughts.map(\.content) == ["included"])
    }

    @Test
    func daySummariesRespectArchivedAndTagFilters() throws {
        let fixture = try StoreFixture()
        defer { fixture.cleanup() }

        let dayOne = fixture.makeDate(year: 2026, month: 5, day: 15, hour: 9, minute: 0)
        let dayTwo = fixture.makeDate(year: 2026, month: 5, day: 16, hour: 9, minute: 0)

        _ = try fixture.store.addThought(content: "work active", createdAt: dayOne, tags: ["work"])
        _ = try fixture.store.addThought(content: "work archived", createdAt: dayOne.addingTimeInterval(60), tags: ["work"], archived: true)
        _ = try fixture.store.addThought(content: "personal archived", createdAt: dayTwo, tags: ["personal"], archived: true)

        let archivedWork = try fixture.store.fetchDaySummaries(
            query: ThoughtQuery(tag: "work", archived: true, order: .ascending)
        )
        let activeWork = try fixture.store.fetchDaySummaries(
            query: ThoughtQuery(tag: "work", archived: false, order: .ascending)
        )

        #expect(archivedWork.map(\.day) == ["2026-05-15"])
        #expect(archivedWork.map(\.count) == [1])
        #expect(activeWork.map(\.day) == ["2026-05-15"])
        #expect(activeWork.map(\.count) == [1])
    }

    @Test
    func addThoughtRejectsEmptyContent() throws {
        let fixture = try StoreFixture()
        defer { fixture.cleanup() }

        #expect(throws: ThoughtStoreError.self) {
            try fixture.store.addThought(content: "   ")
        }
    }

    @Test
    func migratingWithErrorPolicyRejectsExistingDestination() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanup() }

        #expect(throws: ThoughtStoreError.self) {
            try ThoughtStore.migrateStoreIfNeeded(
                from: fixture.sourceStore.databaseURL,
                to: fixture.destinationRoot,
                onConflict: .error
            )
        }
    }

    @Test
    func migratingWithOverwriteReplacesDestinationDatabase() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanup() }

        try ThoughtStore.migrateStoreIfNeeded(
            from: fixture.sourceStore.databaseURL,
            to: fixture.destinationRoot,
            onConflict: .overwrite
        )

        #expect(!FileManager.default.fileExists(atPath: fixture.sourceStore.databaseURL.path))

        let thoughts = try fixture.reopenDestinationStore().fetchThoughts(query: ThoughtQuery(order: .ascending))
        #expect(thoughts.map(\.content) == ["source only"])
    }

    @Test
    func migratingWithMergePreservesBothDatabasesContents() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanup() }

        try ThoughtStore.migrateStoreIfNeeded(
            from: fixture.sourceStore.databaseURL,
            to: fixture.destinationRoot,
            onConflict: .merge
        )

        #expect(!FileManager.default.fileExists(atPath: fixture.sourceStore.databaseURL.path))

        let thoughts = try fixture.reopenDestinationStore().fetchThoughts(query: ThoughtQuery(order: .ascending))
        #expect(thoughts.map(\.content) == ["source only", "destination only"])
    }

    @Test
    func migratingWithKeepDestinationPreservesTargetDatabase() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanup() }

        try ThoughtStore.migrateStoreIfNeeded(
            from: fixture.sourceStore.databaseURL,
            to: fixture.destinationRoot,
            onConflict: .keepDestination
        )

        #expect(FileManager.default.fileExists(atPath: fixture.destinationStore.databaseURL.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.sourceStore.databaseURL.path))

        let thoughts = try fixture.reopenDestinationStore().fetchThoughts(query: ThoughtQuery(order: .ascending))
        #expect(thoughts.map(\.content) == ["destination only"])
    }
}

private struct MigrationFixture {
    let sourceRoot: URL
    let destinationRoot: URL
    let sourceStore: ThoughtStore
    let destinationStore: ThoughtStore

    init() throws {
        sourceRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        destinationRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        sourceStore = try ThoughtStore(baseDirectory: sourceRoot)
        destinationStore = try ThoughtStore(baseDirectory: destinationRoot)
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try sourceStore.addThought(content: "source only", createdAt: baseDate)
        _ = try destinationStore.addThought(content: "destination only", createdAt: baseDate.addingTimeInterval(60))
    }

    func reopenDestinationStore() throws -> ThoughtStore {
        try ThoughtStore(baseDirectory: destinationRoot)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: sourceRoot)
        try? FileManager.default.removeItem(at: destinationRoot)
    }
}

private struct StoreFixture {
    let root: URL
    let store: ThoughtStore

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = try ThoughtStore(baseDirectory: root)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }

    func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}

private struct LegacyStoreFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let databaseURL = root.appendingPathComponent("thoughts.sqlite3", isDirectory: false)
        var db: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK, let db else {
            throw ThoughtStoreError.openDatabase("Failed to create legacy test database")
        }
        defer { sqlite3_close(db) }

        let statements = [
            """
            CREATE TABLE thoughts (
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
            """,
            """
            CREATE VIRTUAL TABLE thoughts_fts
            USING fts5(content, tokenize='unicode61');
            """,
            """
            INSERT INTO thoughts (
                id, content, created_at, updated_at, day, source, channel, tags_json, archived, pinned
            ) VALUES (
                'legacy-thought',
                'important follow-up',
                '2026-05-16T10:30:00Z',
                '2026-05-16T10:30:00Z',
                '2026-05-16',
                'human',
                'gui',
                '[]',
                0,
                0
            );
            """,
            "INSERT INTO thoughts_fts(rowid, content) VALUES (1, 'important follow-up');"
        ]

        for statement in statements {
            guard sqlite3_exec(db, statement, nil, nil, nil) == SQLITE_OK else {
                throw ThoughtStoreError.openDatabase(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
