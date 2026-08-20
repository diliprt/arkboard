import AppKit
import SwiftUI

/// SwiftUI `.defaultSize` is ignored once AppKit has a restoration record.
/// Saved Settings frames on this Mac have opened as a sliver (~57×98) or
/// under the 560 pt minimum (504×613). Clamp the real `NSWindow`.
enum SettingsWindowSizing {
    static let autosaveName = "com_apple_SwiftUI_Settings_window"
    private static var enlargeAttempts = 0
    private static var isClamping = false

    static func isTooSmall(width: CGFloat, height: CGFloat) -> Bool {
        width + 0.5 < Metrics.settingsMin.width
            || height + 0.5 < Metrics.settingsMin.height
    }

    static func isSettings(_ window: NSWindow) -> Bool {
        if window.frameAutosaveName == autosaveName { return true }
        if window.identifier?.rawValue == autosaveName { return true }
        if window.title.localizedCaseInsensitiveContains("Settings") { return true }
        return false
    }

    static func clampOpenWindows() {
        for window in NSApp.windows where isSettings(window) {
            clamp(window)
        }
    }

    static func install() {
        Observer.shared.start()
        clampOpenWindows()
    }

    static func clamp(_ window: NSWindow, knownSettings: Bool = false) {
        guard knownSettings || isSettings(window) else { return }
        guard !isClamping else { return }
        isClamping = true
        defer { isClamping = false }

        window.contentMinSize = Metrics.settingsMin
        window.minSize = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: Metrics.settingsMin)
        ).size

        let content = window.contentRect(forFrameRect: window.frame)
        guard isTooSmall(width: window.frame.width, height: window.frame.height)
            || isTooSmall(width: content.width, height: content.height)
        else {
            enlargeAttempts = 0
            return
        }
        guard enlargeAttempts < 16 else { return }
        enlargeAttempts += 1

        // Stop AppKit from re-applying the sliver while we enlarge.
        let savedAutosave = window.frameAutosaveName
        if !savedAutosave.isEmpty {
            window.setFrameAutosaveName("")
        }

        window.setContentSize(Metrics.settingsDefault)

        var frame = window.frame
        if isTooSmall(width: frame.width, height: frame.height) {
            frame.size = Metrics.settingsDefault
            window.setFrame(constrained: frame)
        }

        let contentAfter = window.contentRect(forFrameRect: window.frame)
        if isTooSmall(width: window.frame.width, height: window.frame.height)
            || isTooSmall(width: contentAfter.width, height: contentAfter.height) {
            let size = window.frameRect(
                forContentRect: NSRect(origin: .zero, size: Metrics.settingsDefault)
            ).size
            var next = window.frame
            next.size = size
            window.setFrame(constrained: next)
        }

        if !savedAutosave.isEmpty {
            window.setFrameAutosaveName(savedAutosave)
            window.saveFrame(usingName: savedAutosave)
        }
    }

    private final class Observer {
        static let shared = Observer()
        private var tokens: [NSObjectProtocol] = []
        private var started = false

        func start() {
            guard !started else { return }
            started = true
            DispatchQueue.main.async {
                SettingsWindowSizing.clampOpenWindows()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                SettingsWindowSizing.clampOpenWindows()
            }
            let center = NotificationCenter.default
            let handler: (Notification) -> Void = { _ in
                SettingsWindowSizing.clampOpenWindows()
            }
            tokens = [
                center.addObserver(
                    forName: NSWindow.didBecomeKeyNotification,
                    object: nil,
                    queue: .main,
                    using: handler
                ),
                center.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: nil,
                    queue: .main,
                    using: { note in
                        guard let window = note.object as? NSWindow,
                              SettingsWindowSizing.isSettings(window)
                        else { return }
                        SettingsWindowSizing.clamp(window)
                    }
                ),
                center.addObserver(
                    forName: NSApplication.didFinishRestoringWindowsNotification,
                    object: nil,
                    queue: .main,
                    using: handler
                ),
                center.addObserver(
                    forName: NSApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main,
                    using: handler
                ),
            ]
        }
    }
}

private extension NSWindow {
    func setFrame(constrained frame: NSRect) {
        var next = frame
        if let visible = (screen ?? NSScreen.main)?.visibleFrame {
            if next.maxX > visible.maxX { next.origin.x = visible.maxX - next.width }
            if next.maxY > visible.maxY { next.origin.y = visible.maxY - next.height }
            if next.minX < visible.minX { next.origin.x = visible.minX }
            if next.minY < visible.minY { next.origin.y = visible.minY }
        }
        setFrame(next, display: true, animate: false)
    }
}

struct SettingsWindowClamp: NSViewRepresentable {
    func makeNSView(context: Context) -> SettingsWindowClampView {
        SettingsWindowClampView()
    }

    func updateNSView(_ view: SettingsWindowClampView, context: Context) {
        view.scheduleClamp()
    }
}

/// Hosted behind the Settings form so it shares that scene's `NSWindow`.
/// Not hidden: a hidden view often never gets `window`. Clicks fall through.
final class SettingsWindowClampView: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: 1, height: 1) }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        SettingsWindowSizing.install()
        if let window {
            SettingsWindowSizing.clamp(window, knownSettings: true)
        }
    }

    func scheduleClamp() {
        SettingsWindowSizing.install()
        if let window {
            SettingsWindowSizing.clamp(window, knownSettings: true)
        }
    }
}
