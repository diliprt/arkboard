import Foundation
import GRDB

struct Workspace: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    static let databaseTableName = "workspace"
    var id: String
    var name: String
    var createdAt: Date
}

struct Project: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    static let databaseTableName = "project"
    var id: String
    var key: String
    var name: String
    var color: String
    var icon: String
    var summary: String
    var repoPath: String?
    var githubRepo: String?
    var issueCounter: Int
    var capabilityCounter: Int
    var sortOrder: Double
    var pinned: Bool
    var createdAt: Date
}

struct Issue: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    static let databaseTableName = "issue"
    var id: String
    var identifier: String
    var projectId: String
    var title: String
    var bodyMarkdown: String
    var status: IssueStatus
    var priority: IssuePriority
    var assignee: String?
    var sortOrder: Double
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var archivedAt: Date?
}

struct Label: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    static let databaseTableName = "label"
    var id: String
    var name: String
    var color: String
}

struct IssueLabel: Codable, FetchableRecord, PersistableRecord, Hashable, Sendable {
    static let databaseTableName = "issue_label"
    var issueId: String
    var labelId: String
}

struct Comment: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    static let databaseTableName = "comment"
    var id: String
    var issueId: String
    var bodyMarkdown: String
    var author: String
    var createdAt: Date
}

struct Milestone: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    static let databaseTableName = "milestone"
    var id: String
    var projectId: String?
    var title: String
    var bodyMarkdown: String
    var targetDate: Date
    var status: MilestoneStatus
    var relatedIssueIdentifiers: String
    var createdAt: Date
    var updatedAt: Date

    var relatedIdentifiers: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(relatedIssueIdentifiers.utf8))) ?? []
    }

    static func encodeRelated(_ identifiers: [String]) -> String {
        let data = (try? JSONEncoder().encode(identifiers)) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

struct Capability: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    static let databaseTableName = "capability"
    var id: String
    var identifier: String
    var projectId: String
    var title: String
    var note: String
    var state: CapabilityState
    var health: CapabilityHealth
    var docPath: String?
    var docAnchor: String?
    var linkedIssueIdentifiers: String
    var sortOrder: Double
    var checkedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var linkedIdentifiers: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(linkedIssueIdentifiers.utf8))) ?? []
    }

    static func encodeLinked(_ identifiers: [String]) -> String {
        let data = (try? JSONEncoder().encode(identifiers)) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

struct Activity: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    static let databaseTableName = "activity"
    var id: String
    var createdAt: Date
    var actor: String
    var kind: ActivityKind
    var action: ActivityAction
    var body: String
    var targetActors: String
    var projectId: String?
    var issueId: String?
    var capabilityId: String?
    var milestoneId: String?
    var metadata: String = "{}"

    var targets: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(targetActors.utf8))) ?? []
    }

    static func encodeTargets(_ names: [String]) -> String {
        let data = (try? JSONEncoder().encode(names)) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

struct ActivityDraft: Sendable {
    var kind: ActivityKind
    var action: ActivityAction
    var body: String
    var targetActors: [String] = []
    var projectId: String? = nil
    var issueId: String? = nil
    var capabilityId: String? = nil
    var milestoneId: String? = nil
    var metadata: String = "{}"
}

struct StudioDocument: Identifiable, Hashable, Sendable {
    var id: String { path }
    var path: String
    var tab: DocumentTab
    var title: String
    var markdown: String?
    var imageData: Data?
    var isImage: Bool
    var bytes: Int
    var modifiedAt: Date
    var absoluteURL: URL?
}

struct DocumentBundle: Sendable {
    var source: String
    var root: String?
    var documents: [StudioDocument]
    var loadedAt: Date
    var error: String?

    func documents(in tab: DocumentTab) -> [StudioDocument] {
        documents.filter { $0.tab == tab && !$0.isImage || ($0.tab == tab) }
            .filter { $0.tab == tab }
    }

    func primary(in tab: DocumentTab) -> StudioDocument? {
        let docs = documents(in: tab).filter { !$0.isImage }
        if let exact = docs.first(where: { DocumentRouting.stem($0.path) == tab.rawValue }) {
            return exact
        }
        return docs.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }.first
    }

    var overview: StudioDocument? {
        documents.first { $0.tab == .overview }
    }

    var moreDocuments: [StudioDocument] {
        documents.filter { $0.tab == .more }
    }
}

struct OpenQuestion: Identifiable, Hashable, Sendable {
    var id: String { "\(projectId)|\(path)|\(anchor)" }
    var projectId: String
    var projectKey: String
    var projectName: String
    var projectColor: String
    var path: String
    var heading: String
    var anchor: String
    var body: String
}

struct HeadingRef: Hashable, Sendable {
    var level: Int
    var title: String
    var anchor: String
}
