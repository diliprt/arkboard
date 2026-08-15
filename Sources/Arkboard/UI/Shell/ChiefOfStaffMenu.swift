import AppKit
import SwiftUI

enum FocusedSelection {
    private static var lastHighlight = ""

    static func currentText() -> String {
        if let live = liveSelection(), !live.isEmpty {
            lastHighlight = live
            return live
        }
        return lastHighlight
    }

    private static func liveSelection() -> String? {
        if let responder = NSApp.keyWindow?.firstResponder {
            if let textView = responder as? NSTextView {
                let text = selectedString(in: textView)
                if !text.isEmpty { return text }
            }
            if let field = responder as? NSTextField, let editor = field.currentEditor() as? NSTextView {
                let text = selectedString(in: editor)
                if !text.isEmpty { return text }
            }
            if let view = responder as? NSView,
               let editor = view.window?.fieldEditor(false, for: nil) as? NSTextView {
                let text = selectedString(in: editor)
                if !text.isEmpty { return text }
            }
        }
        guard let root = NSApp.keyWindow?.contentView else { return nil }
        return firstSelectedText(in: root)
    }

    private static func firstSelectedText(in view: NSView) -> String? {
        if let textView = view as? NSTextView {
            let text = selectedString(in: textView)
            if !text.isEmpty { return text }
        }
        for child in view.subviews {
            if let found = firstSelectedText(in: child) { return found }
        }
        return nil
    }

    private static func selectedString(in textView: NSTextView) -> String {
        let range = textView.selectedRange()
        guard range.location != NSNotFound, range.length > 0 else { return "" }
        let text = textView.string as NSString
        guard NSMaxRange(range) <= text.length else { return "" }
        return text.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ChiefOfStaffMenuButton: View {
    @Environment(AppStore.self) private var store
    var selectedText: String? = nil

    var body: some View {
        Button(ChiefOfStaffCopy.menuTitle) {
            store.beginChiefHandoff(selectedText: selectedText ?? FocusedSelection.currentText())
        }
    }
}

struct ChiefOfStaffContextMenu: ViewModifier {
    func body(content: Content) -> some View {
        content.contextMenu {
            let selected = FocusedSelection.currentText()
            if !selected.isEmpty {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(selected, forType: .string)
                }
            }
            ChiefOfStaffMenuButton(selectedText: selected)
        }
    }
}

extension View {
    func chiefOfStaffContextMenu() -> some View {
        modifier(ChiefOfStaffContextMenu())
    }
}

@MainActor
final class ChiefOfStaffMenuBridge: NSObject {
    static let shared = ChiefOfStaffMenuBridge()
    var onPick: ((String) -> Void)?
    private var installed = false

    func install(onPick: @escaping (String) -> Void) {
        self.onPick = onPick
        guard !installed else { return }
        installed = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBeganTracking(_:)),
            name: NSMenu.didBeginTrackingNotification,
            object: nil
        )
    }

    @objc private func menuBeganTracking(_ notification: Notification) {
        guard let menu = notification.object as? NSMenu else { return }
        inject(into: menu)
    }

    private func inject(into menu: NSMenu) {
        if menu === NSApp.mainMenu { return }
        if menu.supermenu === NSApp.mainMenu { return }
        if menu.items.contains(where: { $0.title == ChiefOfStaffCopy.menuTitle }) { return }
        let titles = menu.items.map(\.title)
        guard titles.contains(where: { $0 == "Copy" || $0.hasPrefix("Copy") }) else { return }
        menu.addItem(.separator())
        let item = NSMenuItem(
            title: ChiefOfStaffCopy.menuTitle,
            action: #selector(chatWithChiefOfStaff(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = FocusedSelection.currentText()
        menu.addItem(item)
    }

    @objc func chatWithChiefOfStaff(_ sender: Any?) {
        let selected = (sender as? NSMenuItem)?.representedObject as? String ?? FocusedSelection.currentText()
        onPick?(selected)
    }
}
