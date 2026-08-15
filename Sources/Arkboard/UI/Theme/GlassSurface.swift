import SwiftUI

/// Liquid Glass is the navigation layer: the sidebar, the window toolbar, the
/// project tab rail, and the Contents inspector. The document body stays solid
/// and readable and never takes a glass surface.
///
/// Arkboard still deploys to macOS 14, so every Tahoe API here sits behind an
/// availability check with a system-material fallback. The `compiler` check
/// keeps the file buildable on toolchains whose SDK predates these symbols.
extension View {
    /// A navigation bar that floats over content: system material carrying the
    /// section wash, so the rail keeps its identity without an opaque
    /// `windowBackgroundColor` slab underneath — that slab is what blocks glass.
    @ViewBuilder
    func navigationBarSurface(tint: Color) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.background(tint).glassEffect(.regular, in: .rect)
        } else {
            self.background(tint).background(.bar)
        }
        #else
        self.background(tint).background(.bar)
        #endif
    }

    /// Edge-to-edge glass alongside the document: the inspector treatment.
    @ViewBuilder
    func inspectorSurface() -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect)
        } else {
            self.background(.regularMaterial)
        }
        #else
        self.background(.regularMaterial)
        #endif
    }

    /// A bar pinned to the bottom of a column. On Tahoe it joins the scroll edge
    /// effect and inherits the column's own glass rather than painting a second
    /// material over it.
    @ViewBuilder
    func columnBottomBar<Bar: View>(_ bar: Bar) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.safeAreaBar(edge: .bottom) { bar }
        } else {
            self.safeAreaInset(edge: .bottom) { bar.background(.bar) }
        }
        #else
        self.safeAreaInset(edge: .bottom) { bar.background(.bar) }
        #endif
    }

    /// A filter or tab capsule on the navigation layer. The shape, the hit area,
    /// and the selected state are the system's; the call site supplies only the
    /// label and the tint.
    func filterCapsule() -> some View {
        self.toggleStyle(.button).buttonStyle(.accessoryBar)
    }

    /// The document pane's own fill. It runs edge to edge beneath the floating
    /// sidebar while the scrolling content stays inside the safe area, so the
    /// page has no hard seam against the glass.
    ///
    /// A background extension effect is the other option here, but it mirrors
    /// and blurs whatever is adjacent — right for a hero image, wrong for a
    /// column of prose, which would read as ghost text behind the sidebar.
    func paneBackground(_ fill: Color) -> some View {
        self.background { fill.ignoresSafeArea() }
    }
}

/// Corner radii that nest inside their container instead of each surface
/// guessing its own. An inner radius is the container radius less the inset, so
/// the curves share a centre.
enum Concentric {
    static func inner(of container: CGFloat, inset: CGFloat) -> CGFloat {
        max(2, container - inset)
    }

    static func shape(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
