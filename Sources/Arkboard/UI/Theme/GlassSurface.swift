import SwiftUI

/// Liquid Glass is the navigation layer: the sidebar, the window toolbar, the
/// project tab rail, and the Contents inspector. The document body stays solid
/// and readable and never takes a glass surface.
///
/// Arkboard still deploys to macOS 14, so every Tahoe API here sits behind an
/// availability check with a system-material fallback. The `compiler` check
/// keeps the file buildable on toolchains whose SDK predates these symbols.
/// The 1pt line where a pane of glass meets what is under it.
///
/// Glass separates by translucency, which works when there is something behind
/// it worth seeing. In dark mode a frosted rail and a solid page can sit close
/// enough in value that the boundary disappears and the window reads as one
/// flat field — so the edge is drawn, once, at hairline weight. It is a line,
/// never a fill: a filled strip would be opaque paint on navigation.
struct GlassEdge: View {
    enum Axis { case horizontal, vertical }
    var axis: Axis

    init(_ axis: Axis) { self.axis = axis }

    var body: some View {
        Rectangle()
            .fill(StudioColor.hairline)
            .frame(
                width: axis == .vertical ? 1 : nil,
                height: axis == .horizontal ? 1 : nil
            )
            .accessibilityHidden(true)
    }
}

extension View {
    /// A navigation bar that floats over content: system material carrying the
    /// section wash, so the rail keeps its identity without an opaque
    /// `windowBackgroundColor` slab underneath — that slab is what blocks glass.
    @ViewBuilder
    func navigationBarSurface(tint: Color) -> some View {
        let edged = self.overlay(alignment: .bottom) { GlassEdge(.horizontal) }
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            edged.background(tint).glassEffect(.regular, in: .rect)
        } else {
            edged.background(tint).background(.bar)
        }
        #else
        edged.background(tint).background(.bar)
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

    /// A bar pinned to the bottom of a column, sitting on the column's own
    /// material with a hairline where it meets the list.
    ///
    /// It carries no material of its own on any release. A safe-area inset
    /// already reserves the space, so nothing scrolls under the bar and nothing
    /// needs to be obscured — and a second material inside a glass column is
    /// the legacy pattern the new design tells you to delete.
    @ViewBuilder
    func columnBottomBar<Bar: View>(_ bar: Bar) -> some View {
        let seated = bar.overlay(alignment: .top) { GlassEdge(.horizontal) }
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.safeAreaBar(edge: .bottom) { seated }
        } else {
            self.safeAreaInset(edge: .bottom) { seated }
        }
        #else
        self.safeAreaInset(edge: .bottom) { seated }
        #endif
    }

    /// A filter or tab capsule on the navigation layer. The shape, the hit area,
    /// and the selected state are the system's; the call site supplies only the
    /// label and the tint.
    func filterCapsule() -> some View {
        self.toggleStyle(.button).buttonStyle(.accessoryBar)
    }

    /// The document pane's own fill: an opaque reading field with the section
    /// wash over it. The sidebar beside it is frosted material, so the two
    /// columns read as slightly different surfaces — navigation is glass,
    /// content is solid. It runs edge to edge beneath the floating sidebar
    /// while the scrolling content stays inside the safe area, so the page has
    /// no hard seam against the glass.
    ///
    /// A background extension effect is the other option here, but it mirrors
    /// and blurs whatever is adjacent — right for a hero image, wrong for a
    /// column of prose, which would read as ghost text behind the sidebar.
    func paneBackground(_ wash: Color) -> some View {
        self.background {
            ZStack {
                StudioColor.documentField
                wash
            }
            .ignoresSafeArea()
        }
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
