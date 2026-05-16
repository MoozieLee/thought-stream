import AppKit
import Carbon
import ThoughtStreamCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var store: ThoughtStore?
    private var panelController: CapturePanelController?
    private var hotKeyRef: EventHotKeyRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x54535452), id: 1) // TSTR

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard reloadStore() else {
            NSApp.terminate(nil)
            return
        }
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

    @objc private func revealDataFolder() {
        guard let store else { return }
        NSWorkspace.shared.activateFileViewerSelecting([store.databaseURL])
    }

    @objc private func changeStorageLocation() {
        let panel = NSOpenPanel()
        panel.title = "Choose ThoughtStream Storage Folder"
        panel.message = "ThoughtStream stores thoughts.sqlite3 in the selected folder."
        panel.prompt = "Use Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let directoryURL = panel.url else {
            return
        }

        do {
            // Detect conflict and ask user how to handle it.
            let newDatabaseURL = directoryURL.appendingPathComponent("thoughts.sqlite3", isDirectory: false)
            let policy: ThoughtStore.MigrationConflictPolicy
            if FileManager.default.fileExists(atPath: newDatabaseURL.path) {
                guard let chosen = askMigrationConflict(at: newDatabaseURL.path) else { return }
                policy = chosen
            } else {
                policy = .error // safe default, target doesn't exist
            }

            // Migrate existing database to the new location before saving config.
            if let oldStore = store {
                try ThoughtStore.migrateStoreIfNeeded(from: oldStore.databaseURL, to: directoryURL, onConflict: policy)
            }
            var config = ThoughtStreamConfig.load()
            config.storageRoot = directoryURL.path
            try config.save()
            if reloadStore() {
                showInformationalAlert(
                    title: "Storage Location Updated",
                    message: "ThoughtStream will store data in:\n\(directoryURL.path)"
                )
            }
        } catch {
            showErrorAlert(
                title: "Could Not Save Storage Location",
                message: error.localizedDescription
            )
        }
    }

    @objc private func resetStorageLocation() {
        var config = ThoughtStreamConfig.load()
        guard config.storageRoot != nil else {
            showInformationalAlert(
                title: "Storage Location Already Default",
                message: "ThoughtStream is already using the default Application Support folder."
            )
            return
        }

        config.storageRoot = nil
        do {
            try config.save()
            if reloadStore() {
                showInformationalAlert(
                    title: "Storage Location Reset",
                    message: "ThoughtStream is now using the default Application Support folder again."
                )
            }
        } catch {
            showErrorAlert(
                title: "Could Not Reset Storage Location",
                message: error.localizedDescription
            )
        }
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
        menu.addItem(NSMenuItem(title: "Reveal Data Folder", action: #selector(revealDataFolder), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Change Storage Location…", action: #selector(changeStorageLocation), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reset Storage Location", action: #selector(resetStorageLocation), keyEquivalent: ""))
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

    @discardableResult
    private func reloadStore() -> Bool {
        let wasVisible = panelController?.isVisible == true
        if wasVisible {
            panelController?.hidePanel()
        }
        panelController = nil
        store = nil

        do {
            let nextStore = try ThoughtStore()
            store = nextStore
            panelController = CapturePanelController(store: nextStore)
            if wasVisible {
                panelController?.toggle()
            }
            return true
        } catch {
            showErrorAlert(
                title: "Could Not Open ThoughtStream Storage",
                message: error.localizedDescription
            )
            return false
        }
    }

    private func showInformationalAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    /// Ask the user how to handle an existing database at the target location.
    /// Returns nil when the user cancels.
    private func askMigrationConflict(at path: String) -> ThoughtStore.MigrationConflictPolicy? {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Database Already Exists"
        alert.informativeText = "\(path) already contains a database.\n\nOverwrite: replace it with your current data.\nMerge: combine both databases (duplicate entries are skipped)."
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Merge")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .overwrite
        case .alertSecondButtonReturn: return .merge
        default: return nil
        }
    }

    private func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
