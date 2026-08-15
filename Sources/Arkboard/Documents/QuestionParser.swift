import Foundation

struct ParsedDecision: Hashable, Sendable {
    var heading: String
    var level: Int
    var anchor: String
    var body: String
    var isOpen: Bool
    var isLocked: Bool
}

enum QuestionParser {
    static func parse(_ markdown: String) -> [ParsedDecision] {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var items: [ParsedDecision] = []
        var current: (level: Int, heading: String, body: [String])?
        func flush() {
            guard let current else { return }
            let heading = current.heading
            let open = isOpen(heading)
            let locked = isLocked(heading)
            guard open || locked else { return }
            items.append(
                ParsedDecision(
                    heading: heading,
                    level: current.level,
                    anchor: MarkdownParser.slug(heading),
                    body: current.body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                    isOpen: open,
                    isLocked: locked
                )
            )
        }
        for line in lines {
            if let heading = headingLine(line) {
                flush()
                current = (heading.level, heading.text, [])
            } else if current != nil {
                current?.body.append(line)
            }
        }
        flush()
        return items
    }

    static func openQuestions(in markdown: String) -> [ParsedDecision] {
        parse(markdown).filter(\.isOpen)
    }

    static func isOpen(_ heading: String) -> Bool {
        let trimmed = heading.trimmingCharacters(in: .whitespaces)
        return trimmed.lowercased().hasPrefix("open") || trimmed.hasSuffix("?")
    }

    static func isLocked(_ heading: String) -> Bool {
        let trimmed = heading.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed.hasPrefix("locked") || trimmed.hasPrefix("decided")
    }

    private static func headingLine(_ line: String) -> (level: Int, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        var level = 0
        for character in trimmed {
            if character == "#" { level += 1 } else { break }
        }
        guard level == 2 || level == 3 else { return nil }
        guard trimmed.count > level, trimmed[trimmed.index(trimmed.startIndex, offsetBy: level)] == " " else {
            return nil
        }
        return (level, String(trimmed.dropFirst(level + 1)).trimmingCharacters(in: .whitespaces))
    }
}
