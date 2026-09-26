import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: NoteStore!
    private var panelController: PanelController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = NoteStore()
        panelController = PanelController(store: store)
        NSApp.mainMenu = makeMainMenu()
        panelController.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Launching the app again (Finder, Spotlight, `open`) brings the scratchpad up.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController.expand()
        return false
    }

    /// `quickjot://open`, `quickjot://collapse`, `quickjot://toggle`, `quickjot://new?text=...`
    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(panelController.handle(url:))
    }

    // MARK: - Menu actions

    @objc func newScratchpad(_ sender: Any?) {
        panelController.newScratchpad()
    }

    @objc func collapsePanel(_ sender: Any?) {
        panelController.collapse()
    }

    @objc func togglePreview(_ sender: Any?) {
        panelController.togglePreview()
    }

    @objc func selectNextScratchpad(_ sender: Any?) {
        store.select(offset: 1)
        panelController.focusEditor()
    }

    @objc func selectPreviousScratchpad(_ sender: Any?) {
        store.select(offset: -1)
        panelController.focusEditor()
    }

    @objc func selectScratchpadByNumber(_ sender: NSMenuItem) {
        store.select(at: sender.tag - 1)
        panelController.focusEditor()
    }
}

// MARK: - Main menu

extension AppDelegate {
    /// The menu bar is never shown for an accessory app, but its key equivalents
    /// still drive ⌘C / ⌘V / ⌘Z etc. inside the panel.
    fileprivate func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenu = NSMenu(title: "QuickJot")
        appMenu.addItem(withTitle: "Quit QuickJot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addSubmenu(appMenu)

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(item("New Scratchpad", #selector(newScratchpad(_:)), "t"))
        fileMenu.addItem(item("Collapse", #selector(collapsePanel(_:)), "w"))
        fileMenu.addItem(item("Toggle Preview", #selector(togglePreview(_:)), "p", [.command, .shift]))
        fileMenu.addItem(.separator())
        fileMenu.addItem(item("Next Scratchpad", #selector(selectNextScratchpad(_:)), "]", [.command, .shift]))
        fileMenu.addItem(item("Previous Scratchpad", #selector(selectPreviousScratchpad(_:)), "[", [.command, .shift]))
        for number in 1...9 {
            let numbered = item("Scratchpad \(number)", #selector(selectScratchpadByNumber(_:)), "\(number)")
            numbered.tag = number
            fileMenu.addItem(numbered)
        }
        mainMenu.addSubmenu(fileMenu)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
            .keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        editMenu.addItem(findItem("Find…", .showFindInterface, "f"))
        editMenu.addItem(findItem("Find Next", .nextMatch, "g"))
        editMenu.addItem(findItem("Find Previous", .previousMatch, "g", [.command, .shift]))
        editMenu.addItem(findItem("Use Selection for Find", .setSearchString, "e"))
        mainMenu.addSubmenu(editMenu)

        return mainMenu
    }

    private func item(
        _ title: String,
        _ action: Selector,
        _ key: String,
        _ modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        return item
    }

    private func findItem(
        _ title: String,
        _ action: NSTextFinder.Action,
        _ key: String,
        _ modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.tag = action.rawValue
        return item
    }
}

private extension NSMenu {
    func addSubmenu(_ submenu: NSMenu) {
        let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }
}
