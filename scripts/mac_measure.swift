// Arkboard's Mac measures. Run this before Critique, not after.
//
// A still cannot show a jump. This reads the numbers a still hides: where a
// tab's first line sits under the rail, what colour the selected sidebar row
// is while the sidebar has focus, and whether a pane prints its own title
// under the window's.
//
// It measures a *running* Debug build. It does not launch Xcode, does not
// build, does not create worktrees, and does not take a shot set.
//
//     swiftc -O -o /tmp/arkboard-measure scripts/mac_measure.swift
//     /tmp/arkboard-measure
//
// or just `./scripts/mac_measure.sh`, which does both.
//
// Exit codes:
//   0  measured, every gate passed
//   1  measured, a gate failed — the numbers drifted
//   2  could not measure — app not running, or a permission is missing
//
// Requires Accessibility and Screen Recording permission for the terminal that
// runs it (System Settings → Privacy & Security). Without them there is no
// measurement to report, which is exit 2, not a pass.

import AppKit
import ApplicationServices
import ImageIO

// MARK: - Contract

enum Contract {
    static let bundleID = "studio.originark.arkboard"

    /// Sibling tabs share one content origin. Two points of slack absorbs
    /// rounding between backing scales; 52 was the regression that made this
    /// script exist, when Mockups opened 52pt below Design.
    static let originTolerance: CGFloat = 2

    /// The rail is pinned. It should not move at all; the same slack applies.
    static let railTolerance: CGFloat = 2

    /// Above this saturation a selected row is a tinted fill rather than the
    /// system's unemphasized grey.
    static let selectionSaturationCeiling: CGFloat = 0.35

    /// A project mark that has been forced to white loses its colour. Below
    /// this the mark is no longer readable as itself.
    static let markSaturationFloor: CGFloat = 0.08

    /// Contents floats over the trailing edge; ignore anything inside this much
    /// of the pane's right edge when looking for the document's first line.
    static let trailingOverlayAllowance: CGFloat = 300

    /// The document's first line is left-aligned. Anything past this fraction
    /// of the pane is chrome, not the start of the body.
    static let bodyLeadingFraction: CGFloat = 0.6

    /// Wide enough to clear the sidebar, so its rows are never mistaken for
    /// content in the document column.
    static let sidebarAllowance: CGFloat = 240

    static let measuredTabs = ["Design", "Mockups", "Design"]
}

// MARK: - Reporting

struct Report {
    var samples: [(tab: String, railY: CGFloat, bodyY: CGFloat)] = []
    var selectionSaturation: CGFloat?
    var markSaturation: CGFloat?
    var selectionOK: Bool?
    var titleOK: Bool?
    var failures: [String] = []

    func emit() {
        var lines: [String] = []
        for (index, sample) in samples.enumerated() {
            lines.append("  \"step_\(index + 1)\": { \"tab\": \"\(sample.tab)\", \"rail_y\": \(round(sample.railY)), \"body_y\": \(round(sample.bodyY)) }")
        }
        lines.append("  \"rail_y\": [\(samples.map { String(format: "%.0f", $0.railY) }.joined(separator: ", "))]")
        lines.append("  \"body_y\": [\(samples.map { String(format: "%.0f", $0.bodyY) }.joined(separator: ", "))]")
        lines.append("  \"selection_saturation\": \(selectionSaturation.map { String(format: "%.3f", $0) } ?? "null")")
        lines.append("  \"mark_saturation\": \(markSaturation.map { String(format: "%.3f", $0) } ?? "null")")
        lines.append("  \"selection_ok\": \(selectionOK.map(String.init) ?? "null")")
        lines.append("  \"title_ok\": \(titleOK.map(String.init) ?? "null")")
        lines.append("  \"passed\": \(failures.isEmpty)")
        print("{")
        print(lines.joined(separator: ",\n"))
        print("}")
        for failure in failures {
            FileHandle.standardError.write(Data(("FAIL  " + failure + "\n").utf8))
        }
    }
}

func bail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("arkboard-measure: " + message + "\n").utf8))
    exit(2)
}

// MARK: - Accessibility helpers

func axAttribute<T>(_ element: AXUIElement, _ name: String) -> T? {
    var raw: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &raw) == .success else { return nil }
    return raw as? T
}

func axChildren(_ element: AXUIElement) -> [AXUIElement] {
    axAttribute(element, kAXChildrenAttribute) ?? []
}

func axRole(_ element: AXUIElement) -> String {
    axAttribute(element, kAXRoleAttribute) ?? ""
}

