import Foundation

/// Owns the scratchpads and persists them to
/// `~/Library/Application Support/QuickJot/notes.json`.
@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note]
    @Published var selectedID: UUID {
        didSet { if oldValue != selectedID { scheduleSave() } }
    }

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    private struct Library: Codable {
        var notes: [Note]
        var selectedID: UUID?
    }

    init(fileURL: URL = NoteStore.defaultFileURL) {
        self.fileURL = fileURL
        let library = Self.loadLibrary(from: fileURL)
        let notes = library.map(\.notes).flatMap { $0.isEmpty ? nil : $0 } ?? [Note(title: "Scratchpad 1")]
        self.notes = notes
        self.selectedID = notes.first { $0.id == library?.selectedID }?.id ?? notes[0].id
    }

    nonisolated static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QuickJot", isDirectory: true)
            .appendingPathComponent("notes.json")
    }

    // MARK: - Reading

    var selectedNote: Note {
        notes.first { $0.id == selectedID } ?? notes[0]
    }

    func note(withID id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    func body(of id: UUID) -> String {
        note(withID: id)?.body ?? ""
    }

    // MARK: - Editing

    func setBody(_ body: String, of id: UUID) {
        guard let index = index(of: id), notes[index].body != body else { return }
        notes[index].body = body
        notes[index].updatedAt = Date()
        scheduleSave()
    }

    @discardableResult
    func addNote(body: String = "") -> Note {
        let note = Note(title: nextTitle(), body: body)
        notes.append(note)
        selectedID = note.id
        scheduleSave()
        return note
    }

    func rename(_ id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = index(of: id) else { return }
        notes[index].title = trimmed
        scheduleSave()
    }

    /// Removes a scratchpad. The last remaining one is emptied instead, so there is always a page to type into.
    func delete(_ id: UUID) {
        guard let index = index(of: id) else { return }
        guard notes.count > 1 else {
            setBody("", of: id)
            return
        }
        notes.remove(at: index)
        if selectedID == id {
            selectedID = notes[min(index, notes.count - 1)].id
        }
        scheduleSave()
    }

    /// Flips the first `[ ]` / `[x]` checkbox on the given line.
    func toggleTask(atLine lineIndex: Int, of id: UUID) {
        var lines = body(of: id).components(separatedBy: "\n")
        guard lines.indices.contains(lineIndex) else { return }
        var line = lines[lineIndex]
        let open = line.range(of: "[ ]")
        let done = line.range(of: "[x]", options: .caseInsensitive)
        guard let box = [open, done].compactMap({ $0 }).min(by: { $0.lowerBound < $1.lowerBound }) else { return }
        line.replaceSubrange(box, with: box == open ? "[x]" : "[ ]")
        lines[lineIndex] = line
        setBody(lines.joined(separator: "\n"), of: id)
    }

    // MARK: - Selection

    func select(offset: Int) {
        guard let current = index(of: selectedID) else { return }
        let count = notes.count
        selectedID = notes[((current + offset) % count + count) % count].id
    }

    func select(at index: Int) {
        guard notes.indices.contains(index) else { return }
        selectedID = notes[index].id
    }

    // MARK: - Persistence

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        write()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.write()
        }
    }

    private func write() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(Library(notes: notes, selectedID: selectedID))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("QuickJot: failed to save notes: \(error)")
        }
    }

    private static func loadLibrary(from url: URL) -> Library? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Library.self, from: data)
        } catch {
            // Move the unreadable file aside rather than overwriting it on the next save.
            let backup = url.deletingPathExtension()
                .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            NSLog("QuickJot: could not read \(url.path), moved it to \(backup.lastPathComponent): \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    private func index(of id: UUID) -> Int? {
        notes.firstIndex { $0.id == id }
    }

    private func nextTitle() -> String {
        let used = Set(notes.map(\.title))
        var number = notes.count + 1
        while used.contains("Scratchpad \(number)") { number += 1 }
        return "Scratchpad \(number)"
    }
}
