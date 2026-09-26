import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Owns the scratchpad panel and drives its three states:
///
/// - `collapsed`: only the header peeks up from the bottom edge of the screen.
/// - `peeking`: the pointer is over the collapsed panel, so it slides up a little further.
/// - `expanded`: the full panel sits above the Dock, focused and ready for typing.
///
/// The panel floats above other windows (and full-screen apps) on every Space in all three states.
@MainActor
final class PanelController: NSObject, ObservableObject {
    enum Mode {
        case collapsed, peeking, expanded
    }

    @Published private(set) var mode: Mode = .collapsed {
        didSet { updateHoverPolling() }
    }
    /// Pinned panels stay expanded when you click into another app.
    @Published var isPinned: Bool {
        didSet { UserDefaults.standard.set(isPinned, forKey: Self.pinnedDefaultsKey) }
    }
    @Published var isPreviewing = false
    @Published var renamingNoteID: UUID?
    /// Scratchpad waiting on the inline "Delete?" confirmation in the bottom bar.
    @Published var pendingDeleteID: UUID?

    let store: NoteStore

    private var panel: ScratchpadPanel!
    private weak var editorTextView: NSTextView?
    private var wantsEditorFocus = false
    private var animationGeneration = 0
    private var isPresentingSavePanel = false

    private var hoverZones = HoverZones.none
    private var pendingHoverCollapse: Task<Void, Never>?
    private var pointerMonitors: [Any] = []
    private var hoverPollTimer: Timer?

    private static let pinnedDefaultsKey = "isPinned"

    init(store: NoteStore) {
        self.store = store
        self.isPinned = UserDefaults.standard.bool(forKey: Self.pinnedDefaultsKey)
        super.init()
        panel = makePanel()
        updateHoverZones()
        startPointerMonitoring()

        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(applicationDidResignActive(_:)),
            name: NSApplication.didResignActiveNotification, object: nil
        )
        center.addObserver(
            self, selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    // MARK: - State changes

    func show() {
        panel.setFrame(frame(for: mode), display: true)
        panel.orderFrontRegardless()
    }

    func expand() {
        guard mode != .expanded else {
            focusEditor()
            return
        }
        cancelHoverCollapse()
        mode = .expanded
        activateApp()
        panel.makeKeyAndOrderFront(nil)
        animate(to: .expanded)
        focusEditor()
    }

    func collapse() {
        guard mode == .expanded else { return }
        mode = .collapsed
        pendingDeleteID = nil
        panel.makeFirstResponder(nil)
        // Hand keyboard focus back to whatever app was in front. The panel has
        // `canHide = false`, so it stays on screen.
        if NSApp.isActive { NSApp.hide(nil) }
        animate(to: .collapsed)
    }

    func toggle() {
        if mode == .expanded { collapse() } else { expand() }
    }

    @objc private func applicationDidResignActive(_ notification: Notification) {
        guard mode == .expanded, !isPinned, !isPresentingSavePanel else { return }
        collapse()
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        updateHoverZones()
        panel.setFrame(frame(for: mode), display: true)
    }

    // MARK: - Hover

    /// The hover state depends only on where the pointer is relative to fixed screen
    /// regions (`HoverZones`), never on the panel's frame mid-animation.
    private func evaluateHover() {
        guard mode != .expanded else { return }
        let wantsPeek = hoverZones.wantsPeek(pointer: NSEvent.mouseLocation, isPeeking: mode == .peeking)

        switch (mode, wantsPeek) {
        case (.collapsed, true):
            cancelHoverCollapse()
            mode = .peeking
            animate(to: .peeking)
        case (.peeking, true):
            cancelHoverCollapse()
        case (.peeking, false):
            scheduleHoverCollapse()
        default:
            break
        }
    }

    /// Slide back down only if the pointer stays away for a moment.
    private func scheduleHoverCollapse() {
        guard pendingHoverCollapse == nil else { return }
        pendingHoverCollapse = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Metrics.hoverCollapseDelay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.pendingHoverCollapse = nil
            guard self.mode == .peeking,
                  !self.hoverZones.wantsPeek(pointer: NSEvent.mouseLocation, isPeeking: true)
            else { return }
            self.mode = .collapsed
            self.animate(to: .collapsed)
        }
    }

    private func cancelHoverCollapse() {
        pendingHoverCollapse?.cancel()
        pendingHoverCollapse = nil
    }

