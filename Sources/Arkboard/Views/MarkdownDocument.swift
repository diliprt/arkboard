import SwiftUI
import AppKit

struct MarkdownHeading: Identifiable, Hashable {
    var id: String
    var level: Int
    var title: String
}

struct MarkdownBlock: Identifiable, Hashable {
    var id: String
    var kind: Kind

    enum Kind: Hashable {
        case heading(level: Int, title: String)
        case paragraph(String)
        case list(ordered: Bool, items: [String])
        case code(language: String, text: String)
        case quote(String)
        case image(alt: String, url: String)
        case rule
    }
}

enum MarkdownDocument {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var blocks: [MarkdownBlock] = []
        var i = 0
        var serial = 0

        func nextId(_ hint: String = "b") -> String {
            serial += 1
            return "\(hint)-\(serial)"
        }

        while i < lines.count {
            let raw = lines[i]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                i += 1
                var body: [String] = []
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    body.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 }
                blocks.append(MarkdownBlock(id: nextId("code"), kind: .code(language: lang, text: body.joined(separator: "\n"))))
                continue
            }

            if let heading = headingMatch(trimmed) {
                let slug = Self.slug(heading.title)
                blocks.append(MarkdownBlock(id: "h-\(slug)-\(serial + 1)", kind: .heading(level: heading.level, title: heading.title)))
                serial += 1
                i += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                var quote: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard t.hasPrefix(">") else { break }
                    var q = String(t.dropFirst())
                    if q.hasPrefix(" ") { q = String(q.dropFirst()) }
                    quote.append(q)
                    i += 1
                }
                blocks.append(MarkdownBlock(id: nextId("q"), kind: .quote(quote.joined(separator: "\n"))))
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(MarkdownBlock(id: nextId("hr"), kind: .rule))
                i += 1
                continue
            }

            if let image = imageMatch(trimmed) {
                blocks.append(MarkdownBlock(id: nextId("img"), kind: .image(alt: image.alt, url: image.url)))
                i += 1
                continue
            }

            if isListItem(trimmed) {
                let ordered = trimmed.first?.isNumber == true
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard isListItem(t) else { break }
                    items.append(stripListMarker(t))
                    i += 1
                }
                blocks.append(MarkdownBlock(id: nextId("list"), kind: .list(ordered: ordered, items: items)))
                continue
            }

            if trimmed.isEmpty {
                i += 1
                continue
            }

            var para: [String] = []
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty || headingMatch(t) != nil || t.hasPrefix(">") || t.hasPrefix("```")
                    || t == "---" || t == "***" || isListItem(t) {
                    break
                }
                para.append(t)
                i += 1
            }
            blocks.append(MarkdownBlock(id: nextId("p"), kind: .paragraph(para.joined(separator: " "))))
        }
        return blocks
    }

    static func headings(in markdown: String) -> [MarkdownHeading] {
        parse(markdown).compactMap { block in
            if case .heading(let level, let title) = block.kind {
                return MarkdownHeading(id: block.id, level: level, title: title)
            }
            return nil
        }
    }

    static func firstParagraph(in markdown: String) -> String {
        for block in parse(markdown) {
            if case .paragraph(let text) = block.kind {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return ""
    }

    static func slug(_ title: String) -> String {
        let lowered = title.lowercased()
        var out = ""
        for ch in lowered {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
            } else if ch == " " || ch == "-" || ch == "_" {
                if out.last != "-" { out.append("-") }
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out.isEmpty ? "section" : out
    }

    private static func headingMatch(_ line: String) -> (level: Int, title: String)? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 } else { break }
        }
        guard (1...6).contains(level) else { return nil }
        let rest = line.dropFirst(level)
        guard rest.first == " " || rest.first == "\t" else { return nil }
        let title = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        return (level, title)
    }

    private static func imageMatch(_ line: String) -> (alt: String, url: String)? {
        // ![alt](url)
        guard line.hasPrefix("![") else { return nil }
        guard let close = line.firstIndex(of: "]"),
              close < line.endIndex,
              line[line.index(after: close)] == "(" ,
              let end = line.lastIndex(of: ")"),
              end > close else { return nil }
        let altStart = line.index(line.startIndex, offsetBy: 2)
        let alt = String(line[altStart..<close])
        let urlStart = line.index(close, offsetBy: 2)
        let url = String(line[urlStart..<end])
        return (alt, url)
    }

    private static func isListItem(_ line: String) -> Bool {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") { return true }
        var i = line.startIndex
        var sawDigit = false
        while i < line.endIndex, line[i].isNumber {
            sawDigit = true
            i = line.index(after: i)
        }
        guard sawDigit, i < line.endIndex, line[i] == "." else { return false }
        let next = line.index(after: i)
        return next < line.endIndex && line[next] == " "
    }

    private static func stripListMarker(_ line: String) -> String {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return String(line.dropFirst(2))
        }
        if let dot = line.firstIndex(of: ".") {
            let after = line.index(after: dot)
            if after < line.endIndex {
                return line[after...].trimmingCharacters(in: .whitespaces)
            }
        }
        return line
    }
}

