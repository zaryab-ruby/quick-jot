import AppKit
import SwiftUI

/// Plain-text editor backed by NSTextView (transparent background, native undo,
/// find bar, and automatic list continuation).
struct NoteEditor: NSViewRepresentable {
    static let textInset = NSSize(width: 8, height: 4)
    static let lineFragmentPadding: CGFloat = 5

    @Binding var text: String
    let noteID: UUID
    var onEscape: () -> Void
    var onAttach: (NSTextView) -> Void

    static var textAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        return [.font: Theme.editorFont, .foregroundColor: Theme.textNS, .paragraphStyle: paragraph]
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        let textView = EditorTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        textView.onAttach = onAttach
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = Self.lineFragmentPadding
        textView.textContainerInset = Self.textInset

        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.insertionPointColor = Theme.accentNS
        textView.selectedTextAttributes = [.backgroundColor: Theme.accentNS.withAlphaComponent(0.45)]

        textView.delegate = context.coordinator
        textView.replaceAllText(with: text)
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? EditorTextView else { return }

        if context.coordinator.noteID != noteID {
            // Switched scratchpads: swap contents, drop the old undo history, caret at the end.
            context.coordinator.noteID = noteID
            textView.replaceAllText(with: text)
            textView.undoManager?.removeAllActions()
            let end = (text as NSString).length
            textView.setSelectedRange(NSRange(location: end, length: 0))
            textView.scrollRangeToVisible(NSRange(location: end, length: 0))
        } else if textView.string != text {
            // Changed from outside the editor (cleared, checkbox toggled in preview, …).
            let selection = textView.selectedRange()
            textView.replaceAllText(with: text)
            let length = (text as NSString).length
            let location = min(selection.location, length)
            textView.setSelectedRange(NSRange(location: location, length: min(selection.length, length - location)))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteEditor
        var noteID: UUID

        init(parent: NoteEditor) {
            self.parent = parent
            self.noteID = parent.noteID
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                return ListContinuation.insertNewline(in: textView)
            default:
                return false
            }
        }
    }
}

final class EditorTextView: NSTextView {
    var onAttach: ((NSTextView) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { onAttach?(self) }
    }

    /// Replaces the whole text without registering undo or notifying the delegate.
    func replaceAllText(with text: String) {
        let attributes = NoteEditor.textAttributes
        textStorage?.setAttributedString(NSAttributedString(string: text, attributes: attributes))
        typingAttributes = attributes
    }
}

/// Pressing Return on a list line starts the next item (`- `, `* `, `1. `, `- [ ] `);
/// pressing it on an empty item ends the list.
enum ListContinuation {
    private static let pattern = try! NSRegularExpression(
        pattern: #"^([ \t]*)(?:([-*+])|(\d+)([.)]))([ \t]+)(\[[ xX]\][ \t]+)?"#
    )

    static func insertNewline(in textView: NSTextView) -> Bool {
        let selection = textView.selectedRange()
        let string = textView.string as NSString
        var lineRange = string.lineRange(for: NSRange(location: selection.location, length: 0))
        if lineRange.length > 0, string.character(at: NSMaxRange(lineRange) - 1) == 0x0A {
            lineRange.length -= 1
        }
        let line = string.substring(with: lineRange) as NSString
        guard
            let match = pattern.firstMatch(in: line as String, range: NSRange(location: 0, length: line.length)),
            selection.location - lineRange.location >= match.range.length
        else { return false }

        if line.length == match.range.length {
            // Empty item: remove the marker instead of adding another one.
            let marker = NSRange(location: lineRange.location, length: match.range.length)
            guard textView.shouldChangeText(in: marker, replacementString: "") else { return true }
            textView.replaceCharacters(in: marker, with: "")
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
            return true
        }

        var next = line.substring(with: match.range(at: 1))
        if match.range(at: 3).location != NSNotFound, let number = Int(line.substring(with: match.range(at: 3))) {
            next += "\(number + 1)" + line.substring(with: match.range(at: 4))
        } else {
            next += line.substring(with: match.range(at: 2))
        }
        next += line.substring(with: match.range(at: 5))
        if match.range(at: 6).location != NSNotFound { next += "[ ] " }

        textView.insertText("\n" + next, replacementRange: selection)
        return true
    }
}