/// Whatever this element says it is, in the order AppKit tends to fill in.
func axLabel(_ element: AXUIElement) -> String {
    for name in [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute] {
        if let text: String = axAttribute(element, name), !text.isEmpty {
            return text
        }
    }
    return ""
}

func axFrame(_ element: AXUIElement) -> CGRect? {
    var positionRef: CFTypeRef?
    var sizeRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
          AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
          let position = positionRef, let size = sizeRef,
          CFGetTypeID(position) == AXValueGetTypeID(),
          CFGetTypeID(size) == AXValueGetTypeID()
    else { return nil }

    var point = CGPoint.zero
    var extent = CGSize.zero
    // swiftlint:disable:next force_cast
    guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
          // swiftlint:disable:next force_cast
          AXValueGetValue(size as! AXValue, .cgSize, &extent)
    else { return nil }
    return CGRect(origin: point, size: extent)
}

struct Node {
    var element: AXUIElement
    var role: String
    var label: String
    var frame: CGRect
}

/// Flatten the window once. Depth is capped because a SwiftUI tree that has
/// gone wrong should time out rather than hang a build.
func flatten(_ root: AXUIElement, depth: Int = 0, into nodes: inout [Node]) {
    guard depth < 40 else { return }
    for child in axChildren(root) {
        if let frame = axFrame(child), frame.width > 0, frame.height > 0 {
            nodes.append(Node(element: child, role: axRole(child), label: axLabel(child), frame: frame))
        }
        flatten(child, depth: depth + 1, into: &nodes)
    }
}

// MARK: - Screen sampling

/// The app's frontmost on-screen window, straight from the window server.
func windowNumberAndBounds(pid: pid_t) -> (number: CGWindowID, bounds: CGRect)? {
    guard let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }
    for entry in raw {
        guard let owner = entry[kCGWindowOwnerPID as String] as? pid_t, owner == pid,
              let number = entry[kCGWindowNumber as String] as? CGWindowID,
              let boundsDict = entry[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
              bounds.width > 200, bounds.height > 200
        else { continue }
        return (number, bounds)
    }
    return nil
}

struct Bitmap {
    var pixels: [UInt8]
    var width: Int
    var height: Int
    var scale: CGFloat

    func averageHSB(in rect: CGRect) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat)? {
        let x0 = max(0, Int(rect.minX * scale))
        let y0 = max(0, Int(rect.minY * scale))
        let x1 = min(width, Int(rect.maxX * scale))
        let y1 = min(height, Int(rect.maxY * scale))
        guard x1 > x0, y1 > y0 else { return nil }

        var reds = 0.0, greens = 0.0, blues = 0.0, count = 0.0
        for y in stride(from: y0, to: y1, by: 1) {
            for x in stride(from: x0, to: x1, by: 1) {
                let offset = (y * width + x) * 4
                guard offset + 2 < pixels.count else { continue }
                reds += Double(pixels[offset])
                greens += Double(pixels[offset + 1])
                blues += Double(pixels[offset + 2])
                count += 1
            }
        }
        guard count > 0 else { return nil }
        let colour = NSColor(
            srgbRed: CGFloat(reds / count / 255),
            green: CGFloat(greens / count / 255),
            blue: CGFloat(blues / count / 255),
            alpha: 1
        )
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        colour.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue, saturation, brightness)
    }
}

/// Capture the window and keep it as straight RGBA so pixels can be read back.
///
/// `CGWindowListCreateImage` is unavailable in the macOS 26 SDK, so this shells
/// out to `screencapture` for the one window and reads the file back. That is
/// still a measurement, not a shot set: one window, one temp file, deleted on
/// the way out, and nothing written anywhere the repo can see.
func capture(window: CGWindowID, bounds: CGRect) -> Bitmap? {
    let path = NSTemporaryDirectory() + "arkboard-measure-\(getpid()).png"
    defer { try? FileManager.default.removeItem(atPath: path) }

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    // -l<id> one window, -o no shadow, -x no shutter sound.
    task.arguments = ["-l\(window)", "-o", "-x", path]
    do { try task.run() } catch { return nil }
    task.waitUntilExit()

    guard task.terminationStatus == 0,
          let data = FileManager.default.contents(atPath: path),
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }

    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else { return nil }
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drew else { return nil }
    let scale = bounds.width > 0 ? CGFloat(width) / bounds.width : 1
    return Bitmap(pixels: pixels, width: width, height: height, scale: scale)
}

// MARK: - Measuring

func press(_ element: AXUIElement) {
    AXUIElementPerformAction(element, kAXPressAction as CFString)
    // One runloop turn plus a beat: enough for a layout pass, short enough that
    // a hung pane fails the build rather than stalling it.
    RunLoop.current.run(until: Date().addingTimeInterval(0.45))
}