struct MarkdownInlineText: View {
    let source: String

    var body: some View {
        if let attr = try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attr)
                .textSelection(.enabled)
        } else {
            Text(source)
                .textSelection(.enabled)
        }
    }
}

struct MarkdownPreview: View {
    let markdown: String
    var imageResolver: ((String) -> NSImage?)? = nil
    var accent: Color = StudioSection.overview.accent

    @Environment(\.appFontSize) private var fontSize
    @Environment(\.appFontFamily) private var fontFamily

    private var blocks: [MarkdownBlock] { MarkdownDocument.parse(markdown) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                blockView(block)
                    .id(block.id)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level, let title):
            MarkdownInlineText(source: title)
                .font(headingFont(level))
                .foregroundStyle(.primary)
                .padding(.top, level <= 2 ? 8 : 4)
        case .paragraph(let text):
            MarkdownInlineText(source: text)
                .appBodyFont()
                .fixedSize(horizontal: false, vertical: true)
        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(ordered ? "\(index + 1)." : "•")
                            .foregroundStyle(accent)
                            .frame(width: 18, alignment: .trailing)
                        MarkdownInlineText(source: item)
                            .appBodyFont()
                    }
                }
            }
        case .code(_, let text):
            Text(text)
                .font(AppTypography.mono(size: fontSize))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(accent.opacity(0.18))
                )
        case .quote(let text):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 3)
                MarkdownInlineText(source: text)
                    .appBodyFont()
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .image(let alt, let url):
            markdownImage(alt: alt, url: url)
        case .rule:
            Divider()
                .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func markdownImage(alt: String, url: String) -> some View {
        if let resolver = imageResolver, let ns = resolver(url) {
            Image(nsImage: ns)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel(alt.isEmpty ? "Image" : alt)
        } else if let remote = URL(string: url), let scheme = remote.scheme, scheme == "http" || scheme == "https" {
            AsyncImage(url: remote) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit().frame(maxHeight: 420)
                case .failure:
                    Text(alt.isEmpty ? url : alt).foregroundStyle(.secondary)
                default:
                    ProgressView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else if !alt.isEmpty {
            Text(alt)
                .foregroundStyle(.secondary)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        let base = fontSize.points
        switch level {
        case 1: return fontFamily.font(size: base + 10, weight: .semibold)
        case 2: return fontFamily.font(size: base + 6, weight: .semibold)
        case 3: return fontFamily.font(size: base + 3, weight: .semibold)
        default: return fontFamily.font(size: base + 1, weight: .medium)
        }
    }
}

struct DocumentPane: View {
    let markdown: String
    var accent: Color = StudioSection.overview.accent
    var imageResolver: ((String) -> NSImage?)? = nil
    var emptyTitle: String = "Nothing written yet"
    var emptyDetail: String = "A director pass will write this."

    @State private var jumpID: String?

    private var headings: [MarkdownHeading] {
        MarkdownDocument.headings(in: markdown)
    }

    var body: some View {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: "text.page")
            } description: {
                Text(emptyDetail)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(alignment: .top, spacing: 0) {
                if headings.count >= 2 {
                    outline
                        .frame(width: 188)
                    Divider()
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        MarkdownPreview(markdown: markdown, imageResolver: imageResolver, accent: accent)
                            .padding(24)
                            .frame(maxWidth: 820, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: jumpID) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newValue, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private var outline: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("On this page")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                ForEach(headings) { heading in
                    Button {
                        jumpID = heading.id
                    } label: {
                        Text(heading.title)
                            .font(.caption)
                            .foregroundStyle(heading.level <= 2 ? .primary : .secondary)
                            .multilineTextAlignment(.leading)
                            .padding(.leading, CGFloat(max(0, heading.level - 1)) * 10)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }
}
