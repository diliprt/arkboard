import Foundation
import Observation
import GRDB
import SwiftUI

@MainActor
@Observable
final class AppStore {
    var workspace: Workspace?
    var projects: [Project] = []
    var issues: [Issue] = []
    var labels: [IssueTag] = []
    var comments: [Comment] = []
    var selectedProjectId: String? = nil // nil = Inbox (all)
    var selectedIssueId: String? = nil
    var viewMode: ViewMode = .list
    var filter = IssueFilter()
    var mcpRunning = false
    var mcpPort: UInt16 = 7420
    var lastError: String?
    /// Bumped on every successful reload so SwiftUI views refresh after MCP mutations.
    var dataRevision: UInt64 = 0

    enum ViewMode: String, CaseIterable, Identifiable {
        case list, board
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    private let db: DatabasePool
    private var mcpServer: MCPServer?
    private var observation: Task<Void, Never>?

    init(db: DatabasePool = AppDatabase.shared) {
        self.db = db
    }

    func start() async {
        do {
            try await db.write { db in
                try SeedData.seedIfNeeded(db)
            }
            try await reloadAll()
            startMCP()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func startMCP() {
        guard mcpServer == nil else { return }
        let server = MCPServer(port: mcpPort, store: self)
        do {
            try server.start()
            mcpServer = server
            mcpRunning = true
        } catch {
            lastError = "MCP server failed: \(error.localizedDescription)"
            mcpRunning = false
        }
    }

    func stopMCP() {
        mcpServer?.stop()
        mcpServer = nil
        mcpRunning = false
    }

    // MARK: - Queries

    var selectedProject: Project? {
        guard let selectedProjectId else { return nil }
        return projects.first { $0.id == selectedProjectId }
    }

    /// Board is per-project; Inbox (nil selection) stays list-first to avoid mixed-project columns.
    var isInbox: Bool { selectedProjectId == nil }

    var boardAvailable: Bool { selectedProjectId != nil }


    var selectedIssue: Issue? {
        guard let selectedIssueId else { return nil }
        return issues.first { $0.id == selectedIssueId }
    }

    var filteredIssues: [Issue] {
        issues.filter { issue in
            if let pid = selectedProjectId ?? filter.projectId, issue.projectId != pid {
                return false
            }
            if let status = filter.status, issue.status != status { return false }
            if let priority = filter.priority, issue.priority != priority { return false }
            if !filter.showCanceled && issue.status == .canceled { return false }
            if !filter.query.isEmpty {
                let q = filter.query.lowercased()
                let hay = (issue.title + " " + issue.identifier + " " + issue.descriptionMarkdown).lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
        .sorted { lhs, rhs in
            if lhs.status.sortOrder != rhs.status.sortOrder {
                return lhs.status.sortOrder < rhs.status.sortOrder
            }
            if lhs.priority.sortOrder != rhs.priority.sortOrder {
                return lhs.priority.sortOrder < rhs.priority.sortOrder
            }
            return lhs.orderInStatus < rhs.orderInStatus
        }
    }

    func issues(for status: IssueStatus) -> [Issue] {
        filteredIssues
            .filter { $0.status == status }
            .sorted { $0.orderInStatus < $1.orderInStatus }
    }

    func project(for issue: Issue) -> Project? {
        projects.first { $0.id == issue.projectId }
    }

    func labels(for issue: Issue) -> [IssueTag] {
        // Load via join cache: issue_label not held in memory — query sync from labels attached after reload
        labelMap[issue.id] ?? []
    }

    func comments(for issue: Issue) -> [Comment] {
        comments.filter { $0.issueId == issue.id }.sorted { $0.createdAt < $1.createdAt }
    }

    private var labelMap: [String: [IssueTag]] = [:]

    // MARK: - Reload

    func reloadAll() async throws {
        let snapshot = try await db.read { db -> (Workspace?, [Project], [Issue], [IssueTag], [Comment], [IssueLabel]) in
            let ws = try Workspace.fetchOne(db)
            let projects = try Project.order(Column("name")).fetchAll(db)
            let issues = try Issue.order(Column("updatedAt").desc).fetchAll(db)
            let labels = try IssueTag.order(Column("name")).fetchAll(db)
            let comments = try Comment.order(Column("createdAt")).fetchAll(db)
            let links = try IssueLabel.fetchAll(db)
            return (ws, projects, issues, labels, comments, links)
        }

        workspace = snapshot.0
        projects = snapshot.1
        issues = snapshot.2
        labels = snapshot.3
        comments = snapshot.4

        var map: [String: [IssueTag]] = [:]
        let labelById = Dictionary(uniqueKeysWithValues: snapshot.3.map { ($0.id, $0) })
        for link in snapshot.5 {
            if let label = labelById[link.labelId] {
                map[link.issueId, default: []].append(label)
            }
        }
        labelMap = map
        dataRevision &+= 1

        if selectedIssueId == nil {
            selectedIssueId = filteredIssues.first?.id
        } else if !issues.contains(where: { $0.id == selectedIssueId }) {
            selectedIssueId = filteredIssues.first?.id
        }
    }

    // MARK: - Mutations

    @discardableResult
    func createProject(key: String, name: String, color: String = "#5E6AD2") async throws -> Project {
        let cleanedKey = key.uppercased().filter { $0.isLetter || $0.isNumber }
        guard cleanedKey.count >= 2 else { throw StoreError.invalidProjectKey }
        let project = Project(
            id: UUID().uuidString,
            key: String(cleanedKey.prefix(6)),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            color: color,
            createdAt: Date(),
            issueCounter: 0
        )
        try await db.write { db in
            try project.insert(db)
        }
        try await reloadAll()
        selectedProjectId = project.id
        return project
    }

    @discardableResult
    func createIssue(
        projectId: String? = nil,
        title: String,
        description: String = "",
        status: IssueStatus = .backlog,
        priority: IssuePriority = .none,
        assigneeName: String? = nil,
        labelNames: [String] = []
    ) async throws -> Issue {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyTitle }

        let pid = projectId ?? selectedProjectId ?? projects.first?.id
        guard let pid, let _ = projects.first(where: { $0.id == pid }) else {
            throw StoreError.noProject
        }

        let issue = try await db.write { db -> Issue in
            guard var project = try Project.fetchOne(db, key: pid) else {
                throw StoreError.noProject
            }
            project.issueCounter += 1
            let maxOrder = try Double.fetchOne(
                db,
                sql: "SELECT MAX(orderInStatus) FROM issue WHERE projectId = ? AND status = ?",
                arguments: [pid, status.rawValue]
            ) ?? 0
            let now = Date()
            let issue = Issue(
                id: UUID().uuidString,
                identifier: "\(project.key)-\(project.issueCounter)",
                projectId: pid,
                title: trimmed,
                descriptionMarkdown: description,
                status: status,
                priority: priority,
                assigneeName: assigneeName,
                estimatePoints: nil,
                createdAt: now,
                updatedAt: now,
                orderInStatus: maxOrder + 1
            )
            try project.update(db)
            try issue.insert(db)

            for name in labelNames {
                let labelName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !labelName.isEmpty else { continue }
                let label: IssueTag
                if let existing = try IssueTag.filter(Column("name") == labelName).fetchOne(db) {
                    label = existing
                } else {
                    label = IssueTag(id: UUID().uuidString, name: labelName, color: Self.randomColor())
                    try label.insert(db)
                }
                try IssueLabel(issueId: issue.id, labelId: label.id).insert(db)
            }
            return issue
        }

        try await reloadAll()
        selectedIssueId = issue.id
        return issue
    }

    func updateIssue(
        id: String,
        title: String? = nil,
        description: String? = nil,
        status: IssueStatus? = nil,
        priority: IssuePriority? = nil,
        assigneeName: String?? = nil,
        estimatePoints: Int?? = nil,
        orderInStatus: Double? = nil
    ) async throws -> Issue {
        let updated = try await db.write { db -> Issue in
            guard var issue = try Issue.fetchOne(db, key: id) else {
                throw StoreError.notFound
            }
            if let title {
                let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { throw StoreError.emptyTitle }
                issue.title = t
            }
            if let description { issue.descriptionMarkdown = description }
            if let status { issue.status = status }
            if let priority { issue.priority = priority }
            if let assigneeName { issue.assigneeName = assigneeName }
            if let estimatePoints { issue.estimatePoints = estimatePoints }
            if let orderInStatus { issue.orderInStatus = orderInStatus }
            issue.updatedAt = Date()
            try issue.update(db)
            return issue
        }
        try await reloadAll()
        return updated
    }

    func moveIssue(_ issueId: String, to status: IssueStatus, before beforeId: String?) async throws {
        try await db.write { db in
            guard let moving = try Issue.fetchOne(db, key: issueId) else { return }
            var siblings = try Issue
                .filter(Column("status") == status.rawValue)
                .filter(Column("projectId") == moving.projectId)
                .order(Column("orderInStatus"))
                .fetchAll(db)
                .filter { $0.id != issueId }

            if let beforeId, let idx = siblings.firstIndex(where: { $0.id == beforeId }) {
                siblings.insert(moving, at: idx)
            } else {
                siblings.append(moving)
            }

            let now = Date()
            for (index, var item) in siblings.enumerated() {
                if item.id == issueId {
                    item.status = status
                }
                item.orderInStatus = Double(index)
                item.updatedAt = now
                try item.update(db)
            }
        }
        try await reloadAll()
    }

    func deleteIssue(_ id: String) async throws {
        try await db.write { db in
            _ = try Issue.deleteOne(db, key: id)
        }
        if selectedIssueId == id { selectedIssueId = nil }
        try await reloadAll()
    }

    @discardableResult
    func addComment(issueId: String, body: String, authorName: String = "Riyu") async throws -> Comment {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyTitle }
        let comment = Comment(
            id: UUID().uuidString,
            issueId: issueId,
            bodyMarkdown: trimmed,
            authorName: authorName,
            createdAt: Date()
        )
        try await db.write { db in
            guard try Issue.fetchOne(db, key: issueId) != nil else { throw StoreError.notFound }
            try comment.insert(db)
            if var issue = try Issue.fetchOne(db, key: issueId) {
                issue.updatedAt = Date()
                try issue.update(db)
            }
        }
        try await reloadAll()
        return comment
    }

    func setIssueLabels(issueId: String, labelNames: [String]) async throws {
        try await db.write { db in
            try db.execute(sql: "DELETE FROM issue_label WHERE issueId = ?", arguments: [issueId])
            for name in labelNames {
                let labelName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !labelName.isEmpty else { continue }
                let label: IssueTag
                if let existing = try IssueTag.filter(Column("name") == labelName).fetchOne(db) {
                    label = existing
                } else {
                    label = IssueTag(id: UUID().uuidString, name: labelName, color: Self.randomColor())
                    try label.insert(db)
                }
                try IssueLabel(issueId: issueId, labelId: label.id).insert(db)
            }
        }
        try await reloadAll()
    }

    // MARK: - Export for MCP / API

    func issueDictionary(_ issue: Issue) -> [String: Any] {
        [
            "id": issue.id,
            "identifier": issue.identifier,
            "projectId": issue.projectId,
            "projectKey": project(for: issue)?.key ?? "",
            "title": issue.title,
            "description": issue.descriptionMarkdown,
            "status": issue.status.rawValue,
            "priority": issue.priority.rawValue,
            "assigneeName": issue.assigneeName ?? NSNull(),
            "estimatePoints": issue.estimatePoints ?? NSNull(),
            "labels": labels(for: issue).map(\.name),
            "createdAt": ISO8601DateFormatter().string(from: issue.createdAt),
            "updatedAt": ISO8601DateFormatter().string(from: issue.updatedAt),
        ]
    }

    func projectDictionary(_ project: Project) -> [String: Any] {
        [
            "id": project.id,
            "key": project.key,
            "name": project.name,
            "color": project.color,
            "issueCount": issues.filter { $0.projectId == project.id }.count,
            "createdAt": ISO8601DateFormatter().string(from: project.createdAt),
        ]
    }

    nonisolated private static func randomColor() -> String {
        let colors = ["#EB5757", "#F2C94C", "#27AE60", "#4EA7FC", "#BB87FC", "#F2994A", "#56CCF2"]
        return colors.randomElement() ?? "#5E6AD2"
    }
}

enum StoreError: LocalizedError {
    case emptyTitle, noProject, notFound, invalidProjectKey

    var errorDescription: String? {
        switch self {
        case .emptyTitle: return "Title cannot be empty"
        case .noProject: return "No project selected"
        case .notFound: return "Item not found"
        case .invalidProjectKey: return "Project key must be at least 2 alphanumeric characters"
        }
    }
}
