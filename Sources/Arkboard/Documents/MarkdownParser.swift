import Foundation

enum MarkdownInline: Hashable, Sendable {
    case text(String)
    case strong([MarkdownInline])
    case emphasis([MarkdownInline])
    case strike([MarkdownInline])
    case code(String)
    case link(text: [MarkdownInline], destination: String)
}

enum MarkdownBlock: Hashable, Sendable {
    case heading(level: Int, text: String, inlines: [MarkdownInline], anchor: String)
    case paragraph([MarkdownInline])
    case bulletList([[MarkdownInline]], nested: [[[MarkdownInline]]])
    case orderedList([[MarkdownInline]], nested: [[[MarkdownInline]]])
    case code(language: String?, text: String)
    case quote([MarkdownInline])
    case table(headers: [[MarkdownInline]], rows: [[[MarkdownInline]]])
    case rule
    case image(alt: String, destination: String)
}

enum MarkdownParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [MarkdownBlock] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var body: [String] = []
                index += 1
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    body.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(.code(language: language.isEmpty ? nil : language, text: body.joined(separator: "\n")))
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.rule)
                index += 1
                continue
            }

            if let heading = parseHeading(trimmed) {
                blocks.append(heading)
                index += 1
                continue
            }

            if trimmed.hasPrefix("> ") || trimmed == ">" {
                var quoteLines: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    if current.hasPrefix("> ") {
                        quoteLines.append(String(current.dropFirst(2)))
                    } else if current == ">" {
                        quoteLines.append("")
                    } else {
                        break
                    }
                    index += 1
                }
                blocks.append(.quote(parseInlines(quoteLines.joined(separator: " "))))
                continue
            }

            if trimmed.hasPrefix("|") && trimmed.contains("|") {
                var tableLines: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    if current.hasPrefix("|") {
                        tableLines.append(current)
                        index += 1
                    } else {
                        break
                    }
                }
                if let table = parseTable(tableLines) {
                    blocks.append(table)
                    continue
                }
            }

            if isBullet(trimmed) {
                let parsed = parseList(lines: lines, start: index, ordered: false)
                blocks.append(.bulletList(parsed.items, nested: parsed.nested))
                index = parsed.next
                continue
            }

            if isOrdered(trimmed) {
                let parsed = parseList(lines: lines, start: index, ordered: true)
                blocks.append(.orderedList(parsed.items, nested: parsed.nested))
                index = parsed.next
                continue
            }

            if let image = parseStandaloneImage(trimmed) {
                blocks.append(image)
                index += 1
                continue
            }

            var paragraph: [String] = [trimmed]
            index += 1
            while index < lines.count {
                let current = lines[index].trimmingCharacters(in: .whitespaces)
                if current.isEmpty || current.hasPrefix("#") || current.hasPrefix("```") || current.hasPrefix("|") || current.hasPrefix("> ") || isBullet(current) || isOrdered(current) || current == "---" {
                    break
                }
                paragraph.append(current)
                index += 1
            }
            blocks.append(.paragraph(parseInlines(paragraph.joined(separator: " "))))
        }
        return blocks
    }

    static func headings(in markdown: String) -> [HeadingRef] {
        headings(in: markdown, suppressingTitle: nil)
    }

    /// Headings for the Contents outline. When the document opens with an H1
    /// that only repeats the title the reader can already see, that heading is
    /// not rendered, so it must not be listed either — an outline row that
    /// jumps to nothing is worse than a missing row.
    static func headings(in markdown: String, suppressingTitle title: String?) -> [HeadingRef] {
        let blocks = parse(markdown)
        let drop = repeatsTitle(blocks, title: title) ? 1 : 0
        return blocks.dropFirst(drop).compactMap { block in
            if case let .heading(level, text, _, anchor) = block {
                return HeadingRef(level: level, title: text, anchor: anchor)
            }
            return nil
        }
    }

    static func repeatsTitle(_ markdown: String, title: String?) -> Bool {
        repeatsTitle(parse(markdown), title: title)
    }

    /// True when the first block is a level-1 heading saying the same thing as
    /// `title`. The window title bar and the tab rail already name the page;
    /// printing it a third time at the top of the prose is a second headline.
    static func repeatsTitle(_ blocks: [MarkdownBlock], title: String?) -> Bool {
        guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard case let .heading(level, text, _, _) = blocks.first, level == 1 else { return false }
        return matchesTitle(text, title)
    }

    /// `Decisions & questions` and a document titled `Decisions` are the same
    /// page as far as a reader is concerned, so compare on words, not glyphs.
    static func matchesTitle(_ heading: String, _ title: String) -> Bool {
        let left = comparableTitle(heading)
        let right = comparableTitle(title)
        guard !left.isEmpty, !right.isEmpty else { return false }
        return left == right || left.hasPrefix(right) || right.hasPrefix(left)
    }

    private static func comparableTitle(_ text: String) -> String {
        let lowered = text.lowercased()
        let kept = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : Character(" ")
        }
        return String(kept)
            .split(separator: " ")
            .filter { $0 != "and" }
            .joined(separator: " ")
    }

    static func lead(beforeFirstH2 markdown: String) -> String {
        var collected: [String] = []
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") { break }
            collected.append(String(line))
        }
        return collected.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func firstSentence(_ markdown: String) -> String {
        let stripped = markdown
            .replacingOccurrences(of: "^#+\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = stripped.range(of: ". ") {
            return String(stripped[..<range.upperBound]).trimmingCharacters(in: .whitespaces)
        }
        return stripped
    }

    /// Card copy next to the project name. Drops a leading name so "Arkboard Arkboard is…" does not ship.
    static func cardSummary(markdown: String?, name: String, fallback: String) -> String {
        let raw: String
        if let markdown, !markdown.isEmpty {
            let sentence = firstSentence(markdown)
            raw = sentence.isEmpty ? fallback : sentence
        } else {
            raw = fallback
        }
        let stripped = asSentence(withoutNamePrefix(raw, name: name))
        return stripped.isEmpty ? asSentence(withoutNamePrefix(fallback, name: name)) : stripped
    }

    /// Dropping the project name off `Arkboard is Origin Ark Studio's board`
    /// leaves `is Origin Ark Studio's board`, which starts mid-sentence. Drop
    /// the stranded copula too and open on a capital, so the card reads as a
    /// line someone wrote rather than the tail of one.
    static func asSentence(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return result }
        for copula in ["is ", "are ", "was ", "were "] where result.lowercased().hasPrefix(copula) {
            result = String(result.dropFirst(copula.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }
        guard let first = result.first, first.isLowercase else { return result }
        return result.replacingCharacters(in: ...result.startIndex, with: String(first).uppercased())
    }

    static func withoutNamePrefix(_ text: String, name: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else { return result }
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "—–-:,"))
        while result.lowercased().hasPrefix(prefix.lowercased()) {
            let rest = result.dropFirst(prefix.count)
            guard let first = rest.first else { break }
            guard String(first).rangeOfCharacter(from: separators) != nil else { break }
            result = rest.trimmingCharacters(in: separators)
        }
        return result
    }

    static func slug(_ text: String) -> String {
        let lowered = text.lowercased()
        let scalars = lowered.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" ? Character($0) : Character(" ") }
        return String(scalars)
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    static func parseInlines(_ text: String) -> [MarkdownInline] {
        parseInlineSequence(text)
    }

    // MARK: - Blocks

    private static func parseHeading(_ line: String) -> MarkdownBlock? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        for character in line {
            if character == "#" { level += 1 } else { break }
        }
        guard (1...6).contains(level), line.count > level, line[line.index(line.startIndex, offsetBy: level)] == " " else {
            return nil
        }
        let text = String(line.dropFirst(level + 1)).trimmingCharacters(in: .whitespaces)
        return .heading(level: level, text: text, inlines: parseInlines(text), anchor: slug(text))
    }

    private static func isBullet(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ")
    }

    private static func isOrdered(_ line: String) -> Bool {
        guard let dot = line.firstIndex(of: ".") else { return false }
        let number = line[..<dot]
        return !number.isEmpty && number.allSatisfy(\.isNumber) && line[dot...].hasPrefix(". ")
    }

    private static func parseList(lines: [String], start: Int, ordered: Bool) -> (items: [[MarkdownInline]], nested: [[[MarkdownInline]]], next: Int) {
        var items: [[MarkdownInline]] = []
        var nested: [[[MarkdownInline]]] = []
        var index = start
        while index < lines.count {
            let raw = lines[index]
            let indent = raw.prefix { $0 == " " }.count
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if indent >= 2 && (isBullet(trimmed) || isOrdered(trimmed)) && !items.isEmpty {
                var children: [[MarkdownInline]] = nested.last ?? []
                children.append(parseInlines(listText(trimmed, ordered: isOrdered(trimmed))))
                if nested.isEmpty {
                    nested = Array(repeating: [], count: items.count - 1)
                }
                if nested.count == items.count - 1 {
                    nested.append(children)
                } else {
                    nested[items.count - 1] = children
                }
                index += 1
                continue
            }
            if ordered ? isOrdered(trimmed) : isBullet(trimmed) {
                items.append(parseInlines(listText(trimmed, ordered: ordered)))
                nested.append([])
                index += 1
                continue
            }
            break
        }
        return (items, nested, index)
    }

    private static func listText(_ line: String, ordered: Bool) -> String {
        if ordered, let dot = line.firstIndex(of: ".") {
            return String(line[line.index(dot, offsetBy: 2)...])
        }
        return String(line.dropFirst(2))
    }

    private static func parseTable(_ lines: [String]) -> MarkdownBlock? {
        guard lines.count >= 2 else { return nil }
        let rows = lines.map { line -> [String] in
            var cells = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            if cells.first == "" { cells.removeFirst() }
            if cells.last == "" { cells.removeLast() }
            return cells
        }
        guard rows.count >= 2, rows[1].allSatisfy({ $0.allSatisfy { $0 == "-" || $0 == ":" } }) else { return nil }
        let headers = rows[0].map { parseInlines($0) }
        let body = rows.dropFirst(2).map { $0.map { parseInlines($0) } }
        return .table(headers: headers, rows: Array(body))
    }

    private static func parseStandaloneImage(_ line: String) -> MarkdownBlock? {
        let pattern = /^!\[(.*?)\]\((.*?)\)$/
        guard let match = line.wholeMatch(of: pattern) else { return nil }
        return .image(alt: String(match.1), destination: String(match.2))
    }

    // MARK: - Inlines

    private static func parseInlineSequence(_ text: String) -> [MarkdownInline] {
        var result: [MarkdownInline] = []
        var remaining = Substring(text)
        while !remaining.isEmpty {
            if remaining.hasPrefix("`") {
                let rest = remaining.dropFirst()
                if let end = rest.firstIndex(of: "`") {
                    result.append(.code(String(rest[..<end])))
                    remaining = rest[rest.index(after: end)...]
                    continue
                }
            }
            if remaining.hasPrefix("![") {
                if let parsed = takeLink(remaining, image: true) {
                    result.append(.link(text: parseInlineSequence(parsed.text), destination: parsed.destination))
                    remaining = parsed.rest
                    continue
                }
            }
            if remaining.hasPrefix("[") {
                if let parsed = takeLink(remaining, image: false) {
                    result.append(.link(text: parseInlineSequence(parsed.text), destination: parsed.destination))
                    remaining = parsed.rest
                    continue
                }
            }
            if remaining.hasPrefix("**") || remaining.hasPrefix("__") {
                let marker = remaining.prefix(2)
                if let parsed = takeDelimited(remaining, marker: String(marker)) {
                    result.append(.strong(parseInlineSequence(parsed.inner)))
                    remaining = parsed.rest
                    continue
                }
            }
            if remaining.hasPrefix("~~") {
                if let parsed = takeDelimited(remaining, marker: "~~") {
                    result.append(.strike(parseInlineSequence(parsed.inner)))
                    remaining = parsed.rest
                    continue
                }
            }
            if remaining.hasPrefix("*") || remaining.hasPrefix("_") {
                let marker = String(remaining.prefix(1))
                if let parsed = takeDelimited(remaining, marker: marker) {
                    result.append(.emphasis(parseInlineSequence(parsed.inner)))
                    remaining = parsed.rest
                    continue
                }
            }
            let next = remaining.firstIndex(where: { $0 == "`" || $0 == "[" || $0 == "*" || $0 == "_" || $0 == "~" }) ?? remaining.endIndex
            if next == remaining.startIndex {
                result.append(.text(String(remaining.prefix(1))))
                remaining = remaining.dropFirst()
            } else {
                result.append(.text(String(remaining[..<next])))
                remaining = remaining[next...]
            }
        }
        return mergeText(result)
    }

    private static func takeDelimited(_ text: Substring, marker: String) -> (inner: String, rest: Substring)? {
        guard text.hasPrefix(marker) else { return nil }
        let rest = text.dropFirst(marker.count)
        guard let end = rest.range(of: marker) else { return nil }
        return (String(rest[..<end.lowerBound]), rest[end.upperBound...])
    }

    private static func takeLink(_ text: Substring, image: Bool) -> (text: String, destination: String, rest: Substring)? {
        var work = text
        if image {
            guard work.hasPrefix("![") else { return nil }
            work = work.dropFirst(2)
        } else {
            guard work.hasPrefix("[") else { return nil }
            work = work.dropFirst()
        }
        guard let close = work.firstIndex(of: "]") else { return nil }
        let label = String(work[..<close])
        var after = work[work.index(after: close)...]
        guard after.hasPrefix("("), let end = after.firstIndex(of: ")") else { return nil }
        let destination = String(after[after.index(after: after.startIndex)..<end])
        return (label, destination, after[after.index(after: end)...])
    }

    private static func mergeText(_ items: [MarkdownInline]) -> [MarkdownInline] {
        var merged: [MarkdownInline] = []
        for item in items {
            if case let .text(text) = item, case let .text(previous)? = merged.last {
                merged[merged.count - 1] = .text(previous + text)
            } else {
                merged.append(item)
            }
        }
        return merged
    }
}
