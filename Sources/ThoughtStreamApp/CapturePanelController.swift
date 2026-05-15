import AppKit
import ThoughtStreamCore

@MainActor
final class CapturePanelController: NSWindowController, NSWindowDelegate {
    private struct ResultSession {
        let command: ResultCommand
        var offset: Int
        var hasMore: Bool
    }

    private let store: ThoughtStore
    private let rootView = TransparentRootView(frame: NSRect(x: 0, y: 0, width: 760, height: 78))
    private let captureView = CaptureView(frame: NSRect(x: 0, y: 0, width: 760, height: 78))
    private weak var previousApp: NSRunningApplication?
    private let defaults = UserDefaults.standard
    private let originXKey = "capturePanel.origin.x"
    private let originYKey = "capturePanel.origin.y"
    private var persistentResultsVisible = false
    private var persistentEmptyStateText = "No notes yet"
    private var knownTags: [String] = []
    private var resultSession: ResultSession?
    private let resultPageSize = 100

    init(store: ThoughtStore) {
        self.store = store

        let panel = CapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 78),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        super.init(window: panel)

        rootView.addSubview(captureView)
        captureView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            captureView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            captureView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            captureView.topAnchor.constraint(equalTo: rootView.topAnchor),
            captureView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])

        panel.contentView = rootView
        panel.delegate = self

        captureView.onSubmit = { [weak self] text in
            self?.submit(text: text)
        }
        captureView.onTextChange = { [weak self] text in
            self?.handleTextChange(text)
        }
        captureView.onCancel = { [weak self] in
            self?.hidePanel()
        }
        captureView.onRequestMoreTailResults = { [weak self] in
            self?.loadMoreResults() ?? false
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isVisible: Bool {
        window?.isVisible == true
    }

    func toggle() {
        if isVisible {
            hidePanel()
        } else {
            show()
        }
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        guard let panel = window else { return }

        persistentResultsVisible = false
        resultSession = nil
        refreshKnownTags()
        captureView.reset()
        resizeWindowToMatchContent(panel, animate: false)
        positionPanel(panel)

        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(captureView.textView)
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow, panel === window else { return }
        let origin = panel.frame.origin
        defaults.set(origin.x, forKey: originXKey)
        defaults.set(origin.y, forKey: originYKey)
    }

    func windowDidResignKey(_ notification: Notification) {
        hidePanel()
    }

    private func submit(text: String) {
        var submittedText = text
        let trimmed = submittedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hidePanel()
            return
        }

        if let suggestion = autocompleteSuggestion(for: trimmed), suggestion != trimmed {
            captureView.applyAutocompleteSuggestionIfNeeded()
            if suggestion.hasPrefix("/") {
                executeSlashCommand(.exactCommand(suggestion))
                return
            }
            submittedText = suggestion
        }

        let normalized = submittedText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch parseSlashCommand(normalized) {
        case .handled(let command):
            executeSlashCommand(command)
            return
        case .invalid:
            NSSound.beep()
            return
        case .notCommand:
            break
        }

        do {
            _ = try store.addThought(content: normalized, source: "human", channel: "gui")
            refreshKnownTags()
            if persistentResultsVisible {
                refreshResultSession()
            }
            captureView.clearInput(keepResults: persistentResultsVisible)
            if let panel = window {
                resizeWindowToMatchContent(panel, animate: true)
                panel.makeFirstResponder(captureView.textView)
            }
        } catch {
            NSSound.beep()
        }
    }

    func hidePanel() {
        persistentResultsVisible = false
        resultSession = nil
        captureView.reset()
        window?.orderOut(nil)
        previousApp?.activate(options: [.activateIgnoringOtherApps])
    }

    private func positionPanel(_ panel: NSWindow) {
        if let restored = restoredOrigin(), isFrameVisible(panel.frame, at: restored) {
            panel.setFrameOrigin(restored)
            return
        }

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            let frame = panel.frame
            let origin = NSPoint(
                x: screen.frame.midX - frame.width / 2,
                y: screen.frame.midY - frame.height / 2
            )
            panel.setFrameOrigin(origin)
        }
    }

    private func restoredOrigin() -> NSPoint? {
        guard
            defaults.object(forKey: originXKey) != nil,
            defaults.object(forKey: originYKey) != nil
        else {
            return nil
        }
        return NSPoint(
            x: defaults.double(forKey: originXKey),
            y: defaults.double(forKey: originYKey)
        )
    }

    private func isFrameVisible(_ frame: NSRect, at origin: NSPoint) -> Bool {
        let candidate = NSRect(origin: origin, size: frame.size)
        return NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(candidate)
        }
    }

    private func handleTextChange(_ text: String) {
        captureView.setAutocompleteSuggestion(autocompleteSuggestion(for: text))

        guard captureView.isShowingResults else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !persistentResultsVisible, !trimmed.hasPrefix("/") {
            captureView.hideResults()
            if let panel = window {
                resizeWindowToMatchContent(panel, animate: true)
            }
        }
    }

    private func resizeWindowToMatchContent(_ panel: NSWindow, animate: Bool) {
        let currentFrame = panel.frame
        let targetHeight = captureView.preferredPanelHeight
        let heightDelta = targetHeight - currentFrame.height
        guard abs(heightDelta) > 0.5 else { return }

        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y - heightDelta,
            width: currentFrame.width,
            height: targetHeight
        )
        panel.setFrame(newFrame, display: true, animate: animate)
    }

    private func autocompleteSuggestion(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/"), !trimmed.contains(" ") {
            let availableCommands = ["/tail", "/search", "/today", "/tag", "/help", "/exit"]
            return availableCommands.first { command in
                command != trimmed && command.hasPrefix(trimmed)
            }
        }

        guard let match = text.range(of: #"(?:^|\s)#([^\s#{]+)$"#, options: .regularExpression) else {
            return nil
        }

        let token = String(text[match])
        guard let hashIndex = token.firstIndex(of: "#") else { return nil }
        let prefix = String(token[token.index(after: hashIndex)...])
        guard !prefix.isEmpty else { return nil }

        guard let tag = knownTags.first(where: {
            !$0.contains(" ") &&
            $0.caseInsensitiveCompare(prefix) != .orderedSame &&
            $0.lowercased().hasPrefix(prefix.lowercased())
        }) else {
            return nil
        }

        guard let absoluteHashIndex = text[match].firstIndex(of: "#") else { return nil }
        let rangeToReplace = text.index(after: absoluteHashIndex)..<match.upperBound
        var suggestion = text
        suggestion.replaceSubrange(rangeToReplace, with: tag)
        return suggestion
    }

    private func refreshKnownTags() {
        do {
            knownTags = try store.fetchTags(limit: 200)
        } catch {
            knownTags = []
        }
    }

    private func parseSlashCommand(_ text: String) -> SlashCommandParseResult {
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
            guard Self.isValidInlineTag(tag) else { return .invalid }
            return .handled(.tag(tag: tag))
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

    private func executeSlashCommand(_ command: SlashCommand) {
        switch command {
        case .tail(let limit):
            showResults(for: .tail(limit: limit))
            captureView.clearInput(keepResults: true)
        case .search(let query):
            showResults(for: .search(query: query))
            captureView.clearInput(keepResults: true)
        case .today:
            showResults(for: .today)
            captureView.clearInput(keepResults: true)
        case .tag(let tag):
            showResults(for: .tag(tag: tag))
            captureView.clearInput(keepResults: true)
        case .help:
            showResults(for: .help)
            captureView.clearInput(keepResults: true)
        case .exit:
            hidePanel()
        case .exactCommand(let exact):
            switch exact {
            case "/tail":
                executeSlashCommand(.tail(limit: nil))
            case "/search", "/tag":
                return
            case "/today":
                executeSlashCommand(.today)
            case "/help":
                executeSlashCommand(.help)
            case "/exit":
                executeSlashCommand(.exit)
            default:
                NSSound.beep()
            }
        }
    }

    private func showResults(for command: ResultCommand) {
        switch command {
        case .help:
            persistentResultsVisible = true
            persistentEmptyStateText = "No commands yet"
            resultSession = nil
            captureView.showResultRows(Self.helpRows, hasMore: false, emptyStateText: persistentEmptyStateText)
            if let panel = window {
                resizeWindowToMatchContent(panel, animate: true)
                panel.makeFirstResponder(captureView.textView)
            }
        default:
            showThoughtResults(for: command)
        }
    }

    private func showThoughtResults(for command: ResultCommand) {
        let thoughts: [Thought]
        do {
            thoughts = try store.fetchThoughts(query: makeThoughtQuery(for: command, offset: 0))
        } catch {
            NSSound.beep()
            return
        }

        let hasMore = hasMoreResults(for: command, fetchedCount: thoughts.count, offset: 0)
        resultSession = ResultSession(command: command, offset: thoughts.count, hasMore: hasMore)
        persistentResultsVisible = true
        persistentEmptyStateText = emptyStateText(for: command)
        captureView.showResultRows(makeRows(from: thoughts), hasMore: hasMore, emptyStateText: persistentEmptyStateText)
        if let panel = window {
            resizeWindowToMatchContent(panel, animate: true)
            panel.makeFirstResponder(captureView.textView)
        }
    }

    private func refreshResultSession() {
        guard let session = resultSession else { return }
        showResults(for: session.command)
    }

    private func loadMoreResults() -> Bool {
        guard var session = resultSession, session.hasMore else { return false }

        let thoughts: [Thought]
        do {
            thoughts = try store.fetchThoughts(query: makeThoughtQuery(for: session.command, offset: session.offset))
        } catch {
            NSSound.beep()
            return false
        }

        guard !thoughts.isEmpty else {
            session.hasMore = false
            resultSession = session
            return false
        }

        let currentOffset = session.offset
        session.offset += thoughts.count
        session.hasMore = hasMoreResults(for: session.command, fetchedCount: thoughts.count, offset: currentOffset)
        resultSession = session
        captureView.appendResultRows(
            makeRows(from: thoughts),
            hasMore: session.hasMore,
            emptyStateText: persistentEmptyStateText
        )
        return true
    }

    private func makeThoughtQuery(for command: ResultCommand, offset: Int) -> ThoughtQuery {
        let fetchLimit: Int
        switch command {
        case .tail(let limit):
            fetchLimit = min(resultPageSize, limit ?? resultPageSize)
        default:
            fetchLimit = resultPageSize
        }

        switch command {
        case .tail:
            return ThoughtQuery(
                limit: fetchLimit,
                offset: offset,
                source: "human",
                channel: "gui",
                order: .descending
            )
        case .search(let query):
            return ThoughtQuery(
                limit: fetchLimit,
                offset: offset,
                search: query,
                source: "human",
                channel: "gui",
                order: .descending
            )
        case .today:
            let start = Calendar.current.startOfDay(for: Date())
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
            return ThoughtQuery(
                limit: fetchLimit,
                offset: offset,
                from: start,
                to: end,
                source: "human",
                channel: "gui",
                order: .descending
            )
        case .tag(let tag):
            return ThoughtQuery(
                limit: fetchLimit,
                offset: offset,
                tag: tag,
                source: "human",
                channel: "gui",
                order: .descending
            )
        case .help:
            return ThoughtQuery()
        }
    }

    private func hasMoreResults(for command: ResultCommand, fetchedCount: Int, offset: Int) -> Bool {
        switch command {
        case .tail(let limit):
            let fetchLimit = min(resultPageSize, limit ?? resultPageSize)
            if let limit {
                return fetchedCount == fetchLimit && offset + fetchedCount < limit
            }
            return fetchedCount == fetchLimit
        case .search, .today, .tag:
            return fetchedCount == resultPageSize
        case .help:
            return false
        }
    }

    private func emptyStateText(for command: ResultCommand) -> String {
        switch command {
        case .tail:
            return "No notes yet"
        case .search:
            return "No matching notes"
        case .today:
            return "Nothing captured today"
        case .tag(let tag):
            return "No notes tagged #\(tag)"
        case .help:
            return "No commands yet"
        }
    }

    private func makeRows(from thoughts: [Thought]) -> [CaptureResultRow] {
        thoughts.map {
            CaptureResultRow(
                title: $0.content,
                detail: Self.resultMetaFormatter.string(from: $0.createdAt),
                highlightsTags: true
            )
        }
    }

    private static func isValidInlineTag(_ tag: String) -> Bool {
        guard !tag.isEmpty else { return false }
        return tag.range(of: #"^[\p{L}\p{N}_-]+$"#, options: .regularExpression) != nil
    }
}

private enum SlashCommandParseResult {
    case notCommand
    case invalid
    case handled(SlashCommand)
}

private enum SlashCommand {
    case tail(limit: Int?)
    case search(query: String)
    case today
    case tag(tag: String)
    case help
    case exit
    case exactCommand(String)
}

private enum ResultCommand {
    case tail(limit: Int?)
    case search(query: String)
    case today
    case tag(tag: String)
    case help
}

private extension CapturePanelController {
    static let resultMetaFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    static let helpRows: [CaptureResultRow] = [
        CaptureResultRow(title: "/tail", detail: "Recent notes", highlightsTags: false),
        CaptureResultRow(title: "/search <query>", detail: "Full-text search", highlightsTags: false),
        CaptureResultRow(title: "/today", detail: "Today's notes", highlightsTags: false),
        CaptureResultRow(title: "/tag <tag>", detail: "Browse by tag", highlightsTags: false),
        CaptureResultRow(title: "/help", detail: "Command list", highlightsTags: false),
        CaptureResultRow(title: "/exit", detail: "Close panel", highlightsTags: false)
    ]
}

@MainActor
final class CapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class TransparentRootView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }
}
