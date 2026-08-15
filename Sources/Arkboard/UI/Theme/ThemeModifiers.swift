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
            .frame(maxWidth: Metrics.proseMax, alignment: .leading)
            .frame(maxWidth: .infinity)
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