    /// While the tab is raised, re-check the pointer on a timer too, so it always
    /// slides back down even if the pointer leaves without delivering an event.
    private func updateHoverPolling() {
        if mode == .peeking {
            guard hoverPollTimer == nil else { return }
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluateHover() }
            }
            RunLoop.main.add(timer, forMode: .common)
            hoverPollTimer = timer
        } else {
            hoverPollTimer?.invalidate()
            hoverPollTimer = nil
        }
    }

    private func updateHoverZones() {
        guard let screen else { return }
        hoverZones = HoverZones(
            collapsedFrame: frame(for: .collapsed),
            peekingFrame: frame(for: .peeking),
            screenFrame: screen.frame
        )
    }

    /// Pointer movement over other apps (global) and over our own windows (local),
    /// so the zones work even where they extend past the panel's edges.
    private func startPointerMonitoring() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluateHover() }
        }) {
            pointerMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            self?.evaluateHover()
            return event
        }) {
            pointerMonitors.append(local)
        }
    }

    // MARK: - Editor focus

    func editorDidAttach(_ textView: NSTextView) {
        editorTextView = textView
        if wantsEditorFocus {
            wantsEditorFocus = false
            panel.makeFirstResponder(textView)
        }
    }

    func focusEditor() {
        guard mode == .expanded, !isPreviewing, renamingNoteID == nil else { return }
        if let editorTextView, editorTextView.window === panel {
            panel.makeFirstResponder(editorTextView)
        } else {
            wantsEditorFocus = true
        }
    }

    // MARK: - Actions

    func newScratchpad(body: String = "") {
        store.addNote(body: body)
        expand()
        focusEditor()
    }

    func togglePreview() {
        isPreviewing.toggle()
        if isPreviewing {
            panel.makeFirstResponder(nil)
        } else {
            focusEditor()
        }
    }

    func startRenaming(_ id: UUID) {
        store.selectedID = id
        renamingNoteID = id
    }

    /// Empty scratchpads go straight away; anything with text asks first.
    func requestDelete(_ id: UUID) {
        guard let note = store.note(withID: id) else { return }
        if note.body.isEmpty {
            if store.notes.count > 1 { store.delete(id) }
            return
        }
        pendingDeleteID = id
    }

    func confirmPendingDelete() {
        guard let id = pendingDeleteID else { return }
        pendingDeleteID = nil
        store.delete(id)
        focusEditor()
    }

    func copyToPasteboard(_ note: Note) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(note.body, forType: .string)
    }

    func export(_ note: Note) {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Scratchpad"
        savePanel.nameFieldStringValue = note.title.replacingOccurrences(of: "[/:]", with: "-", options: .regularExpression) + ".md"
        savePanel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        savePanel.allowsOtherFileTypes = true
        savePanel.canCreateDirectories = true
        savePanel.level = NSWindow.Level(rawValue: panel.level.rawValue + 1)

        isPresentingSavePanel = true
        activateApp()
        savePanel.begin { [weak self] response in
            MainActor.assumeIsolated {
                self?.isPresentingSavePanel = false
                guard response == .OK, let url = savePanel.url else { return }
                do {
                    try note.body.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    self?.present(error)
                }
                self?.panel.makeKey()
                self?.focusEditor()
            }
        }
    }

    func showOverflowMenu() {
        let selected = store.selectedNote
        let canDelete = store.notes.count > 1
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(ActionMenuItem("New Scratchpad", key: "t") { [weak self] in
            self?.newScratchpad()
        })
        menu.addItem(ActionMenuItem("Rename Scratchpad…") { [weak self] in
            self?.startRenaming(selected.id)
        })
        let delete = ActionMenuItem(canDelete ? "Delete Scratchpad…" : "Clear Scratchpad…") { [weak self] in
            self?.requestDelete(selected.id)
        }
        delete.isEnabled = canDelete || !selected.body.isEmpty
        menu.addItem(delete)

        menu.addItem(.separator())
        let preview = ActionMenuItem("Preview Markdown", key: "p") { [weak self] in
            self?.togglePreview()
        }
        preview.keyEquivalentModifierMask = [.command, .shift]
        preview.state = isPreviewing ? .on : .off
        menu.addItem(preview)
        let loginItem = ActionMenuItem("Launch at Login") { [weak self] in
            do {
                try LoginItem.setEnabled(!LoginItem.isEnabled)
            } catch {
                self?.present(error)
            }
        }
        loginItem.state = LoginItem.isEnabled ? .on : .off
        loginItem.isEnabled = LoginItem.isAvailable
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Quit QuickJot", key: "q") {
            NSApp.terminate(nil)
        })

        guard let view = panel.contentView else { return }
        let location = view.convert(panel.mouseLocationOutsideOfEventStream, from: nil)
        menu.popUp(positioning: nil, at: location, in: view)
    }

    func handle(url: URL) {
        switch url.host?.lowercased() {
        case "collapse", "close", "hide":
            collapse()
        case "toggle":
            toggle()
        case "new":
            let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "text" }?.value ?? ""
            newScratchpad(body: text)
        default:
            expand()
        }
    }

    // MARK: - Window

    private func makePanel() -> ScratchpadPanel {
        let panel = ScratchpadPanel(
            contentRect: frame(for: .collapsed),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        // Above normal and floating windows and the Dock, on every Space including full-screen ones.
        // (Set after `isFloatingPanel`, which resets the level to `.floating`.)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.worksWhenModal = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.appearance = NSAppearance(named: .darkAqua)

        // The window grows and shrinks from the bottom screen edge; the card inside
        // stays full size, pinned to the window's top edge, so the panel appears to slide.
        let size = Metrics.panelSize
        let container = PointerTrackingView(frame: NSRect(origin: .zero, size: panel.frame.size))
        container.autoresizingMask = [.width, .height]
        if #available(macOS 14.0, *) { container.clipsToBounds = true }
        container.onPointerActivity = { [weak self] in
            self?.evaluateHover()
        }

        let card = NSVisualEffectView(frame: NSRect(
            x: 0, y: container.bounds.height - size.height,
            width: size.width, height: size.height
        ))
        card.autoresizingMask = [.minYMargin]
        card.material = .hudWindow
        card.blendingMode = .behindWindow
        card.state = .active
        card.maskImage = .roundedRectMask(cornerRadius: Metrics.cornerRadius)

        let hostingView = FirstMouseHostingView(rootView: ScratchpadView(controller: self, store: store))
        hostingView.sizingOptions = []
        hostingView.frame = card.bounds
        hostingView.autoresizingMask = [.width, .height]

        card.addSubview(hostingView)
        container.addSubview(card)
        panel.contentView = container

        // A click anywhere on the inactive panel activates it.
        panel.mouseDownInterceptor = { [weak self] _ in
            guard let self, self.mode != .expanded else { return false }
            self.expand()
            return true
        }
        panel.onCancel = { [weak self] in self?.collapse() }
        return panel
    }

    private var screen: NSScreen? {
        NSScreen.screens.first
    }

    private func frame(for mode: Mode) -> NSRect {
        guard let screen else { return .zero }
        let size = Metrics.panelSize
        let full = screen.frame
        let visible = screen.visibleFrame
        // Flush with the right edge of the usable area (left of a right-side Dock) in every
        // state, so the panel slides straight up and down.
        let x = visible.maxX - size.width
        // Inactive, the tab fills the same band as a bottom Dock: its top is flush with the
        // bottom of a maximized window.
        let collapsedHeight = max(visible.minY - full.minY, Metrics.minimumCollapsedReveal)

        switch mode {
        case .collapsed:
            return NSRect(x: x, y: full.minY, width: size.width, height: collapsedHeight)
        case .peeking:
            return NSRect(x: x, y: full.minY, width: size.width, height: collapsedHeight + Metrics.hoverLift)
        case .expanded:
            // Sits on the bottom of the usable area: right on top of the Dock, where
            // maximized windows end.
            return NSRect(x: x, y: visible.minY, width: size.width, height: size.height)
        }
    }

    private func animate(to mode: Mode) {
        let target = frame(for: mode)
        animationGeneration += 1
        let generation = animationGeneration

        let duration: TimeInterval
        let timing: CAMediaTimingFunction
        switch mode {
        case .expanded:
            duration = 0.38
            timing = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
        case .peeking:
            duration = 0.24
            timing = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
        case .collapsed:
            duration = 0.28
            timing = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1)
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = timing
            panel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, generation == self.animationGeneration else { return }
                self.panel.invalidateShadow()
                // The panel may have moved under a still pointer (e.g. collapsing onto it).
                self.evaluateHover()
            }
        })
    }

    private func activateApp() {
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func present(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.window.level = NSWindow.Level(rawValue: panel.level.rawValue + 1)
        activateApp()
        alert.runModal()
    }
}

/// NSMenuItem that runs a closure.
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func fire() {
        handler()
    }
}
