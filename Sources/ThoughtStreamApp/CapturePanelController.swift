import AppKit
import ThoughtStreamCore

@MainActor
final class CapturePanelController: NSWindowController, NSWindowDelegate {
    private struct ResultSession {
        let command: CaptureResultCommand
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
    private let relativeOriginXKey = "capturePanel.relativeOrigin.x"
    private let relativeOriginYKey = "capturePanel.relativeOrigin.y"
    private var persistentResultsVisible = false
    private var persistentEmptyStateText = "No notes yet"
    private var knownTags: [String] = []
    private var resultSession: ResultSession?
    private let resultPageSize = 100
    private var inputHistory: [String] = []
    private var inputHistoryIndex: Int?
    private var inputHistoryDraftSnapshot: String?
    private var isApplyingInputHistoryNavigation = false
    private var editingThoughtID: String?

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
            guard let self else { return }
            if self.cancelEditingMode() {
                return
            }
            self.hidePanel()
        }
        captureView.onRequestMoreTailResults = { [weak self] in
            self?.loadMoreResults() ?? false
        }
        captureView.onSelectedResultAction = { [weak self] row in
            self?.handleSelectedResultAction(row)
        }
        captureView.onSelectedResultPinToggle = { [weak self] row in
            self?.togglePin(for: row)
        }
        captureView.onSelectedResultArchiveToggle = { [weak self] row in
            self?.toggleArchive(for: row)
        }
        captureView.onSelectedResultCopy = { [weak self] row in
            self?.copyResult(row)
        }
        captureView.onSelectedResultEdit = { [weak self] row in
            self?.beginEditing(row)
        }
        captureView.onRequestTailFromKeyboard = { [weak self] in
            self?.showTailFromKeyboard() ?? false
        }
        captureView.onCollapseResults = { [weak self] in
            self?.collapseResults()
        }
        captureView.onInputHistoryPrevious = { [weak self] in
            self?.showPreviousInputHistoryEntry() ?? false
        }
        captureView.onInputHistoryNext = { [weak self] in
            self?.showNextInputHistoryEntry() ?? false
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
        resetInputHistoryNavigation()
        refreshInputHistory()
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
        if let screen = screenForCurrentFocus() ?? panel.screen {
            let relativeOrigin = relativeOrigin(for: panel.frame, in: screen.visibleFrame)
            defaults.set(relativeOrigin.x, forKey: relativeOriginXKey)
            defaults.set(relativeOrigin.y, forKey: relativeOriginYKey)
        }
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
        if let errorMessage = inlineErrorMessage(for: normalized) {
            captureView.setInlineError(errorMessage)
        }
        switch parseSlashCommand(normalized) {
        case .handled(let command):
            captureView.setInlineError(nil)
            executeSlashCommand(command)
            return
        case .invalid:
            captureView.setInlineError(inlineErrorMessage(for: normalized) ?? "Invalid command")
            NSSound.beep()
            return
        case .notCommand:
            captureView.setInlineError(nil)
            break
        }

        do {
            if let editingThoughtID {
                _ = try store.updateThought(
                    id: editingThoughtID,
                    update: ThoughtUpdate(content: normalized)
                )
                endEditingMode()
            } else {
                _ = try store.addThought(content: normalized, source: "human", channel: "gui")
                recordInputHistoryEntry(normalized)
            }
            refreshInputHistory()
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
        resetInputHistoryNavigation()
        endEditingMode()
        captureView.reset()
        window?.orderOut(nil)
        previousApp?.activate(options: [.activateIgnoringOtherApps])
    }

    private func collapseResults() {
        persistentResultsVisible = false
        resultSession = nil
        captureView.hideResults()
        if let panel = window {
            resizeWindowToMatchContent(panel, animate: true)
            panel.makeFirstResponder(captureView.textView)
        }
    }

    private func positionPanel(_ panel: NSWindow) {
        let targetScreen = screenForCurrentFocus() ?? NSScreen.main
        if let targetScreen {
            if let restored = restoredOrigin(for: panel.frame, targetScreen: targetScreen), isFrameVisible(panel.frame, at: restored) {
                panel.setFrameOrigin(restored)
                return
            }

            let frame = panel.frame
            let origin = NSPoint(
                x: targetScreen.frame.midX - frame.width / 2,
                y: targetScreen.frame.midY - frame.height / 2
            )
            panel.setFrameOrigin(origin)
        }
    }

    private func restoredOrigin(for frame: NSRect, targetScreen: NSScreen) -> NSPoint? {
        if let relativeOrigin = restoredRelativeOrigin() {
            return absoluteOrigin(from: relativeOrigin, frame: frame, in: targetScreen.visibleFrame)
        }

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

    private func restoredRelativeOrigin() -> NSPoint? {
        guard
            defaults.object(forKey: relativeOriginXKey) != nil,
            defaults.object(forKey: relativeOriginYKey) != nil
        else {
            return nil
        }
        return NSPoint(
            x: defaults.double(forKey: relativeOriginXKey),
            y: defaults.double(forKey: relativeOriginYKey)
        )
    }

    private func screenForCurrentFocus() -> NSScreen? {
        NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
    }

    private func relativeOrigin(for frame: NSRect, in visibleFrame: NSRect) -> NSPoint {
        let availableWidth = max(1, visibleFrame.width - frame.width)
        let availableHeight = max(1, visibleFrame.height - frame.height)
        let relativeX = (frame.origin.x - visibleFrame.minX) / availableWidth
        let relativeY = (frame.origin.y - visibleFrame.minY) / availableHeight
        return NSPoint(
            x: min(max(relativeX, 0), 1),
            y: min(max(relativeY, 0), 1)
        )
    }

    private func absoluteOrigin(from relativeOrigin: NSPoint, frame: NSRect, in visibleFrame: NSRect) -> NSPoint {
        let availableWidth = max(0, visibleFrame.width - frame.width)
        let availableHeight = max(0, visibleFrame.height - frame.height)
        let proposed = NSPoint(
            x: visibleFrame.minX + min(max(relativeOrigin.x, 0), 1) * availableWidth,
            y: visibleFrame.minY + min(max(relativeOrigin.y, 0), 1) * availableHeight
        )
        return clampedOrigin(for: proposed, frame: frame, in: visibleFrame)
    }

    private func clampedOrigin(for origin: NSPoint, frame: NSRect, in visibleFrame: NSRect) -> NSPoint {
        let minX = visibleFrame.minX
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - frame.width)
        let minY = visibleFrame.minY
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - frame.height)
        return NSPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }

