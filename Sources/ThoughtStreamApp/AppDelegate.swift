import AppKit
import Carbon
import ThoughtStreamCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let store = ThoughtStore.shared
    private var panelController: CapturePanelController?
    private var hotKeyRef: EventHotKeyRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x54535452), id: 1) // TSTR

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = CapturePanelController(store: store)
        configureStatusItem()
        installHotKey()
        installCLIIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }

    @objc private func toggleCapturePanel() {
        panelController?.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    /// On first launch, create a symlink from /usr/local/bin/thought
    /// to the CLI binary embedded inside the app bundle.
    /// This matches Obsidian's approach of self-bootstrapping its CLI tool.
    private func installCLIIfNeeded() {
        let symlinkPath = "/usr/local/bin/thought"

        guard !FileManager.default.fileExists(atPath: symlinkPath) else { return }
        guard let cliURL = Bundle.main.url(forAuxiliaryExecutable: "thought") else { return }

        do {
            try FileManager.default.createSymbolicLink(
                at: URL(fileURLWithPath: symlinkPath),
                withDestinationURL: cliURL
            )
            print("CLI symlink created: \(symlinkPath)")
        } catch {
            // Permission denied or /usr/local/bin not writable.
            // Fall back: install_app.sh handles this with sudo.
            print("Could not create CLI symlink at \(symlinkPath): \(error.localizedDescription)")
        }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            if let image = menuBarImage() {
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.title = "TS"
            }
            button.toolTip = "ThoughtStream"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Capture", action: #selector(toggleCapturePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
    }

    private func menuBarImage() -> NSImage? {
        guard
            let url = Bundle.main.url(forResource: "MenuBarIconTemplate", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    private func installHotKey() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                let appDelegatePointer = userData
                if hotKeyID.id == 1 {
                    Task { @MainActor in
                        let appDelegate = Unmanaged<AppDelegate>.fromOpaque(appDelegatePointer).takeUnretainedValue()
                        appDelegate.toggleCapturePanel()
                    }
                }
                return noErr
            },
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            nil
        )

        let keyCode: UInt32 = 49 // space
        let modifiers = UInt32(cmdKey | shiftKey)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
