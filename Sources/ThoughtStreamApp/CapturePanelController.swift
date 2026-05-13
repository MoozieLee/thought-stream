import AppKit
import ThoughtStreamCore

@MainActor
final class CapturePanelController: NSWindowController, NSWindowDelegate {
    private let store: ThoughtStore
    private let rootView = TransparentRootView(frame: NSRect(x: 0, y: 0, width: 760, height: 78))
    private let captureView = CaptureView(frame: NSRect(x: 0, y: 0, width: 760, height: 78))
    private weak var previousApp: NSRunningApplication?
    private let defaults = UserDefaults.standard
    private let originXKey = "capturePanel.origin.x"
    private let originYKey = "capturePanel.origin.y"
    private var persistentResultsVisible = false

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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hidePanel()
            return
        }

        if let suggestion = autocompleteSuggestion(for: trimmed), suggestion != trimmed {
            captureView.applyAutocompleteSuggestionIfNeeded()
            executeSlashCommand(.exactCommand(suggestion))
            return
        }

        switch parseSlashCommand(trimmed) {
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
            _ = try store.addThought(content: trimmed, source: "human", channel: "gui")
            captureView.clearInput(keepResults: persistentResultsVisible)
            if let panel = window {
                resizeWindowToMatchContent(panel, animate: true)
                panel.makeFirstResponder(captureView.textView)
            }
        } catch {
            NSSound.beep()
            return
        }
    }

    func hidePanel() {
        persistentResultsVisible = false
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
        if !persistentResultsVisible, text.trimmingCharacters(in: .whitespacesAndNewlines) != "/tail" {
            captureView.hideResults()
            if let panel = window {
                resizeWindowToMatchContent(panel, animate: true)
            }
        }
    }

    private func showTailResults(limit: Int) {
        let thoughts: [Thought]
        do {
            thoughts = try store.fetchRecentThoughts(
                limit: limit,
                source: "human",
                channel: "gui"
            )
        } catch {
            NSSound.beep()
            return
        }

        persistentResultsVisible = true
        captureView.showTailResults(thoughts)
        if let panel = window {
            resizeWindowToMatchContent(panel, animate: true)
            panel.makeFirstResponder(captureView.textView)
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
        guard trimmed.hasPrefix("/"), !trimmed.contains(" ") else { return nil }

        let availableCommands = ["/tail", "/exit"]
        return availableCommands.first { command in
            command != trimmed && command.hasPrefix(trimmed)
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

        if command == "/exit" {
            return parts.count == 1 ? .handled(.exit) : .invalid
        }

        guard command == "/tail" else {
            return .notCommand
        }
        if parts.count == 1 {
            return .handled(.tail(limit: 6))
        }
        guard parts.count == 2 else {
            return .invalid
        }

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
            return .invalid
        }

        return .invalid
    }

    private func executeSlashCommand(_ command: SlashCommand) {
        switch command {
        case .tail(let limit):
            showTailResults(limit: limit)
            captureView.clearInput(keepResults: true)
        case .exit:
            hidePanel()
        case .exactCommand(let command):
            switch command {
            case "/tail":
                executeSlashCommand(.tail(limit: 6))
            case "/exit":
                executeSlashCommand(.exit)
            default:
                NSSound.beep()
            }
        }
    }
}

private enum SlashCommandParseResult {
    case notCommand
    case invalid
    case handled(SlashCommand)
}

private enum SlashCommand {
    case tail(limit: Int)
    case exit
    case exactCommand(String)
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
