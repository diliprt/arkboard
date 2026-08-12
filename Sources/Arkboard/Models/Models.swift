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

enum ActivityAction: String, Codable, DatabaseValueConvertible {
    case created_issue
    case updated_issue
    case commented
    case created_project

    var displayName: String {
        switch self {
        case .created_issue: return "created issue"
        case .updated_issue: return "updated issue"
        case .commented: return "commented"
        case .created_project: return "created project"
        }
    }
}

/// Top-level sidebar destinations. Portfolio sits above Inbox.
enum SidebarSelection: Hashable, Identifiable {
    case portfolio
    case activity
    case inbox
    case project(String)

    var id: String {
        switch self {
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

    static let issues = hasMany(Issue.self)
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
    var orderInStatus: Double

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
    var summary: String
}

struct IssueFilter: Equatable {
    var projectId: String? = nil
    var status: IssueStatus? = nil
    var priority: IssuePriority? = nil
    var query: String = ""
    var showCanceled: Bool = false
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
