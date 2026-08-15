import Foundation
import GRDB

enum IssueStatus: String, Codable, CaseIterable, Identifiable, DatabaseValueConvertible {
    case backlog, todo, in_progress, done, canceled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backlog: return "Backlog"
        case .todo: return "Todo"
        case .in_progress: return "In Progress"
        case .done: return "Done"
        case .canceled: return "Canceled"
        }
    }

    /// Compact chip label for dense Portfolio cards.
    var shortName: String {
        switch self {
        case .backlog: return "Backlog"
        case .todo: return "Todo"
        case .in_progress: return "In prog"
        case .done: return "Done"
        case .canceled: return "Canceled"
        }
    }

    var sortOrder: Int {
        switch self {
        case .backlog: return 0
        case .todo: return 1
        case .in_progress: return 2
        case .done: return 3
        case .canceled: return 4
        }
    }

    /// Open = not done and not canceled.
    var isOpen: Bool {
        switch self {
        case .done, .canceled: return false
        default: return true
        }
    }
}

enum IssuePriority: String, Codable, CaseIterable, Identifiable, DatabaseValueConvertible {
    case none, low, medium, high, urgent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "No priority"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }

    /// Compact label for filter chips.
    var chipName: String {
        switch self {
        case .none: return "No priority"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }

    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        case .none: return 4
        }
    }

    var symbolName: String {
        switch self {
        case .none: return "minus"
        case .low: return "arrow.down"
        case .medium: return "equal"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }
}

enum MilestoneStatus: String, Codable, CaseIterable, Identifiable, DatabaseValueConvertible {
    case planned, in_progress, done, missed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .planned: return "Planned"
        case .in_progress: return "In Progress"
        case .done: return "Done"
        case .missed: return "Missed"
        }
    }

    var tintHex: String {
        switch self {
        case .planned: return "#4EA7FC"
        case .in_progress: return "#C49200"
        case .done: return "#27AE60"
        case .missed: return "#EB5757"
        }
    }
}

enum ActivityAction: String, Codable, DatabaseValueConvertible {
    case created_issue
    case updated_issue
    case commented
    case created_project
    case created_milestone
    case updated_milestone
    case deleted_issue
    case restored_issue
    case linked_github_issue
    case unlinked_github_issue
    case created_github_issue
    case set_project_github_repo
    case told_team
    case created_requirement
    case updated_requirement

    var displayName: String {
        switch self {
        case .created_issue: return "created issue"
        case .updated_issue: return "updated issue"
        case .commented: return "commented"
        case .created_project: return "created project"
        case .created_milestone: return "created milestone"
        case .updated_milestone: return "updated milestone"
        case .deleted_issue: return "deleted issue"
        case .restored_issue: return "restored issue"
        case .linked_github_issue: return "linked GitHub issue"
        case .unlinked_github_issue: return "unlinked GitHub issue"
        case .created_github_issue: return "created GitHub issue"
        case .set_project_github_repo: return "set project GitHub repo"
        case .told_team: return "told the team"
        case .created_requirement: return "created requirement"
        case .updated_requirement: return "updated requirement"
        }
    }
}

enum ActivityKind: String, Codable, CaseIterable, Identifiable, DatabaseValueConvertible {
    case comment, mention, handoff, system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .comment: return "comment"
        case .mention: return "mention"
        case .handoff: return "handoff"
        case .system: return "system"
        }
    }
}

/// Top-level sidebar destinations. Monitor is the studio bird’s-eye; inbox is the Issues list.
enum SidebarSelection: Hashable, Identifiable {
    case monitor
    case portfolio
    case activity
    case inbox
    case project(String)

    var id: String {
        switch self {
        case .monitor: return "__monitor__"
        case .portfolio: return "__portfolio__"
        case .activity: return "__activity__"
        case .inbox: return "__inbox__"
        case .project(let id): return id
        }
    }
}

struct Workspace: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "workspace"
    var id: String
    var name: String
    var createdAt: Date
}

struct Project: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "project"
    var id: String
    var key: String
    var name: String
    var color: String
    var createdAt: Date
    var issueCounter: Int
    /// Optional default GitHub repo `owner/name` for issue link/create.
    var githubRepo: String? = nil
    /// Per-project counter for requirement identifiers (ARK-R1).
    var requirementCounter: Int = 0

    static let issues = hasMany(Issue.self)
    static let requirements = hasMany(Requirement.self)
}

