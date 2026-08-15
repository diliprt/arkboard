import AppKit
import SwiftUI

struct StudioRoot: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var typography: Typography
    var appearance: AppearancePreference

    func body(content: Content) -> some View {
        content
            .environment(\.typography, typography)
            .preferredColorScheme(appearance == .system ? nil : (appearance == .dark ? .dark : .light))
    }
}

struct Chip: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var text: String
    var hue: Hue
    var mono: Bool = false

    var body: some View {
        Text(text)
            .font(mono ? type.mono : type.caption)
            .foregroundStyle(hue.color(for: scheme))
            .lineLimit(1)
            .padding(.horizontal, Metrics.chipX)
            .padding(.vertical, Metrics.chipY)
            .background(StudioColor.chipFill(hue, scheme: scheme), in: Capsule())
    }
}

struct ActorChip: View {
    var name: String

    var body: some View {
        Chip(text: name, hue: Hue.actorHue(for: name))
    }
}

struct ProjectDot: View {
    var hex: String
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: size, height: size)
    }
}

struct ProjectIcon: View {
    var project: Project
    var imageData: Data? = nil
    var size: CGFloat = 22

    var body: some View {
        Group {
            if let imageData, let image = NSImage(data: imageData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: project.icon.isEmpty ? ProjectMark.symbols[0] : project.icon)
                    .font(.system(size: size * 0.52, weight: .semibold))
                    .foregroundStyle(Color(hex: project.color))
            }
        }
        .frame(width: size, height: size)
        .background(
            Color(hex: project.color).opacity(0.16),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityLabel(project.name)
    }
}

struct CardSurface<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var hue: Hue
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Metrics.cardPad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StudioColor.card, in: RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
                    .stroke(StudioColor.cardStroke(hue, scheme: scheme), lineWidth: 1)
            )
    }
}

struct ProseColumn<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GridColumn<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: Metrics.gridMax, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : usedWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > bounds.width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(size)
            )
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

struct FadingHScroll<Content: View>: View {
    var fadeWidth: CGFloat = Metrics.tabFade
    @ViewBuilder var content: Content
    @State private var offset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0

    private var overflows: Bool { contentWidth > viewportWidth + 0.5 }
    private var showLeading: Bool { overflows && offset > 0.5 }
    private var showTrailing: Bool { overflows && offset + viewportWidth < contentWidth - 0.5 }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: FadingContentWidthKey.self, value: geo.size.width)
                            .preference(key: FadingMinXKey.self, value: geo.frame(in: .named("fading-hscroll")).minX)
                    }
                )
        }
        .coordinateSpace(name: "fading-hscroll")
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: FadingViewportWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(FadingContentWidthKey.self) { contentWidth = $0 }
        .onPreferenceChange(FadingViewportWidthKey.self) { viewportWidth = $0 }
        .onPreferenceChange(FadingMinXKey.self) { offset = -$0 }
        .mask {
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [showLeading ? .clear : .black, .black],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeWidth)
                Color.black
                LinearGradient(
                    colors: [.black, showTrailing ? .clear : .black],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeWidth)
            }
        }
    }
}

private struct FadingContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct FadingViewportWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct FadingMinXKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
