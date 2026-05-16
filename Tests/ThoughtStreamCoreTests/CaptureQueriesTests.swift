import Foundation
import Testing
@testable import ThoughtStreamCore

struct CaptureQueriesTests {
    @Test
    func parsesSlashCommandsAndHide() {
        #expect(CaptureSlashCommandParser.parse("/tail") == .handled(.tail(limit: nil)))
        #expect(CaptureSlashCommandParser.parse("/tail 20") == .handled(.tail(limit: 20)))
        #expect(CaptureSlashCommandParser.parse("/tail limit:20") == .handled(.tail(limit: 20)))
        #expect(CaptureSlashCommandParser.parse("/search onboarding") == .handled(.search(query: "onboarding")))
        #expect(CaptureSlashCommandParser.parse("/tag thoughtstream") == .handled(.tag(tag: "thoughtstream")))
        #expect(CaptureSlashCommandParser.parse("/keys") == .handled(.keys))
        #expect(CaptureSlashCommandParser.parse("/hide") == .handled(.hide))
    }

    @Test
    func slashValidationReturnsHelpfulErrors() {
        #expect(CaptureSlashCommandParser.inlineErrorMessage(for: "/search") == "Search needs a query")
        #expect(CaptureSlashCommandParser.inlineErrorMessage(for: "/tag code review") == "Tag accepts one token like /tag work")
        #expect(CaptureSlashCommandParser.inlineErrorMessage(for: "/tail limit:nope") == "Tail limit must be a positive number")
        #expect(CaptureSlashCommandParser.inlineErrorMessage(for: "/keys more") == "Use /keys without extra text")
        #expect(CaptureSlashCommandParser.inlineErrorMessage(for: "/wat") == "Unknown command")
    }

    @Test
    func slashAutocompleteIncludesHide() {
        #expect(CaptureSlashCommandParser.autocompleteSuggestion(for: "/ke") == "/keys")
        #expect(CaptureSlashCommandParser.autocompleteSuggestion(for: "/hi") == "/hide")
        #expect(CaptureSlashCommandParser.autocompleteSuggestion(for: "/hide") == nil)
    }

    @Test
    func todayQueryUsesInjectedCalendarWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 16, hour: 14, minute: 30))!

        let query = CaptureResultQueryBuilder.thoughtQuery(
            for: .today,
            offset: 0,
            pageSize: 100,
            now: now,
            calendar: calendar
        )

        let expectedStart = calendar.startOfDay(for: now)
        let expectedEnd = calendar.date(byAdding: .day, value: 1, to: expectedStart)
        #expect(query.from == expectedStart)
        #expect(query.to == expectedEnd)
        #expect(query.archived == false)
        #expect(query.pinnedFirst == true)
    }

    @Test
    func tailPaginationRespectsLimitAndPageSize() {
        #expect(
            CaptureResultQueryBuilder.hasMoreResults(
                for: .tail(limit: nil),
                fetchedCount: 100,
                offset: 0,
                pageSize: 100
            )
        )
        #expect(
            !CaptureResultQueryBuilder.hasMoreResults(
                for: .tail(limit: 20),
                fetchedCount: 20,
                offset: 0,
                pageSize: 100
            )
        )
        #expect(
            CaptureResultQueryBuilder.headerText(for: .tail(limit: 20)) == "Recent notes · 20"
        )
    }

    @Test
    func sharedRecentPresetCarriesScopeAndTimeFilters() {
        let from = Date(timeIntervalSince1970: 100)
        let to = Date(timeIntervalSince1970: 200)
        let query = ThoughtQueryPresets.recent(
            limit: 25,
            offset: 50,
            from: from,
            to: to,
            archived: false,
            source: "human",
            channel: "cli"
        )

        #expect(query.limit == 25)
        #expect(query.offset == 50)
        #expect(query.from == from)
        #expect(query.to == to)
        #expect(query.archived == false)
        #expect(query.source == "human")
        #expect(query.channel == "cli")
        #expect(query.order == .descending)
    }

    @Test
    func sharedTagAndArchivePresetsRemainConsistent() {
        let tagQuery = ThoughtQueryPresets.tag("thoughtstream", limit: 10, source: "human", channel: "gui")
        let archiveQuery = ThoughtQueryPresets.archived(limit: 10, source: "human", channel: "gui")

        #expect(tagQuery.tag == "thoughtstream")
        #expect(tagQuery.archived == nil)
        #expect(archiveQuery.archived == true)
        #expect(archiveQuery.source == "human")
        #expect(archiveQuery.channel == "gui")
    }

    @Test
    func emptyStateCarriesSearchAndTagContext() {
        #expect(CaptureResultQueryBuilder.emptyStateText(for: .search(query: "onboarding")) == #"No matching notes for "onboarding""#)
        #expect(CaptureResultQueryBuilder.emptyStateText(for: .tag(tag: "work")) == "No notes tagged #work")
    }

    @Test
    func contextualHeaderShowsLoadedCounts() {
        #expect(
            CaptureResultQueryBuilder.contextualHeaderText(for: .tail(limit: nil), loadedCount: 6, hasMore: true)
                == "Recent notes · 6+"
        )
        #expect(
            CaptureResultQueryBuilder.contextualHeaderText(for: .search(query: "onboarding"), loadedCount: 1, hasMore: false)
                == "Search: onboarding · 1 note"
        )
        #expect(CaptureResultQueryBuilder.headerText(for: .keys) == "Keyboard shortcuts")
    }
}