struct Issue: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "issue"
    var id: String
    var identifier: String
    var projectId: String
    var title: String
    var descriptionMarkdown: String
    var status: IssueStatus
    var priority: IssuePriority
    var assigneeName: String?
    var estimatePoints: Int?
    var createdAt: Date
    var updatedAt: Date
    /// Set when status becomes `.done`; cleared when leaving done.
    var completedAt: Date?
    /// Soft-delete timestamp; nil means active.
    var deletedAt: Date?
    var orderInStatus: Double
    /// Linked GitHub issue number (within project.githubRepo or URL repo).
    var githubIssueNumber: Int? = nil
    /// Canonical GitHub issue URL when linked.
    var githubIssueUrl: String? = nil

    var isDeleted: Bool { deletedAt != nil }

    static let project = belongsTo(Project.self)
    static let comments = hasMany(Comment.self)
}

struct IssueTag: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "label"
    var id: String
    var name: String
    var color: String
}

struct IssueLabel: Codable, FetchableRecord, PersistableRecord, Hashable {
    static let databaseTableName = "issue_label"
    var issueId: String
    var labelId: String
}

struct Comment: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "comment"
    var id: String
    var issueId: String
    var bodyMarkdown: String
    var authorName: String
    var createdAt: Date
}

struct Activity: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "activity"
    var id: String
    var createdAt: Date
    var actor: String
    var action: String
    var issueId: String?
    var projectId: String?
    /// Optional pointer at a design requirement (Monitor center).
    var requirementId: String? = nil
    var summary: String
    /// Who this entry addresses. Single name or comma-separated multi-mention targets (e.g. "Ops, Comms").
    var targetActor: String?
    /// comment | mention | handoff | system
    var kind: String

    /// Distinct target actors parsed from `targetActor` (comma-separated).
    var targetActors: [String] {
        Self.parseTargets(targetActor)
    }

    static func parseTargets(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for part in raw.split(separator: ",") {
            let name = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            if seen.insert(key).inserted {
                result.append(name)
            }
        }
        return result
    }

    static func encodeTargets(_ targets: [String]) -> String? {
        let cleaned = parseTargets(targets.joined(separator: ", "))
        return cleaned.isEmpty ? nil : cleaned.joined(separator: ", ")
    }
}

struct Milestone: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "milestone"
    var id: String
    /// nil = studio-wide
    var projectId: String?
    var title: String
    var description: String
    var targetDate: Date
    var status: MilestoneStatus
    /// JSON array of issue identifiers, e.g. ["ARK-1","OPS-2"]
    var relatedIssueIdentifiers: String
    var createdAt: Date
    var updatedAt: Date

    var relatedIdentifiers: [String] {
        guard let data = relatedIssueIdentifiers.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return arr
    }

    static func encodeIdentifiers(_ ids: [String]) -> String {
        let cleaned = ids.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let data = try? JSONEncoder().encode(cleaned),
              let s = String(data: data, encoding: .utf8) else { return "[]" }
        return s
    }
}

struct IssueFilter: Equatable {
    var projectId: String? = nil
    var status: IssueStatus? = nil
    var priority: IssuePriority? = nil
    var query: String = ""
    var showCanceled: Bool = false
    /// When true, list soft-deleted (Archived) issues instead of active ones.
    var showDeleted: Bool = false

    var hasActiveFilters: Bool {
        status != nil
            || priority != nil
            || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || showCanceled
            || showDeleted
    }

    mutating func clearActiveFilters() {
        status = nil
        priority = nil
        query = ""
        showCanceled = false
        showDeleted = false
    }
}

/// Aggregates for the Portfolio bird's-eye view.
struct ProjectPortfolioCard: Identifiable, Hashable {
    var id: String { project.id }
    var project: Project
    var total: Int
    var byStatus: [IssueStatus: Int]
    var featureCount: Int
    var bugCount: Int
    var otherCount: Int

    var openCount: Int {
        IssueStatus.allCases.filter(\.isOpen).reduce(0) { $0 + (byStatus[$1] ?? 0) }
    }
}

