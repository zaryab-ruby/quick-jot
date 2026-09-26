# QuickJot

A native macOS scratchpad that lives in the bottom-right corner of your screen.

- **Inactive:** only the header peeks up from the bottom edge of the screen, floating above every window, on every Space, including full-screen apps.
- **Hover:** the tab slides up a little further so you can see your tabs.
- **Click anywhere on it:** it slides up into the active state above the Dock, ready to type into.
- **Click another app or press Esc:** it slides back down and keyboard focus returns to the app you were using. Pin it (📌) to keep it open while you work in other apps.
- **✕ (while active):** quits the app. Your notes are saved first.

There's no Dock icon and no menu bar. You can also quit from the `…` menu.

## Download

Grab [`dist/QuickJot-1.0.0.dmg`](dist/QuickJot-1.0.0.dmg), open it, and drag QuickJot into Applications. It runs on Apple Silicon and Intel Macs (macOS 13+).

The build isn't notarized yet, so the first time you open it macOS will block it. Go to **System Settings → Privacy & Security → Open Anyway**.

## Build and run

Requires macOS 13+ and the Xcode Command Line Tools (full Xcode not needed).

```bash
make run        # build build/QuickJot.app and launch it
make install    # copy it to /Applications and launch it (do this before enabling Launch at Login)
make dmg        # build a universal app and package it as build/QuickJot-<version>.dmg
make test       # run the unit tests
```

## Features

- Multiple scratchpads as tabs: `+` or ⌘T adds one, double-click a tab to rename it, right-click for more.
- Plain-text editor with auto-continued lists (`- `, `1. `, `- [ ] `) and a find bar (⌘F).
- 👁 toggles a Markdown preview; checkboxes in the preview are clickable.
- Copy the whole scratchpad, export it as `.md`, or delete it (asks first if it has text).
- Notes autosave to `~/Library/Application Support/QuickJot/notes.json`.
- Launch at Login from the `…` menu.

| Shortcut | Action |
| --- | --- |
| Esc / ⌘W | Collapse |
| ⌘T | New scratchpad |
| ⇧⌘] / ⇧⌘[ | Next / previous scratchpad |
| ⌘1…⌘9 | Jump to scratchpad |
| ⇧⌘P | Toggle Markdown preview |
| ⌘F | Find |

### URL scheme

You can drive it from Shortcuts, Raycast, Alfred or a global hotkey tool:

```bash
open "quickjot://open"
open "quickjot://collapse"
open "quickjot://toggle"
open "quickjot://new?text=Call%20back%20Sam"
```

## How it works

| File | Role |
| --- | --- |
| `Panel/PanelController.swift` | The state machine (collapsed → peeking → expanded), frame animations, focus hand-off, app-switch detection |
| `Panel/ScratchpadPanel.swift` | Borderless `NSPanel` at status-bar level; intercepts clicks while inactive; pointer tracking view |
| `Panel/HoverZones.swift` | Screen regions that raise/hold the hover peek; the hold zone is larger than the trigger zone so the tab can't jitter |
| `Views/` | SwiftUI UI: header, tab strip, `NSTextView`-backed editor, Markdown preview, bottom bar |
| `Model/NoteStore.swift` | Scratchpads and JSON persistence |

The panel window grows upward from the bottom screen edge while the card inside stays full-size and pinned to the window's top edge, so it looks like the panel is sliding. Nothing is ever positioned off-screen, which also keeps it from leaking onto a second display.

Sizes and reveal heights are in `Panel/Metrics.swift`; colors (including the translucent gray tint) are in `Views/Theme.swift`.
