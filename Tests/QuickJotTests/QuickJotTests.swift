import AppKit
import Foundation
import Testing
@testable import QuickJot

@MainActor
struct NoteStoreTests {
    private func makeStore() -> NoteStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("notes.json")
        return NoteStore(fileURL: url)
    }

    @Test func startsWithOneScratchpad() {
        let store = makeStore()
        #expect(store.notes.map(\.title) == ["Scratchpad 1"])
    }

    @Test func newScratchpadsGetUnusedNumbers() {
        let store = makeStore()
        store.addNote()
        store.addNote()
        store.delete(store.notes[1].id)
        store.addNote()
        #expect(store.notes.map(\.title) == ["Scratchpad 1", "Scratchpad 3", "Scratchpad 4"])
    }

    @Test func deletingSelectsNeighbourAndLastOneIsClearedInstead() {
        let store = makeStore()
        let first = store.notes[0].id
        let second = store.addNote().id
        store.delete(second)
        #expect(store.selectedID == first)

        store.setBody("keep me?", of: first)
        store.delete(first)
        #expect(store.notes.count == 1)
        #expect(store.body(of: first).isEmpty)
    }

    @Test func togglesTheCheckboxNotLaterBrackets() {
        let store = makeStore()
        let id = store.selectedID
        store.setBody("intro\n- [x] ship it, then [ ] later", of: id)
        store.toggleTask(atLine: 1, of: id)
        #expect(store.body(of: id) == "intro\n- [ ] ship it, then [ ] later")
        store.toggleTask(atLine: 1, of: id)
        #expect(store.body(of: id) == "intro\n- [x] ship it, then [ ] later")
    }

    @Test func persistsAcrossLaunches() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("notes.json")
        let store = NoteStore(fileURL: url)
        store.setBody("hello", of: store.selectedID)
        let second = store.addNote(body: "second")
        store.rename(second.id, to: "Ideas")
        store.saveNow()

        let reloaded = NoteStore(fileURL: url)
        #expect(reloaded.notes.map(\.title) == ["Scratchpad 1", "Ideas"])
        #expect(reloaded.notes.map(\.body) == ["hello", "second"])
        #expect(reloaded.selectedID == second.id)
    }

    @Test func unreadableFileIsMovedAsideNotOverwritten() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("notes.json")
        try Data("not json".utf8).write(to: url)

        let store = NoteStore(fileURL: url)
        #expect(store.notes.count == 1)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files.contains { $0.hasPrefix("notes.corrupt-") })
    }
}

@MainActor
struct ListContinuationTests {
    /// Types Return at the end of `text` and returns the result.
    private func pressReturn(after text: String) -> String {
        let textView = NSTextView()
        textView.string = text
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        if !ListContinuation.insertNewline(in: textView) {
            textView.insertText("\n", replacementRange: textView.selectedRange())
        }
        return textView.string
    }

    @Test func continuesBullets() {
        #expect(pressReturn(after: "- one") == "- one\n- ")
        #expect(pressReturn(after: "  * nested") == "  * nested\n  * ")
    }

    @Test func incrementsNumbers() {
        #expect(pressReturn(after: "9. nine") == "9. nine\n10. ")
        #expect(pressReturn(after: "1) one") == "1) one\n2) ")
    }

    @Test func continuesTasksUnchecked() {
        #expect(pressReturn(after: "- [x] done") == "- [x] done\n- [ ] ")
    }

    @Test func emptyItemEndsTheList() {
        #expect(pressReturn(after: "- one\n- ") == "- one\n")
        #expect(pressReturn(after: "- [ ] ") == "")
    }

    @Test func plainLinesAreLeftAlone() {
        #expect(pressReturn(after: "hello") == "hello\n")
        #expect(pressReturn(after: "-5 degrees") == "-5 degrees\n")
    }
}

struct MarkdownBlockTests {
    @Test func classifiesLines() {
        let blocks = MarkdownBlock.parse("# Title\n- item\n- [ ] todo\n- [X] done\n2. two\n> quote\n---\n\nplain")
        let kinds = blocks.map { block -> String in
            switch block.kind {
            case let .heading(level, text): return "h\(level):\(text)"
            case let .bullet(_, text): return "bullet:\(text)"
            case let .task(_, isDone, text): return "task:\(isDone):\(text)"
            case let .numbered(_, number, text): return "num:\(number)\(text)"
            case let .quote(text): return "quote:\(text)"
            case .code: return "code"
            case .rule: return "rule"
            case let .paragraph(text): return "p:\(text)"
            case .blank: return "blank"
            }
        }
        #expect(kinds == [
            "h1:Title", "bullet:item", "task:false:todo", "task:true:done",
            "num:2.two", "quote:quote", "rule", "blank", "p:plain",
        ])
    }

    @Test func blockIDsAreSourceLineNumbers() {
        let blocks = MarkdownBlock.parse("a\n```\ncode\nmore\n```\n- [ ] task")
        #expect(blocks.map(\.id) == [0, 1, 5])
    }
}

struct HoverZonesTests {
    // Same geometry as a 1920×1080 screen with the panel in the bottom-right corner.
    private let screen = NSRect(x: 0, y: 0, width: 1920, height: 1080)
    private var collapsed: NSRect { NSRect(x: 1552, y: 0, width: 360, height: 54) }  // a 54pt bottom Dock
    private var peeking: NSRect { NSRect(x: 1552, y: 0, width: 360, height: 54 + Metrics.hoverLift) }
    private var zones: HoverZones { HoverZones(collapsedFrame: collapsed, peekingFrame: peeking, screenFrame: screen) }

    @Test func holdZoneContainsTriggerZoneWithRoomToSpare() {
        // If this ever fails, the tab can flicker: it would raise and drop at the same pointer position.
        #expect(zones.hold.contains(zones.trigger))
        #expect(zones.hold.maxY - zones.trigger.maxY >= 16)
    }

    @Test func pointerJustAboveTheTabRaisesIt() {
        let justAbove = NSPoint(x: collapsed.midX, y: collapsed.maxY + Metrics.peekTriggerSlop - 1)
        #expect(zones.wantsPeek(pointer: justAbove, isPeeking: false))
        #expect(!zones.wantsPeek(pointer: NSPoint(x: collapsed.midX, y: collapsed.maxY + 40), isPeeking: false))
    }

    @Test func raisedTabStaysUpNearItsEdgesAndDropsWhenClearlyAway() {
        let nearTop = NSPoint(x: peeking.midX, y: peeking.maxY + Metrics.peekHoldSlop - 1)
        let nearLeft = NSPoint(x: peeking.minX - Metrics.peekHoldSlop + 1, y: 10)
        #expect(zones.wantsPeek(pointer: nearTop, isPeeking: true))
        #expect(zones.wantsPeek(pointer: nearLeft, isPeeking: true))
        #expect(!zones.wantsPeek(pointer: NSPoint(x: peeking.midX, y: peeking.maxY + 60), isPeeking: true))
    }

    @Test func zonesStayOnTheirScreen() {
        #expect(zones.hold.maxX <= screen.maxX)
        #expect(zones.hold.minY >= screen.minY)
        #expect(zones.wantsPeek(pointer: NSPoint(x: collapsed.midX, y: 0), isPeeking: false))
    }
}
