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

struct IssueFilter: Equatable {
    var projectId: String? = nil
    var status: IssueStatus? = nil
    var priority: IssuePriority? = nil
    var query: String = ""
    var showCanceled: Bool = false
}
