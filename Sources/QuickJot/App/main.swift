import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // No Dock icon and no app switcher entry: the panel itself is the whole UI.
    app.setActivationPolicy(.accessory)
    app.run()
}
