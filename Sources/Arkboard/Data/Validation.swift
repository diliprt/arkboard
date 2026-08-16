import Foundation

enum ValidationError: LocalizedError, Equatable {
    case emptyTitle
    case emptyComment
    case emptyNote
    case invalidStatus(String)
    case invalidPriority(String)
    case invalidState(String)
    case invalidHealth(String)
    case invalidMilestoneStatus(String)
    case invalidDate
    case invalidProjectKey
    case unknownRelatedIssue(String)
    case unknownDependency(String)
    case selfDependency
    case dependencyCycle
    case noteTooLong
    case pathEscape
    case missingProject
    case missingIssue
    case missingMilestone
    case missingCapability
    case missingDocument
    case duplicateKey(String)
    case invalidGitHubRepo

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Title cannot be empty"
        case .emptyComment:
            return "Comment cannot be empty"
        case .emptyNote:
            return "Note cannot be empty"
        case .invalidStatus(let value):
            return "Unknown status '\(value)'. Use backlog, todo, in_progress, done, or canceled."
        case .invalidPriority(let value):
            return "Unknown priority '\(value)'. Use none, low, medium, high, or urgent."
        case .invalidState(let value):
            return "Unknown state '\(value)'. Use not_started, building, or built."
        case .invalidHealth(let value):
            return "Unknown health '\(value)'. Use unknown, working, or not_working."
        case .invalidMilestoneStatus(let value):
            return "Unknown milestone status '\(value)'. Use planned, in_progress, done, or missed."
        case .invalidDate:
            return "Invalid date"
        case .invalidProjectKey:
            return "Project key must be 2 to 6 characters of A–Z and 0–9."
        case .unknownRelatedIssue(let identifier):
            return "Unknown related issue '\(identifier)'."
        case .unknownDependency(let id):
            return "Unknown milestone dependency '\(id)'."
        case .selfDependency:
            return "A milestone cannot depend on itself."
        case .dependencyCycle:
            return "Milestone dependencies cannot form a cycle."
        case .noteTooLong:
            return "Capability note must be 280 characters or fewer."
        case .pathEscape:
            return "Document path must stay inside product/."
        case .missingProject:
            return "Unknown project"
        case .missingIssue:
            return "Unknown issue"
        case .missingMilestone:
            return "Unknown milestone"
        case .missingCapability:
            return "Unknown capability"
        case .missingDocument:
            return "Unknown document"
        case .duplicateKey(let key):
            return "Project key '\(key)' is already in use."
        case .invalidGitHubRepo:
            return "GitHub repository must be owner/name."
        }
    }
}

enum Validation {
    static let identifierPattern = /^[A-Z][A-Z0-9]{1,5}-(C)?\d+$/

    static func collapseTitle(_ raw: String) throws -> String {
        let collapsed = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if collapsed.isEmpty { throw ValidationError.emptyTitle }
        return collapsed
    }

