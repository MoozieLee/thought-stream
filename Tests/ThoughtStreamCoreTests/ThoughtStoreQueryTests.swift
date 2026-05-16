import Foundation
import Testing
@testable import ThoughtStreamCore

struct ThoughtStoreQueryTests {
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