struct PortfolioTotals: Hashable {
    var openWork: Int = 0
    var inProgress: Int = 0
    var bugs: Int = 0
    var features: Int = 0
}

/// Shared calendar strip event for Timeline.
enum TimelineEventKind: String {
    case milestone
    case issueCreated
    case issueDone
}

struct TimelineEvent: Identifiable, Hashable {
    var id: String
    var date: Date
    var title: String
    var subtitle: String
    var kind: TimelineEventKind
    var projectId: String?
    var projectKey: String?
    var projectColor: String
    var statusLabel: String?
    var issueId: String? = nil
    var milestoneId: String? = nil
}

enum RequirementImplementing: String, Codable, CaseIterable, Identifiable, DatabaseValueConvertible {
    case not_started, implementing, implemented

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .not_started: return "Not started"
        case .implementing: return "Implementing"
        case .implemented: return "Implemented"
        }
    }

    var tintHex: String {
        switch self {
        case .not_started: return "#8E8E93"
        case .implementing: return "#C49200"
        case .implemented: return "#27AE60"
        }
    }

    var next: RequirementImplementing {
        switch self {
        case .not_started: return .implementing
        case .implementing: return .implemented
        case .implemented: return .not_started
        }
    }
}

enum RequirementWorking: String, Codable, CaseIterable, Identifiable, DatabaseValueConvertible {
    case unknown, working, not_working

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .working: return "Working"
        case .not_working: return "Not working"
        }
    }

    var tintHex: String {
        switch self {
        case .unknown: return "#8E8E93"
        case .working: return "#27AE60"
        case .not_working: return "#EB5757"
        }
    }

    var next: RequirementWorking {
        switch self {
        case .unknown: return .working
        case .working: return .not_working
        case .not_working: return .unknown
        }
    }
}

struct Requirement: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "requirement"
    var id: String
    var identifier: String
    var projectId: String
    var title: String
    var bodyMarkdown: String
    var implementing: RequirementImplementing
    var working: RequirementWorking
    var sortOrder: Double
    var createdAt: Date
    var updatedAt: Date
    /// JSON array of issue identifiers, e.g. ["ARK-1","ARK-2"]
    var linkedIssueIdentifiers: String = "[]"

    var linkedIdentifiers: [String] {
        guard let data = linkedIssueIdentifiers.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return arr
    }

    static func encodeIdentifiers(_ ids: [String]) -> String {
        let cleaned = ids.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let data = try? JSONEncoder().encode(cleaned),
              let s = String(data: data, encoding: .utf8) else { return "[]" }
        return s
    }

    static let project = belongsTo(Project.self)
    static let comments = hasMany(RequirementComment.self)
}

struct RequirementComment: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "requirement_comment"
    var id: String
    var requirementId: String
    var bodyMarkdown: String
    var authorName: String
    var createdAt: Date
}

enum MentionParser {
    /// Canonical bot / human names agents may @mention.
    static let knownActors: [String] = ["Product", "Ops", "Comms", "Riyu", "Agent"]

    static func canonicalizeActor(_ raw: String) -> String {
        if let known = knownActors.first(where: { $0.caseInsensitiveCompare(raw) == .orderedSame }) {
            return known
        }
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    static func firstMention(in body: String) -> String? {
        allMentions(in: body).first
    }

    /// Distinct @mentions in order of first appearance (case-insensitive dedupe).
    static func allMentions(in body: String) -> [String] {
        let pattern = #"@([A-Za-z][A-Za-z0-9_-]{0,31})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        var seen = Set<String>()
        var result: [String] = []
        regex.enumerateMatches(in: body, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 2,
                  let nameRange = Range(match.range(at: 1), in: body) else { return }
            let canonical = canonicalizeActor(String(body[nameRange]))
            let key = canonical.lowercased()
            if seen.insert(key).inserted {
                result.append(canonical)
            }
        }
        return result
    }

    static func inferKind(body: String, targetActor: String?) -> ActivityKind {
        let lower = body.lowercased()
        if lower.contains("handoff") || lower.contains("hand off") || lower.contains("handing off") {
            return .handoff
        }
        if let targetActor, !targetActor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .mention
        }
        return .comment
    }
}
