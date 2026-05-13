import Foundation

public enum ThoughtOutput {
    private static func makeFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    public static func printThoughts(_ thoughts: [Thought], json: Bool) throws {
        let formatter = makeFormatter()
        if json {
            struct Payload: Codable {
                let items: [ThoughtPayload]
            }
            let payload = Payload(items: thoughts.map { ThoughtPayload($0, formatter: formatter) })
            let data = try JSONEncoder.pretty.encode(payload)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data([0x0A]))
            return
        }

        for thought in thoughts {
            let line = "\(formatter.string(from: thought.createdAt)) [\(thought.channel)] \(thought.content)"
            print(line)
        }
    }

    public static func printStats(_ stats: ThoughtStats, json: Bool) throws {
        let formatter = makeFormatter()
        if json {
            let payload = StatsPayload(
                totalCount: stats.totalCount,
                activeDays: stats.activeDays,
                firstEntryAt: stats.firstEntryAt.map { formatter.string(from: $0) },
                lastEntryAt: stats.lastEntryAt.map { formatter.string(from: $0) }
            )
            let data = try JSONEncoder.pretty.encode(payload)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data([0x0A]))
            return
        }

        print("total: \(stats.totalCount)")
        print("active_days: \(stats.activeDays)")
        print("first_entry_at: \(stats.firstEntryAt.map { formatter.string(from: $0) } ?? "-")")
        print("last_entry_at: \(stats.lastEntryAt.map { formatter.string(from: $0) } ?? "-")")
    }

    public static func printDaySummaries(_ summaries: [ThoughtDaySummary], json: Bool) throws {
        let formatter = makeFormatter()
        if json {
            let payload = DaySummaryListPayload(items: summaries.map {
                DaySummaryPayload(
                    day: $0.day,
                    count: $0.count,
                    firstEntryAt: $0.firstEntryAt.map { formatter.string(from: $0) },
                    lastEntryAt: $0.lastEntryAt.map { formatter.string(from: $0) }
                )
            })
            let data = try JSONEncoder.pretty.encode(payload)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data([0x0A]))
            return
        }

        for summary in summaries {
            print("\(summary.day) count=\(summary.count)")
        }
    }
}

private struct ThoughtPayload: Codable {
    let id: String
    let content: String
    let created_at: String
    let day: String
    let source: String
    let channel: String

    init(_ thought: Thought, formatter: ISO8601DateFormatter) {
        id = thought.id
        content = thought.content
        created_at = formatter.string(from: thought.createdAt)
        day = thought.day
        source = thought.source
        channel = thought.channel
    }
}

private struct StatsPayload: Codable {
    let totalCount: Int
    let activeDays: Int
    let firstEntryAt: String?
    let lastEntryAt: String?
}

private struct DaySummaryPayload: Codable {
    let day: String
    let count: Int
    let firstEntryAt: String?
    let lastEntryAt: String?
}

private struct DaySummaryListPayload: Codable {
    let items: [DaySummaryPayload]
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