    private func isFrameVisible(_ frame: NSRect, at origin: NSPoint) -> Bool {
        let candidate = NSRect(origin: origin, size: frame.size)
        return NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(candidate)
        }
    }

    private func handleTextChange(_ text: String) {
        if isApplyingInputHistoryNavigation {
            isApplyingInputHistoryNavigation = false
        } else {
            resetInputHistoryNavigation(keepingDraftSnapshot: false)
        }
        captureView.setAutocompleteSuggestion(autocompleteSuggestion(for: text))
        captureView.setInlineError(inlineErrorMessage(for: text))

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
        if let suggestion = CaptureSlashCommandParser.autocompleteSuggestion(for: text) {
            return suggestion
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

    private func parseSlashCommand(_ text: String) -> CaptureSlashCommandParseResult {
        CaptureSlashCommandParser.parse(text)
    }

    private func inlineErrorMessage(for text: String) -> String? {
        CaptureSlashCommandParser.inlineErrorMessage(for: text)
    }

    private func executeSlashCommand(_ command: CaptureSlashCommand) {
        endEditingMode()
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
        case .archive:
            showResults(for: .archive)
            captureView.clearInput(keepResults: true)
        case .hide:
            captureView.clearInput(keepResults: false)
            collapseResults()
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
            case "/archive":
                executeSlashCommand(.archive)
            case "/hide":
                executeSlashCommand(.hide)
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

    private func showTailFromKeyboard() -> Bool {
        guard !captureView.isShowingResults else { return false }
        guard captureView.textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        captureView.setInlineError(nil)
        showResults(for: .tail(limit: nil), focusedSurface: .results)
        if let panel = window {
            resizeWindowToMatchContent(panel, animate: true)
            panel.makeFirstResponder(captureView.textView)
        }
        return true
    }

    private func showPreviousInputHistoryEntry() -> Bool {
        guard !captureView.textView.hasMarkedText() else { return false }
        guard !inputHistory.isEmpty else { return false }
        guard captureView.textView.window?.firstResponder === captureView.textView else { return false }
        guard captureView.isInputSurfaceFocused else { return false }

        let draft = captureView.textView.string
        if inputHistoryIndex == nil {
            inputHistoryDraftSnapshot = draft
            inputHistoryIndex = inputHistory.count - 1
        } else if let currentIndex = inputHistoryIndex, currentIndex > 0 {
            inputHistoryIndex = currentIndex - 1
        }

        guard let historyIndex = inputHistoryIndex, inputHistory.indices.contains(historyIndex) else {
            return false
        }

        applyInputHistoryDraft(inputHistory[historyIndex])
        return true
    }

    private func showNextInputHistoryEntry() -> Bool {
        guard !captureView.textView.hasMarkedText() else { return false }
        guard captureView.textView.window?.firstResponder === captureView.textView else { return false }
        guard captureView.isInputSurfaceFocused else { return false }
        guard let currentIndex = inputHistoryIndex else { return false }

        let nextIndex = currentIndex + 1
        if inputHistory.indices.contains(nextIndex) {
            inputHistoryIndex = nextIndex
            applyInputHistoryDraft(inputHistory[nextIndex])
            return true
        }

        let draft = inputHistoryDraftSnapshot ?? ""
        resetInputHistoryNavigation(keepingDraftSnapshot: false)
        applyInputHistoryDraft(draft)
        return true
    }

    private func applyInputHistoryDraft(_ text: String) {
        isApplyingInputHistoryNavigation = true
        captureView.populateDraft(text, hideResults: false)
        if let panel = window {
            resizeWindowToMatchContent(panel, animate: true)
            panel.makeFirstResponder(captureView.textView)
        }
    }

    private func recordInputHistoryEntry(_ text: String) {
        guard !text.isEmpty else { return }
        if inputHistory.last != text {
            inputHistory.append(text)
            if inputHistory.count > 200 {
                inputHistory.removeFirst(inputHistory.count - 200)
            }
        }
        resetInputHistoryNavigation(keepingDraftSnapshot: false)
    }

    private func refreshInputHistory() {
        do {
            let query = ThoughtQueryPresets.recent(
                limit: 200,
                archived: false,
                source: "human",
                channel: "gui",
                pinnedFirst: false,
                order: .descending
            )
            let thoughts = try store.fetchThoughts(query: query)
            inputHistory = thoughts.reversed().map(\.content)
        } catch {
            inputHistory = []
        }
    }

    private func resetInputHistoryNavigation(keepingDraftSnapshot: Bool = false) {
        inputHistoryIndex = nil
        if !keepingDraftSnapshot {
            inputHistoryDraftSnapshot = nil
        }
    }

    private func handleSelectedResultAction(_ row: CaptureResultRow) {
        guard let reuseText = row.reuseText, !reuseText.isEmpty else { return }
        endEditingMode()
        captureView.populateDraft(reuseText, hideResults: false)
        if let panel = window {
            resizeWindowToMatchContent(panel, animate: true)
            panel.makeFirstResponder(captureView.textView)
        }
    }

    private func beginEditing(_ row: CaptureResultRow) {
        guard let thoughtID = row.thoughtID, let reuseText = row.reuseText, !reuseText.isEmpty else { return }
        editingThoughtID = thoughtID
        resetInputHistoryNavigation(keepingDraftSnapshot: false)
        captureView.setInlineError(nil)
        captureView.setModeStatus("Editing note · Enter to save · Esc to cancel")
        captureView.populateDraft(reuseText, hideResults: false)
        if let panel = window {
            resizeWindowToMatchContent(panel, animate: true)
            panel.makeFirstResponder(captureView.textView)
        }
    }

    private func togglePin(for row: CaptureResultRow) {
        guard let thoughtID = row.thoughtID else { return }
        do {
            _ = try store.updateThought(
                id: thoughtID,
                update: ThoughtUpdate(pinned: !row.pinned)
            )
            refreshResultSession()
            captureView.setInlineError(nil)
            if let panel = window {
                resizeWindowToMatchContent(panel, animate: true)
                panel.makeFirstResponder(captureView.textView)
            }
        } catch {
            captureView.setInlineError("Couldn't update pin")
            NSSound.beep()
        }
    }

    private func toggleArchive(for row: CaptureResultRow) {
        guard let thoughtID = row.thoughtID else { return }
        do {
            _ = try store.updateThought(
                id: thoughtID,
                update: ThoughtUpdate(archived: !row.archived)
            )
            refreshResultSession()
            captureView.setInlineError(nil)
            if let panel = window {
                resizeWindowToMatchContent(panel, animate: true)
                panel.makeFirstResponder(captureView.textView)
            }
        } catch {
            captureView.setInlineError("Couldn't update archive")
            NSSound.beep()
        }
    }

    private func copyResult(_ row: CaptureResultRow) {
        guard let reuseText = row.reuseText, !reuseText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reuseText, forType: .string)
        captureView.setInlineError(nil)
    }

    private func endEditingMode() {
        editingThoughtID = nil
        captureView.setModeStatus(nil)
    }

    private func cancelEditingMode() -> Bool {
        guard editingThoughtID != nil else { return false }
        endEditingMode()
        captureView.setInlineError(nil)
        captureView.clearInput(keepResults: persistentResultsVisible)
        if persistentResultsVisible {
            captureView.focusResults()
        }
        if let panel = window {
            resizeWindowToMatchContent(panel, animate: true)
            panel.makeFirstResponder(captureView.textView)
        }
        return true
    }

    private func showResults(for command: CaptureResultCommand, focusedSurface: CaptureView.FocusedSurface = .input) {
        switch command {
        case .help:
            persistentResultsVisible = true
            persistentEmptyStateText = "No commands yet"
            resultSession = nil
            captureView.showResultRows(
                Self.helpRows,
                hasMore: false,
                headerText: headerText(for: .help),
                emptyStateText: persistentEmptyStateText,
                focusedSurface: focusedSurface
            )
            if let panel = window {
                resizeWindowToMatchContent(panel, animate: true)
                panel.makeFirstResponder(captureView.textView)
            }
        default:
            showThoughtResults(for: command, focusedSurface: focusedSurface)
        }
    }

    private func showThoughtResults(for command: CaptureResultCommand, focusedSurface: CaptureView.FocusedSurface = .input) {
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
        captureView.showResultRows(
            makeRows(from: thoughts),
            hasMore: hasMore,
            headerText: headerText(for: command, loadedCount: thoughts.count, hasMore: hasMore),
            emptyStateText: persistentEmptyStateText,
            focusedSurface: focusedSurface
        )
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
            headerText: headerText(for: session.command, loadedCount: session.offset, hasMore: session.hasMore),
            emptyStateText: persistentEmptyStateText
        )
        return true
    }

    private func makeThoughtQuery(for command: CaptureResultCommand, offset: Int) -> ThoughtQuery {
        CaptureResultQueryBuilder.thoughtQuery(
            for: command,
            offset: offset,
            pageSize: resultPageSize
        )
    }

    private func hasMoreResults(for command: CaptureResultCommand, fetchedCount: Int, offset: Int) -> Bool {
        CaptureResultQueryBuilder.hasMoreResults(
            for: command,
            fetchedCount: fetchedCount,
            offset: offset,
            pageSize: resultPageSize
        )
    }

    private func emptyStateText(for command: CaptureResultCommand) -> String {
        CaptureResultQueryBuilder.emptyStateText(for: command)
    }

    private func headerText(for command: CaptureResultCommand) -> String {
        CaptureResultQueryBuilder.headerText(for: command)
    }

    private func headerText(for command: CaptureResultCommand, loadedCount: Int, hasMore: Bool) -> String {
        CaptureResultQueryBuilder.contextualHeaderText(
            for: command,
            loadedCount: loadedCount,
            hasMore: hasMore
        )
    }

    private func makeRows(from thoughts: [Thought]) -> [CaptureResultRow] {
        thoughts.map {
            CaptureResultRow(
                title: $0.content,
                detail: Self.resultMetaFormatter.string(from: $0.createdAt),
                highlightsTags: true,
                reuseText: $0.content,
                thoughtID: $0.id,
                pinned: $0.pinned,
                archived: $0.archived
            )
        }
    }

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
        CaptureResultRow(title: "/tail 20", detail: "Recent notes", highlightsTags: true, reuseText: "/tail 20", thoughtID: nil, pinned: false, archived: false),
        CaptureResultRow(title: "/search onboarding", detail: "Full-text search", highlightsTags: true, reuseText: "/search ", thoughtID: nil, pinned: false, archived: false),
        CaptureResultRow(title: "/today", detail: "Today's notes", highlightsTags: true, reuseText: "/today", thoughtID: nil, pinned: false, archived: false),
        CaptureResultRow(title: "/tag thoughtstream", detail: "Browse by tag", highlightsTags: true, reuseText: "/tag ", thoughtID: nil, pinned: false, archived: false),
        CaptureResultRow(title: "/archive", detail: "Archived notes", highlightsTags: true, reuseText: "/archive", thoughtID: nil, pinned: false, archived: false),
        CaptureResultRow(title: "/hide", detail: "Collapse results", highlightsTags: true, reuseText: "/hide", thoughtID: nil, pinned: false, archived: false),
        CaptureResultRow(title: "/help", detail: "Command list", highlightsTags: true, reuseText: "/help", thoughtID: nil, pinned: false, archived: false),
        CaptureResultRow(title: "/exit", detail: "Close panel", highlightsTags: true, reuseText: "/exit", thoughtID: nil, pinned: false, archived: false)
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
