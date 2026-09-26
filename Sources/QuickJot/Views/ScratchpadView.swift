import AppKit
import SwiftUI

struct ScratchpadView: View {
    @ObservedObject var controller: PanelController
    @ObservedObject var store: NoteStore

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(controller: controller)
            TabStrip(controller: controller, store: store)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            BottomBar(controller: controller, store: store)
        }
        .frame(width: Metrics.panelSize.width, height: Metrics.panelSize.height)
        .background(Theme.tint)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cornerRadius)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        let note = store.selectedNote
        if controller.isPreviewing {
            MarkdownPreview(text: note.body) { line in
                store.toggleTask(atLine: line, of: note.id)
            }
        } else {
            ZStack(alignment: .topLeading) {
                NoteEditor(
                    text: Binding(
                        get: { store.body(of: note.id) },
                        set: { store.setBody($0, of: note.id) }
                    ),
                    noteID: note.id,
                    onEscape: { controller.collapse() },
                    onAttach: { controller.editorDidAttach($0) }
                )
                if note.body.isEmpty {
                    Text("Jot something down…")
                        .font(Font(Theme.editorFont))
                        .foregroundStyle(Theme.tertiary)
                        .padding(.leading, NoteEditor.textInset.width + NoteEditor.lineFragmentPadding)
                        .padding(.top, NoteEditor.textInset.height)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

// MARK: - Header

private struct HeaderBar: View {
    @ObservedObject var controller: PanelController

    var body: some View {
        HStack(spacing: 2) {
            Text("QuickJot")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.secondary)
            Spacer(minLength: 0)
            IconButton(
                systemName: controller.isPinned ? "pin.fill" : "pin",
                label: controller.isPinned ? "Unpin: collapse when clicking elsewhere" : "Pin: stay open when clicking elsewhere",
                tint: controller.isPinned ? Theme.accent : nil,
                rotation: .degrees(45)
            ) {
                controller.isPinned.toggle()
            }
            // Quits the app. (Clicks on the inactive tab never reach this; they open the panel.)
            IconButton(systemName: "xmark.circle.fill", label: "Quit QuickJot") {
                NSApp.terminate(nil)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(height: Metrics.headerHeight)
    }
}

// MARK: - Bottom bar

private struct BottomBar: View {
    @ObservedObject var controller: PanelController
    @ObservedObject var store: NoteStore
    @State private var didCopy = false

    var body: some View {
        Group {
            if let id = controller.pendingDeleteID, let note = store.note(withID: id) {
                confirmation(for: note)
            } else {
                tools
            }
        }
        .padding(.horizontal, 6)
        .frame(height: Metrics.bottomBarHeight)
    }

    private var tools: some View {
        HStack(spacing: 2) {
            IconButton(
                systemName: controller.isPreviewing ? "eye.fill" : "eye",
                label: controller.isPreviewing ? "Back to editing (⇧⌘P)" : "Preview Markdown (⇧⌘P)",
                tint: controller.isPreviewing ? Theme.accent : nil
            ) {
                controller.togglePreview()
            }
            IconButton(
                systemName: didCopy ? "checkmark" : "doc.on.doc",
                label: "Copy to clipboard",
                tint: didCopy ? Theme.success : nil
            ) {
                controller.copyToPasteboard(store.selectedNote)
                didCopy = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { didCopy = false }
            }
            IconButton(systemName: "square.and.arrow.down", label: "Export as Markdown…") {
                controller.export(store.selectedNote)
            }
            Spacer(minLength: 0)
            IconButton(
                systemName: "trash",
                label: store.notes.count > 1 ? "Delete scratchpad" : "Clear scratchpad"
            ) {
                controller.requestDelete(store.selectedID)
            }
        }
    }

    private func confirmation(for note: Note) -> some View {
        let isClearing = store.notes.count == 1
        return HStack(spacing: 6) {
            Text(isClearing ? "Clear “\(note.title)”?" : "Delete “\(note.title)”?")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Button("Cancel") {
                controller.pendingDeleteID = nil
                controller.focusEditor()
            }
            .buttonStyle(PillButtonStyle())
            Button(isClearing ? "Clear" : "Delete") {
                controller.confirmPendingDelete()
            }
            .buttonStyle(PillButtonStyle(isDestructive: true))
        }
        .padding(.leading, 6)
    }
}