func tabControl(named name: String, in nodes: [Node]) -> Node? {
    nodes.first { pressableRoles.contains($0.role) && $0.label == name }
}

let tabNames = Set(["Design", "Architecture", "Mockups", "Decisions & questions", "Issues", "Timeline"])
let pressableRoles: Set<String> = ["AXButton", "AXCheckBox", "AXRadioButton", "AXMenuButton"]

/// The rail's Y is the top of the row of tab controls.
func railBounds(in nodes: [Node]) -> (y: CGFloat, bottom: CGFloat)? {
    let tabs = nodes.filter { tabNames.contains($0.label) && pressableRoles.contains($0.role) }
    guard tabs.count >= 3, let top = tabs.map(\.frame.minY).min(), let bottom = tabs.map(\.frame.maxY).max() else {
        return nil
    }
    return (top, bottom)
}

/// The first line of the tab body: the topmost piece of content below the rail,
/// in the left part of the document column. Leaves only — a container's frame is
/// the section's top, which is exactly what hides an origin shift.
func bodyTop(in nodes: [Node], railBottom: CGFloat, window: CGRect) -> CGFloat? {
    let textual: Set<String> = ["AXStaticText", "AXTextArea", "AXLink"]
    let visual: Set<String> = ["AXImage", "AXButton", "AXCheckBox"]
    let rightLimit = min(
        window.maxX - Contract.trailingOverlayAllowance,
        window.minX + window.width * Contract.bodyLeadingFraction
    )
    let candidates = nodes.filter { node in
        guard node.frame.minY >= railBottom - 1 else { return false }
        guard node.frame.minX >= window.minX + Contract.sidebarAllowance else { return false }
        guard node.frame.minX < rightLimit else { return false }
        if textual.contains(node.role) { return !node.label.isEmpty }
        // A filled gallery opens on a thumbnail, which carries no label.
        return visual.contains(node.role)
    }
    return candidates.map(\.frame.minY).min()
}

/// A pane must not print the window's own title again below the title bar.
func secondTitleBand(in nodes: [Node], windowTitle: String, railBottom: CGFloat, window: CGRect) -> Node? {
    guard !windowTitle.isEmpty else { return nil }
    return nodes.first {
        $0.role == "AXStaticText"
            && $0.label == windowTitle
            && $0.frame.minY >= railBottom - 1
            && $0.frame.minX >= window.minX + Contract.sidebarAllowance
    }
}

func sidebarRows(in nodes: [Node]) -> [Node] {
    nodes.filter { $0.role == "AXRow" }
}

/// Everything a row says about itself, including its descendants — an AXRow
/// usually carries no label of its own.
func rowLabels(_ row: AXUIElement) -> Set<String> {
    var nodes: [Node] = []
    flatten(row, into: &nodes)
    return Set(nodes.map(\.label).filter { !$0.isEmpty })
}

/// A pinned project, never a destination.
///
/// The mark floor is a check on a *project's* mark keeping its colour on a
/// selected row. Portfolio and Timeline are SF symbols in section hues at the
/// size of a line of text: sampling one of those and asking it to clear the
/// floor measures the wrong thing and fails an app that is behaving.
func pinnedProjectRow(in nodes: [Node]) -> Node? {
    let destinations: Set<String> = ["Portfolio", "Timeline", "Onboarding"]
    return sidebarRows(in: nodes).first { row in
        let labels = rowLabels(row.element).union(row.label.isEmpty ? [] : [row.label])
        return !labels.isEmpty && labels.isDisjoint(with: destinations)
    }
}

// MARK: - Run

let running = NSRunningApplication.runningApplications(withBundleIdentifier: Contract.bundleID)
guard let app = running.first else {
    bail("""
    Arkboard is not running.
    Launch the Debug build first (./scripts/run.sh), then run this again.
    This script measures a running app; it does not build or launch one.
    """)
}

guard AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary) else {
    bail("""
    No Accessibility permission.
    Grant it to the terminal running this script in
    System Settings → Privacy & Security → Accessibility, then run it again.
    """)
}

app.activate(options: [])
RunLoop.current.run(until: Date().addingTimeInterval(0.6))

let axApp = AXUIElementCreateApplication(app.processIdentifier)
guard let windows: [AXUIElement] = axAttribute(axApp, kAXWindowsAttribute), let window = windows.first else {
    bail("Arkboard is running but has no window the accessibility API can see.")
}
let windowTitle: String = axAttribute(window, kAXTitleAttribute) ?? ""
guard let windowFrame = axFrame(window) else {
    bail("Could not read the Arkboard window frame.")
}

