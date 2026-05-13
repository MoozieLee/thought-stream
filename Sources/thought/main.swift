import Foundation
import ThoughtStreamCore
import Darwin

enum CLIError: Error, LocalizedError {
    case usage(String)

    var errorDescription: String? {
        switch self {
        case .usage(let message): return message
        }
    }
}

struct CLI {
    let store = ThoughtStore.shared

    func run(arguments: [String]) throws {
        guard let command = arguments.first else {
            throw CLIError.usage(Self.help)
        }

        switch command {
        case "list":
            try list(args: Array(arguments.dropFirst()))
        case "tail":
            try tail(args: Array(arguments.dropFirst()))
        case "search":
            try search(args: Array(arguments.dropFirst()))
        case "export":
            try export(args: Array(arguments.dropFirst()))
        case "stats":
            try stats(args: Array(arguments.dropFirst()))
        case "days":
            try days(args: Array(arguments.dropFirst()))
        case "add":
            try add(args: Array(arguments.dropFirst()))
        case "help", "--help", "-h":
            print(Self.help)
        default:
            throw CLIError.usage("Unknown command: \(command)\n\n\(Self.help)")
        }
    }

    private func list(args: [String]) throws {
        let options = QueryOptions(args: args)
        let thoughts = try store.fetchThoughts(query: options.makeQuery(defaultOrder: .ascending))
        try ThoughtOutput.printThoughts(thoughts, json: options.json)
    }

    private func tail(args: [String]) throws {
        var options = QueryOptions(args: args)
        if options.limit == nil {
            options.limit = 50
        }
        let thoughts = try store.fetchRecentThoughts(
            limit: options.limit ?? 50,
            source: options.source,
            channel: options.channel
        )
        let ordered = thoughts.sorted(by: { $0.createdAt < $1.createdAt })
        try ThoughtOutput.printThoughts(ordered, json: options.json)
    }

    private func search(args: [String]) throws {
        var options = QueryOptions(args: args)
        if options.search == nil {
            guard !options.remaining.isEmpty else {
                throw CLIError.usage("`thought search <query>` requires a search term.")
            }
            options.search = options.remaining.joined(separator: " ")
        }
        let thoughts = try store.fetchThoughts(query: options.makeQuery(defaultOrder: .descending))
        let ordered = thoughts.sorted(by: { $0.createdAt < $1.createdAt })
        try ThoughtOutput.printThoughts(ordered, json: options.json)
    }

    private func export(args: [String]) throws {
        var options = QueryOptions(args: args)
        options.json = true
        let thoughts = try store.fetchThoughts(query: options.makeQuery(defaultOrder: .ascending))
        try ThoughtOutput.printThoughts(thoughts, json: true)
    }

    private func stats(args: [String]) throws {
        let json = args.contains("--json")
        let stats = try store.fetchStats()
        try ThoughtOutput.printStats(stats, json: json)
    }

    private func days(args: [String]) throws {
        var options = QueryOptions(args: args)
        if options.limit == nil {
            options.limit = 30
        }
        let summaries = try store.fetchDaySummaries(query: options.makeQuery(defaultOrder: .descending))
        try ThoughtOutput.printDaySummaries(summaries, json: options.json)
    }

    private func add(args: [String]) throws {
        let source = value(after: "--source", in: args) ?? "human"
        let channel = value(after: "--channel", in: args) ?? "cli"

        let text: String
        if let stdinText = try readStandardInputIfAvailable(), !stdinText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = stdinText
        } else {
            text = positionalArguments(in: args).joined(separator: " ")
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CLIError.usage("`thought add` needs text from args or stdin.")
        }

        _ = try store.addThought(content: text, source: source, channel: channel)
    }

    private func readStandardInputIfAvailable() throws -> String? {
        if isatty(STDIN_FILENO) != 0 {
            return nil
        }
        let handle = FileHandle.standardInput
        let data = try handle.readToEnd() ?? Data()
        if data.isEmpty {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else {
            return nil
        }
        return args[index + 1]
    }

    private func positionalArguments(in args: [String]) -> [String] {
        var values: [String] = []
        var index = 0
        while index < args.count {
            let arg = args[index]
            if arg == "--source" || arg == "--channel" {
                index += 2
                continue
            }
            if arg.hasPrefix("--") {
                index += 1
                continue
            }
            values.append(arg)
            index += 1
        }
        return values
    }

    static let help = """
    thought commands:
      thought list [--limit N] [--offset N] [--from DATE] [--to DATE] [--source SOURCE] [--channel CHANNEL] [--desc] [--json]
      thought tail [N] [--source SOURCE] [--channel CHANNEL] [--json]
      thought search <query> [--limit N] [--offset N] [--from DATE] [--to DATE] [--source SOURCE] [--channel CHANNEL] [--json]
      thought export [--limit N] [--offset N] [--from DATE] [--to DATE] [--source SOURCE] [--channel CHANNEL]
      thought stats [--json]
      thought days [--limit N] [--offset N] [--from DATE] [--to DATE] [--source SOURCE] [--channel CHANNEL] [--json]
      thought add <text> [--source SOURCE] [--channel CHANNEL]

    date formats:
      2026-05-12
      2026-05-12 09:30
      2026-05-12T09:30:00+08:00
      7d / 24h / 30m
    """
}

struct QueryOptions {
    var json = false
    var limit: Int?
    var offset: Int?
    var from: Date?
    var to: Date?
    var search: String?
    var source: String?
    var channel: String?
    var descending = false
    var remaining: [String] = []

    init(args: [String]) {
        var index = 0
        while index < args.count {
            let arg = args[index]
            switch arg {
            case "--json":
                json = true
            case "--limit":
                if args.indices.contains(index + 1), let parsed = Int(args[index + 1]) {
                    limit = parsed
                    index += 1
                }
            case "--offset":
                if args.indices.contains(index + 1), let parsed = Int(args[index + 1]) {
                    offset = parsed
                    index += 1
                }
            case "--from":
                if args.indices.contains(index + 1) {
                    from = ThoughtDateParser.parse(args[index + 1])
                    index += 1
                }
            case "--to":
                if args.indices.contains(index + 1) {
                    to = ThoughtDateParser.parse(args[index + 1])
                    index += 1
                }
            case "--source":
                if args.indices.contains(index + 1) {
                    source = args[index + 1]
                    index += 1
                }
            case "--channel":
                if args.indices.contains(index + 1) {
                    channel = args[index + 1]
                    index += 1
                }
            case "--desc":
                descending = true
            default:
                if !arg.hasPrefix("--"), limit == nil, let parsed = Int(arg) {
                    limit = parsed
                } else {
                    remaining.append(arg)
                }
            }
            index += 1
        }
    }

    func makeQuery(defaultOrder: ThoughtQuery.SortOrder) -> ThoughtQuery {
        ThoughtQuery(
            limit: limit,
            offset: offset,
            from: from,
            to: to,
            search: search,
            source: source,
            channel: channel,
            order: descending ? .descending : defaultOrder
        )
    }
}

do {
    try CLI().run(arguments: Array(CommandLine.arguments.dropFirst()))
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
