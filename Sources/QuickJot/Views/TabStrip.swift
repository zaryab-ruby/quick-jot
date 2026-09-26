import SwiftUI

struct TabStrip: View {
    @ObservedObject var controller: PanelController
    @ObservedObject var store: NoteStore

    var body: some View {
        HStack(spacing: 2) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(store.notes) { note in
                            TabPill(
                                note: note,
                                isSelected: note.id == store.selectedID,
                                controller: controller,
                                store: store
                            )
                            .id(note.id)
                        }
                    }
                }
                .onChange(of: store.selectedID) { id in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id) }
                }
            }
            IconButton(systemName: "plus", label: "New scratchpad (⌘T)") {
                controller.newScratchpad()
            }
            IconButton(systemName: "ellipsis", label: "More") {
                controller.showOverflowMenu()
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: Metrics.tabStripHeight)
    }
}

private struct TabPill: View {
    let note: Note
    let isSelected: Bool
    @ObservedObject var controller: PanelController
    @ObservedObject var store: NoteStore
    @State private var isHovering = false

    var body: some View {
        if controller.renamingNoteID == note.id {
            RenameField(note: note, controller: controller, store: store)
                .modifier(PillStyle(isSelected: isSelected, isHovering: false))
        } else {
            Text(note.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 130)
                .modifier(PillStyle(isSelected: isSelected, isHovering: isHovering))
                .onHover { isHovering = $0 }
                .onTapGesture {
                    store.selectedID = note.id
                    controller.focusEditor()
                }
                .simultaneousGesture(TapGesture(count: 2).onEnded {
                    controller.startRenaming(note.id)
                })
                .contextMenu {
                    Button("Rename…") { controller.startRenaming(note.id) }
                    Button(store.notes.count > 1 ? "Delete…" : "Clear…") {
                        store.selectedID = note.id
                        controller.requestDelete(note.id)
                    }
                }
                .help("Double-click to rename")
        }
    }
}

private struct PillStyle: ViewModifier {
    let isSelected: Bool
    let isHovering: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : Theme.secondary)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected ? Theme.accent : (isHovering ? Theme.hover : .clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct RenameField: View {
    let note: Note
    @ObservedObject var controller: PanelController
    @ObservedObject var store: NoteStore
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Name", text: $draft)
            .textFieldStyle(.plain)
            .frame(width: 110)
            .focused($isFocused)
            .onAppear {
                draft = note.title
                DispatchQueue.main.async { isFocused = true }
            }
            .onSubmit { finish(commit: true) }
            .onExitCommand { finish(commit: false) }
            .onChange(of: isFocused) { focused in
                if !focused { finish(commit: true) }
            }
    }

    private func finish(commit: Bool) {
        guard controller.renamingNoteID == note.id else { return }
        if commit { store.rename(note.id, to: draft) }
        controller.renamingNoteID = nil
        controller.focusEditor()
    }
}
