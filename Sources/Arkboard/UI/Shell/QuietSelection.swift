import AppKit
import SwiftUI

/// Keeps the sidebar's selected row in the system's *unemphasized* selection —
/// the quiet grey — whether or not the sidebar has focus.
///
/// `NSColor.unemphasizedSelectedContentBackgroundColor` is a colour you draw
/// with, not a mode you can switch on: its own documentation says to use it
/// "when the window containing the content is not key, or when the view
/// containing the content does not have key focus". Which style a row gets is
/// decided by `NSTableRowView.emphasized`, and that follows first-responder
/// status. So tinting a `List` does nothing to the highlight — `tint` reaches
/// the row's icons and stops there, which is why the sidebar still went
/// accent-blue and turned the mark and the key white the moment it took focus.
///
/// Finder, Mail and Music get their permanently quiet sidebars by keeping those
/// lists from becoming first responder. AppKit spells that `refusesFirstResponder`;
/// SwiftUI does not surface it, so this reaches the table view `List` builds and
/// sets it there. Nothing is drawn and no colour is invented: the row keeps the
/// system's unemphasized rendering, so the project mark, the name and the key
/// all keep their own colours instead of being forced to white.
struct QuietSelection: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let probe = ProbeView()
        probe.translatesAutoresizingMaskIntoConstraints = false
        return probe
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ProbeView)?.quieten()
    }

    /// A zero-size view whose only job is to find the enclosing table.
    final class ProbeView: NSView {
        override var intrinsicContentSize: NSSize { .zero }
        override var isOpaque: Bool { false }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            quieten()
        }

        func quieten() {
            guard let table = enclosingTableView else { return }
            guard !table.refusesFirstResponder else { return }
            table.refusesFirstResponder = true
            // If it already holds focus, hand it back so the row redraws quiet.
            if let window = table.window, window.firstResponder === table {
                window.makeFirstResponder(window.contentView)
            }
        }

        private var enclosingTableView: NSTableView? {
            var node: NSView? = superview
            while let current = node {
                if let table = current as? NSTableView { return table }
                node = current.superview
            }
            return nil
        }
    }
}

/// Sets the enclosing table row's accessibility title so VoiceOver and AX
/// Press can find a project by name + key. SwiftUI labels on the HStack do
/// not become `AXRow.title`.
struct SidebarRowName: NSViewRepresentable {
    var name: String

    func makeNSView(context: Context) -> ProbeView {
        let probe = ProbeView()
        probe.translatesAutoresizingMaskIntoConstraints = false
        probe.name = name
        return probe
    }

    func updateNSView(_ view: ProbeView, context: Context) {
        view.name = name
        view.apply()
    }

    final class ProbeView: NSView {
        var name = ""
        override var intrinsicContentSize: NSSize { .zero }
        override var isOpaque: Bool { false }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }

        func apply() {
            guard !name.isEmpty else { return }
            var node: NSView? = superview
            var table: NSTableView?
            while let current = node {
                if let row = current as? NSTableRowView {
                    Self.name(row, name)
                    return
                }
                if let cell = current as? NSTableCellView {
                    Self.name(cell, name)
                    if let row = cell.superview as? NSTableRowView {
                        Self.name(row, name)
                    }
                }
                if table == nil { table = current as? NSTableView }
                node = current.superview
            }
            guard let table else { return }
            let local = table.convert(CGPoint(x: bounds.midX, y: bounds.midY), from: self)
            let index = table.row(at: local)
            guard index >= 0 else { return }
            if let row = table.rowView(atRow: index, makeIfNecessary: false) {
                Self.name(row, name)
            }
            if let cell = table.view(atColumn: 0, row: index, makeIfNecessary: false) {
                Self.name(cell, name)
            }
        }

        private static func name(_ view: NSView, _ name: String) {
            view.setAccessibilityLabel(name)
            view.setAccessibilityTitle(name)
        }
    }
}

extension View {
    /// Attach to a sidebar row so the list it lives in keeps the unemphasized
    /// selection style in every state.
    func quietSelection() -> some View {
        background(QuietSelection().frame(width: 0, height: 0).accessibilityHidden(true))
    }

    func sidebarRowName(_ name: String) -> some View {
        background(SidebarRowName(name: name).frame(width: 0, height: 0).accessibilityHidden(true))
    }
}