var report = Report()

// 1. Design → Mockups → Design. One content origin, one still rail.
for name in Contract.measuredTabs {
    var nodes: [Node] = []
    flatten(window, into: &nodes)
    guard let control = tabControl(named: name, in: nodes) else {
        bail("Could not find the \(name) tab. Open a project before measuring.")
    }
    press(control.element)

    var after: [Node] = []
    flatten(window, into: &after)
    guard let rail = railBounds(in: after) else {
        bail("Could not find the tab rail after pressing \(name).")
    }
    guard let body = bodyTop(in: after, railBottom: rail.bottom, window: windowFrame) else {
        bail("Could not find any content under the rail on \(name).")
    }
    report.samples.append((tab: name, railY: rail.y, bodyY: body))
}

if let railFirst = report.samples.first?.railY {
    let drift = report.samples.map { abs($0.railY - railFirst) }.max() ?? 0
    if drift > Contract.railTolerance {
        report.failures.append("tab rail moved \(String(format: "%.0f", drift))pt across \(Contract.measuredTabs.joined(separator: " → "))")
    }
}

if let bodyFirst = report.samples.first?.bodyY {
    let drift = report.samples.map { abs($0.bodyY - bodyFirst) }.max() ?? 0
    if drift > Contract.originTolerance {
        let seen = report.samples.map { "\($0.tab) \(String(format: "%.0f", $0.bodyY))" }.joined(separator: ", ")
        report.failures.append("tab bodies do not share one origin: \(seen) — \(String(format: "%.0f", drift))pt apart")
    }
}

// 2. A second in-page title band.
do {
    var nodes: [Node] = []
    flatten(window, into: &nodes)
    let railBottom = railBounds(in: nodes)?.bottom ?? windowFrame.minY
    let band = secondTitleBand(in: nodes, windowTitle: windowTitle, railBottom: railBottom, window: windowFrame)
    report.titleOK = band == nil
    if let band {
        report.failures.append("pane prints the window title again at y \(String(format: "%.0f", band.frame.minY)) — one title row")
    }
}

// 3. The selected sidebar row, while the sidebar has focus.
do {
    var nodes: [Node] = []
    flatten(window, into: &nodes)
    guard let row = pinnedProjectRow(in: nodes) else {
        bail("""
        Could not find a pinned project in the sidebar.
        The selection check samples a project's row, because the mark floor is
        about a project mark keeping its colour. Pin a project and run again.
        """)
    }
    press(row.element)

    guard let (number, bounds) = windowNumberAndBounds(pid: app.processIdentifier) else {
        bail("Could not find the Arkboard window in the window server.")
    }
    guard let bitmap = capture(window: number, bounds: bounds) else {
        bail("""
        No Screen Recording permission, so the selected row cannot be sampled.
        Grant it to the terminal running this script in
        System Settings → Privacy & Security → Screen Recording, then run it again.
        """)
    }

    var afterPress: [Node] = []
    flatten(window, into: &afterPress)
    let selected = pinnedProjectRow(in: afterPress) ?? row
    let local = CGRect(
        x: selected.frame.minX - bounds.minX,
        y: selected.frame.minY - bounds.minY,
        width: selected.frame.width,
        height: selected.frame.height
    )

    // The fill, sampled clear of the mark on the left and the key on the right.
    let fill = local.insetBy(dx: local.width * 0.36, dy: local.height * 0.3)
    // The mark's own tile, at the leading edge of the row.
    let mark = CGRect(x: local.minX + 8, y: local.minY + local.height * 0.25,
                      width: 16, height: max(4, local.height * 0.5))

    if let fillHSB = bitmap.averageHSB(in: fill) {
        report.selectionSaturation = fillHSB.saturation
        let tinted = fillHSB.saturation > Contract.selectionSaturationCeiling
        report.selectionOK = !tinted
        if tinted {
            report.failures.append("selected row is a tinted fill (saturation \(String(format: "%.2f", fillHSB.saturation))) — it must be the system's unemphasized grey while the sidebar has focus")
        }
    }
    if let markHSB = bitmap.averageHSB(in: mark) {
        report.markSaturation = markHSB.saturation
        if markHSB.saturation < Contract.markSaturationFloor {
            report.selectionOK = false
            report.failures.append("project mark lost its colour on the selected row (saturation \(String(format: "%.2f", markHSB.saturation))) — the row content must not be forced white")
        }
    }
}

report.emit()
exit(report.failures.isEmpty ? 0 : 1)
