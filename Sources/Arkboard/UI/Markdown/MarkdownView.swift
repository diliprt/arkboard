import SwiftUI

struct MarkdownView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var markdown: String
    var hue: Hue
    var onLink: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: type.blockGap) {
            ForEach(Array(MarkdownParser.parse(markdown).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: Metrics.proseMax, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case let .heading(level, _, inlines, anchor):
            InlineText(inlines: inlines, hue: hue, onLink: onLink)
                .font(headingFont(level))
                .padding(.top, level <= 2 ? type.headingAir : type.deepHeadingAir)
                .id(anchor)
        case let .paragraph(inlines):
            InlineText(inlines: inlines, hue: hue, onLink: onLink)
                .font(type.body)
                .lineSpacing(type.lineSpacing)
                .foregroundStyle(StudioColor.primary)
        case let .bulletList(items, nested):
            list(items, nested: nested, ordered: false)
        case let .orderedList(items, nested):
            list(items, nested: nested, ordered: true)
        case let .code(language, text):
            CodeBlockView(language: language, text: text, hue: hue)
        case let .quote(inlines):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(hue.color(for: scheme))
                    .frame(width: 3)
                InlineText(inlines: inlines, hue: hue, onLink: onLink)
                    .font(type.body)
                    .foregroundStyle(StudioColor.secondary)
            }
        case let .table(headers, rows):
            TableBlockView(headers: headers, rows: rows, hue: hue, onLink: onLink)
        case .rule:
            Divider().overlay(StudioColor.hairline).padding(.vertical, 12)
        case let .image(alt, destination):
            MarkdownImage(alt: alt, destination: destination)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return type.display
        case 2: return type.title
        case 3: return type.heading
        default: return type.subheading
        }
    }

    private func list(_ items: [[MarkdownInline]], nested: [[[MarkdownInline]]], ordered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if ordered {
                        Text("\(index + 1).")
                            .font(type.mono)
                            .foregroundStyle(hue.color(for: scheme))
                            .frame(width: Metrics.markerColumn, alignment: .trailing)
                    } else {
                        Text("•")
                            .foregroundStyle(hue.color(for: scheme))
                            .frame(width: Metrics.markerColumn, alignment: .center)
                    }
                    InlineText(inlines: item, hue: hue, onLink: onLink)
                        .font(type.body)
                }
                if index < nested.count {
                    ForEach(Array(nested[index].enumerated()), id: \.offset) { _, child in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•")
                                .foregroundStyle(hue.color(for: scheme))
                                .frame(width: Metrics.markerColumn, alignment: .center)
                            InlineText(inlines: child, hue: hue, onLink: onLink)
                                .font(type.body)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
        }
    }
}

struct InlineText: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var inlines: [MarkdownInline]
    var hue: Hue
    var onLink: (String) -> Void

    var body: some View {
        inlines.reduce(Text("")) { partial, inline in
            partial + render(inline)
        }
    }

    private func render(_ inline: MarkdownInline) -> Text {
        switch inline {
        case let .text(string):
            return Text(string)
        case let .strong(children):
            return children.reduce(Text("")) { $0 + render($1) }.fontWeight(.semibold)
        case let .emphasis(children):
            return children.reduce(Text("")) { $0 + render($1) }.italic()
        case let .strike(children):
            return children.reduce(Text("")) { $0 + render($1) }.strikethrough()
        case let .code(string):
            return Text(string).font(type.mono)
        case let .link(text, destination):
            return text.reduce(Text("")) { $0 + render($1) }
                .foregroundColor(hue.color(for: scheme))
                .underline()
        }
    }
}

struct MarkdownImage: View {
    @Environment(\.typography) private var type
    var alt: String
    var destination: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
                .fill(StudioColor.card)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(StudioColor.tertiary)
                }
            if !alt.isEmpty {
                Text(alt).font(type.caption).foregroundStyle(StudioColor.secondary)
            }
        }
        .frame(maxHeight: 420)
    }
}

struct ClampedMarkdown: View {
    var markdown: String
    var hue: Hue
    var lines: Int = 4

    var body: some View {
        MarkdownView(markdown: markdown, hue: hue)
            .lineLimit(lines)
            .clipped()
    }
}
