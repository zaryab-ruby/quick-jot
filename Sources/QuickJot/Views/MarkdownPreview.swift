import SwiftUI

/// Read-only rendering of the scratchpad: headings, lists, checkboxes (clickable),
/// quotes, code blocks, rules, and inline Markdown.
struct MarkdownPreview: View {
    let text: String
    var onToggleTask: (Int) -> Void

    var body: some View {
        let blocks = MarkdownBlock.parse(text)
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 3) {
                if blocks.allSatisfy({ if case .blank = $0.kind { return true } else { return false } }) {
                    Text("Nothing to preview yet.")
                        .foregroundStyle(Theme.tertiary)
                }
                ForEach(blocks) { block in
                    row(for: block)
                }
            }
            .font(Font(Theme.editorFont))
            .foregroundStyle(Theme.text)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, NoteEditor.textInset.width + NoteEditor.lineFragmentPadding)
            .padding(.vertical, NoteEditor.textInset.height)
        }
    }

    @ViewBuilder
    private func row(for block: MarkdownBlock) -> some View {
        switch block.kind {
        case let .heading(level, text):
            Text(inline(text))
                .font(.system(size: [17, 15, 13.5][min(level, 3) - 1], weight: .bold))
                .padding(.top, 4)
        case let .bullet(indent, text):
            item(indent: indent, marker: Text("•").foregroundColor(Theme.secondary), text: Text(inline(text)))
        case let .numbered(indent, number, text):
            item(indent: indent, marker: Text(number).monospacedDigit().foregroundColor(Theme.secondary), text: Text(inline(text)))
        case let .task(indent, isDone, text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Button { onToggleTask(block.id) } label: {
                    Image(systemName: isDone ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isDone ? Theme.accent : Theme.secondary)
                }
                .buttonStyle(.plain)
                Text(inline(text))
                    .strikethrough(isDone, color: Theme.tertiary)
                    .foregroundStyle(isDone ? Theme.tertiary : Theme.text)
            }
            .padding(.leading, CGFloat(indent) * 14)
        case let .quote(text):
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1).fill(Theme.accent.opacity(0.7)).frame(width: 2)
                Text(inline(text)).italic().foregroundStyle(Theme.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        case let .code(code):
            Text(code)
                .font(.system(size: 11.5, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.black.opacity(0.25)))
                .padding(.vertical, 2)
        case .rule:
            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.vertical, 5)
        case let .paragraph(text):
            Text(inline(text))
        case .blank:
            Color.clear.frame(height: 4)
        }
    }

    private func item(indent: Int, marker: Text, text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            marker
            text
        }
        .padding(.leading, CGFloat(indent) * 14)
    }

    private func inline(_ source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
    }
}

struct MarkdownBlock: Identifiable {
    enum Kind {
        case heading(level: Int, text: String)
        case bullet(indent: Int, text: String)
        case numbered(indent: Int, number: String, text: String)
        case task(indent: Int, isDone: Bool, text: String)
        case quote(String)
        case code(String)
        case rule
        case paragraph(String)
        case blank
    }

    /// Index of the block's first line in the source text.
    let id: Int
    let kind: Kind

    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0
        while index < lines.count {
            let start = index
            if lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                var code: [String] = []
                index += 1
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[index])
                    index += 1
                }
                blocks.append(MarkdownBlock(id: start, kind: .code(code.joined(separator: "\n"))))
                index += 1
                continue
            }
            blocks.append(MarkdownBlock(id: start, kind: classify(lines[index])))
            index += 1
        }
        return blocks
    }

    private static func classify(_ line: String) -> Kind {
        let leading = line.prefix { $0 == " " || $0 == "\t" }
        let indent = leading.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) } / 2
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty { return .blank }
        if ["---", "***", "___"].contains(trimmed) { return .rule }

        let hashes = trimmed.prefix { $0 == "#" }.count
        if (1...6).contains(hashes), trimmed.dropFirst(hashes).first == " " {
            return .heading(level: hashes, text: String(trimmed.dropFirst(hashes + 1)))
        }

        if trimmed == ">" || trimmed.hasPrefix("> ") {
            return .quote(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
        }

        if let marker = trimmed.first, "-*+".contains(marker), trimmed.dropFirst().first == " " {
            let rest = String(trimmed.dropFirst(2))
            let box = rest.prefix(3).lowercased()
            if box == "[ ]" || box == "[x]", rest.count == 3 || rest.dropFirst(3).first == " " {
                return .task(indent: indent, isDone: box == "[x]", text: String(rest.dropFirst(3)).trimmingCharacters(in: .whitespaces))
            }
            return .bullet(indent: indent, text: rest)
        }

        let digits = trimmed.prefix { $0.isNumber }
        if !digits.isEmpty {
            let rest = trimmed.dropFirst(digits.count)
            if rest.hasPrefix(". ") || rest.hasPrefix(") ") {
                return .numbered(indent: indent, number: digits + ".", text: String(rest.dropFirst(2)))
            }
        }

        return .paragraph(trimmed)
    }
}
