import AppKit
import SwiftUI

struct CodeBlockView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var language: String?
    var text: String
    var hue: Hue
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                if let language {
                    Text(language)
                        .font(type.caption)
                        .foregroundStyle(StudioColor.secondary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(type.mono)
                    .foregroundStyle(StudioColor.primary)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(StudioColor.editor, in: RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
                .stroke(hue.color(for: scheme).opacity(0.18), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .font(type.caption)
                .buttonStyle(.plain)
                .padding(8)
            }
        }
        .onHover { hovering = $0 }
    }
}

struct TableBlockView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var headers: [[MarkdownInline]]
    var rows: [[[MarkdownInline]]]
    var hue: Hue
    var onLink: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, cell in
                        InlineText(inlines: cell, hue: hue, onLink: onLink)
                            .font(type.bodyStrong)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(minWidth: 80, alignment: .leading)
                    }
                }
                .background(StudioColor.tableHeader(hue, scheme: scheme))
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    Divider().overlay(StudioColor.hairline)
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            InlineText(inlines: cell, hue: hue, onLink: onLink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .frame(minWidth: 80, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}