    static func requireBody(_ raw: String, empty: ValidationError) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw empty }
        return trimmed
    }

    static func capabilityNote(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 280 { throw ValidationError.noteTooLong }
        return trimmed
    }

    static func projectKey(_ raw: String) throws -> String {
        let filtered = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        let ascii = String(filtered.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
        let key = ascii.filter { ("A"..."Z").contains($0) || ("0"..."9").contains($0) }
        if key.count < 2 || key.count > 6 { throw ValidationError.invalidProjectKey }
        return key
    }

    /// `owner/name`. Empty becomes nil. A pasted github.com URL is accepted and reduced.
    static func githubRepo(_ raw: String?) throws -> String? {
        var value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }
        if let range = value.range(of: "github.com/", options: .caseInsensitive) {
            value = String(value[range.upperBound...])
        }
        if value.hasSuffix(".git") {
            value = String(value.dropLast(4))
        }
        if value.hasSuffix("/") {
            value.removeLast()
        }
        let parts = value.split(separator: "/").map(String.init)
        guard parts.count == 2 else { throw ValidationError.invalidGitHubRepo }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        for part in parts {
            guard !part.isEmpty, part.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
                throw ValidationError.invalidGitHubRepo
            }
        }
        return "\(parts[0])/\(parts[1])"
    }

    static func deriveKey(from name: String) -> String {
        let letters = name.uppercased().filter { ("A"..."Z").contains($0) || ("0"..."9").contains($0) }
        if letters.count >= 2 {
            return String(letters.prefix(6))
        }
        let padded = (letters + "PROJ").prefix(4)
        return String(padded)
    }

    static func labels(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in raw {
            let name = item.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !name.isEmpty, !seen.contains(name) else { continue }
            seen.insert(name)
            result.append(name)
        }
        return result
    }

    static func actor(_ raw: String?) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Agent" : trimmed
    }

    static func issueStatus(_ raw: String) throws -> IssueStatus {
        guard let value = IssueStatus(rawValue: raw) else { throw ValidationError.invalidStatus(raw) }
        return value
    }

    static func issuePriority(_ raw: String) throws -> IssuePriority {
        guard let value = IssuePriority(rawValue: raw) else { throw ValidationError.invalidPriority(raw) }
        return value
    }

    static func capabilityState(_ raw: String) throws -> CapabilityState {
        guard let value = CapabilityState(rawValue: raw) else { throw ValidationError.invalidState(raw) }
        return value
    }

    static func capabilityHealth(_ raw: String) throws -> CapabilityHealth {
        guard let value = CapabilityHealth(rawValue: raw) else { throw ValidationError.invalidHealth(raw) }
        return value
    }

    static func milestoneStatus(_ raw: String) throws -> MilestoneStatus {
        guard let value = MilestoneStatus(rawValue: raw) else { throw ValidationError.invalidMilestoneStatus(raw) }
        return value
    }

    static func date(_ raw: String) throws -> Date {
        if let iso = StudioISO8601.date(from: raw) { return iso }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        if let day = formatter.date(from: raw) {
            return day.addingTimeInterval(12 * 60 * 60)
        }
        throw ValidationError.invalidDate
    }

    static func optionalDate(_ raw: String?) throws -> Date? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return try date(raw)
    }

    static func studioIdentifiers(_ raw: [String]) throws -> [String] {
        try raw.map { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.wholeMatch(of: identifierPattern) != nil else {
                throw ValidationError.unknownRelatedIssue(trimmed)
            }
            return trimmed
        }
    }

    static func milestoneDependencies(_ raw: [String]) -> [String] {
        GanttDependencies.normalise(raw)
    }

    static func mentions(in body: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: #"@([A-Za-z][A-Za-z0-9_-]*)"#)
        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        let matches = regex?.matches(in: body, range: range) ?? []
        var seen = Set<String>()
        var names: [String] = []
        for match in matches {
            guard let nameRange = Range(match.range(at: 1), in: body) else { continue }
            let name = String(body[nameRange])
            if seen.insert(name).inserted {
                names.append(name)
            }
        }
        return names
    }

    static func activityKind(for body: String, hasMentions: Bool) -> ActivityKind {
        let lower = body.lowercased()
        if lower.contains("handoff") || lower.contains("hand off") || lower.contains("handing off") {
            return .handoff
        }
        if hasMentions { return .mention }
        return .note
    }

    static func commentKind(for body: String, hasMentions: Bool) -> ActivityKind {
        let lower = body.lowercased()
        if lower.contains("handoff") || lower.contains("hand off") || lower.contains("handing off") {
            return .handoff
        }
        if hasMentions { return .mention }
        return .comment
    }

    static func documentPath(_ raw: String) throws -> String {
        var path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.hasPrefix("/") { path.removeFirst() }
        guard path.hasPrefix("product/") else { throw ValidationError.pathEscape }
        let parts = path.split(separator: "/")
        if parts.contains("..") { throw ValidationError.pathEscape }
        return path
    }
}
