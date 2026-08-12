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
    var activities: [Activity] = []
    /// Portfolio is the default bird's-eye landing.
    var selection: SidebarSelection = .portfolio
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
                try SeedData.seedDemoAgentActivityIfNeeded(db)
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

    // MARK: - Selection helpers

    var selectedProjectId: String? {
        if case .project(let id) = selection { return id }
        return nil
    }

    var selectedProject: Project? {
        guard let selectedProjectId else { return nil }
        return projects.first { $0.id == selectedProjectId }
    }

    var isInbox: Bool {
        if case .inbox = selection { return true }
        return false
    }

    var isPortfolio: Bool {
        if case .portfolio = selection { return true }
        return false
    }

    var isActivity: Bool {
        if case .activity = selection { return true }
        return false
    }

    /// Board is per-project; Inbox / Portfolio / Activity stay list-or-overview.
    var boardAvailable: Bool { selectedProjectId != nil }

    var showsIssueBrowser: Bool {
        switch selection {
        case .inbox, .project: return true
        case .portfolio, .activity: return false
        }
    }

    func selectProject(_ projectId: String) {
        selection = .project(projectId)
        viewMode = .list
        selectedIssueId = filteredIssues.first?.id
    }

    // MARK: - Queries

    var selectedIssue: Issue? {
        guard let selectedIssueId else { return nil }
        return issues.first { $0.id == selectedIssueId }
    }

    var filteredIssues: [Issue] {
        issues.filter { issue in
            if let pid = selectedProjectId ?? filter.projectId, issue.projectId != pid {
                return false
            }
            // Inbox / project browser only — portfolio/activity ignore filter project
            if case .portfolio = selection { return false }
            if case .activity = selection { return false }
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
        labelMap[issue.id] ?? []
    }

    func comments(for issue: Issue) -> [Comment] {
        comments.filter { $0.issueId == issue.id }.sorted { $0.createdAt < $1.createdAt }
    }

    func issue(forActivity activity: Activity) -> Issue? {
        guard let issueId = activity.issueId else { return nil }
        return issues.first { $0.id == issueId }
    }

    func project(forActivity activity: Activity) -> Project? {
        if let pid = activity.projectId {
            return projects.first { $0.id == pid }
        }
        if let issue = issue(forActivity: activity) {
            return project(for: issue)
        }
        return nil
    }

    // MARK: - Portfolio

    var portfolioCards: [ProjectPortfolioCard] {
        projects.map { project in
            let projectIssues = issues.filter { $0.projectId == project.id }
            var byStatus: [IssueStatus: Int] = [:]
            for status in IssueStatus.allCases {
                byStatus[status] = projectIssues.filter { $0.status == status }.count
            }
            var features = 0, bugs = 0, other = 0
            for issue in projectIssues {
                let names = Set(labels(for: issue).map { $0.name.lowercased() })
                if names.contains("bug") {
                    bugs += 1
                } else if names.contains("feature") {
                    features += 1
                } else {
                    other += 1
                }
            }
            return ProjectPortfolioCard(
                project: project,
                total: projectIssues.count,
                byStatus: byStatus,
                featureCount: features,
                bugCount: bugs,
                otherCount: other
            )
        }
    }

    var portfolioTotals: PortfolioTotals {
        var totals = PortfolioTotals()
        for card in portfolioCards {
            totals.openWork += card.openCount
            totals.inProgress += card.byStatus[.in_progress] ?? 0
            totals.bugs += card.bugCount
            totals.features += card.featureCount
        }
        return totals
    }

    private var labelMap: [String: [IssueTag]] = [:]

    // MARK: - Reload

    func reloadAll() async throws {
        let snapshot = try await db.read { db -> (Workspace?, [Project], [Issue], [IssueTag], [Comment], [IssueLabel], [Activity]) in
            let ws = try Workspace.fetchOne(db)
            let projects = try Project.order(Column("name")).fetchAll(db)
            let issues = try Issue.order(Column("updatedAt").desc).fetchAll(db)
            let labels = try IssueTag.order(Column("name")).fetchAll(db)
            let comments = try Comment.order(Column("createdAt")).fetchAll(db)
            let links = try IssueLabel.fetchAll(db)
            let activities = try Activity.order(Column("createdAt").desc).fetchAll(db)
            return (ws, projects, issues, labels, comments, links, activities)
        }

        workspace = snapshot.0
        projects = snapshot.1
        issues = snapshot.2
        labels = snapshot.3
        comments = snapshot.4
        activities = snapshot.6

        var map: [String: [IssueTag]] = [:]
        let labelById = Dictionary(uniqueKeysWithValues: snapshot.3.map { ($0.id, $0) })
        for link in snapshot.5 {
            if let label = labelById[link.labelId] {
                map[link.issueId, default: []].append(label)
            }
        }
        labelMap = map
        dataRevision &+= 1

        if showsIssueBrowser {
            if selectedIssueId == nil {
                selectedIssueId = filteredIssues.first?.id
            } else if !issues.contains(where: { $0.id == selectedIssueId }) {
                selectedIssueId = filteredIssues.first?.id
            }
        }
    }

    // MARK: - Mutations

    @discardableResult
    func createProject(key: String, name: String, color: String = "#5E6AD2", actor: String = "Riyu") async throws -> Project {
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
            try ActivityLogger.insert(
                db,
                actor: actor,
                action: ActivityAction.created_project.rawValue,
                summary: "\(actor) created project \(project.key) — \(project.name)",
                projectId: project.id
            )
        }
        try await reloadAll()
        selection = .project(project.id)
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
        labelNames: [String] = [],
        actor: String = "Riyu"
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

            try ActivityLogger.insert(
                db,
                actor: actor,
                action: ActivityAction.created_issue.rawValue,
                summary: "\(actor) created \(issue.identifier): \(issue.title)",
                issueId: issue.id,
                projectId: pid
            )
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
        orderInStatus: Double? = nil,
        actor: String = "Riyu"
    ) async throws -> Issue {
        let updated = try await db.write { db -> Issue in
            guard var issue = try Issue.fetchOne(db, key: id) else {
                throw StoreError.notFound
            }
            var changes: [String] = []
            if let title {
                let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { throw StoreError.emptyTitle }
                if t != issue.title {
                    issue.title = t
                    changes.append("title")
                }
            }
            if let description, description != issue.descriptionMarkdown {
                issue.descriptionMarkdown = description
                changes.append("description")
            }
            if let status, status != issue.status {
                issue.status = status
                changes.append("status → \(status.rawValue)")
            }
            if let priority, priority != issue.priority {
                issue.priority = priority
                changes.append("priority → \(priority.rawValue)")
            }
            if let assigneeName {
                let newVal = assigneeName
                if newVal != issue.assigneeName {
                    issue.assigneeName = newVal
                    changes.append("assignee")
                }
            }
            if let estimatePoints {
                let newVal = estimatePoints
                if newVal != issue.estimatePoints {
                    issue.estimatePoints = newVal
                    changes.append("estimate")
                }
            }
            if let orderInStatus { issue.orderInStatus = orderInStatus }
            issue.updatedAt = Date()
            try issue.update(db)

            if !changes.isEmpty {
                let detail = changes.joined(separator: ", ")
                try ActivityLogger.insert(
                    db,
                    actor: actor,
                    action: ActivityAction.updated_issue.rawValue,
                    summary: "\(actor) updated \(issue.identifier) (\(detail))",
                    issueId: issue.id,
                    projectId: issue.projectId
                )
            }
            return issue
        }
        try await reloadAll()
        return updated
    }

    func moveIssue(_ issueId: String, to status: IssueStatus, before beforeId: String?, actor: String = "Riyu") async throws {
        try await db.write { db in
            guard let moving = try Issue.fetchOne(db, key: issueId) else { return }
            let fromStatus = moving.status
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

            if fromStatus != status {
                try ActivityLogger.insert(
                    db,
                    actor: actor,
                    action: ActivityAction.updated_issue.rawValue,
                    summary: "\(actor) moved \(moving.identifier) \(fromStatus.rawValue) → \(status.rawValue)",
                    issueId: moving.id,
                    projectId: moving.projectId
                )
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
    func addComment(issueId: String, body: String, authorName: String = "Riyu", actor: String? = nil) async throws -> Comment {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyTitle }
        let author = (actor ?? authorName).trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAuthor = author.isEmpty ? "Agent" : author
        let comment = Comment(
            id: UUID().uuidString,
            issueId: issueId,
            bodyMarkdown: trimmed,
            authorName: resolvedAuthor,
            createdAt: Date()
        )
        try await db.write { db in
            guard let issue = try Issue.fetchOne(db, key: issueId) else { throw StoreError.notFound }
            try comment.insert(db)
            if var issue = try Issue.fetchOne(db, key: issueId) {
                issue.updatedAt = Date()
                try issue.update(db)
            }
            let preview = trimmed.count > 80 ? String(trimmed.prefix(77)) + "…" : trimmed
            try ActivityLogger.insert(
                db,
                actor: resolvedAuthor,
                action: ActivityAction.commented.rawValue,
                summary: "\(resolvedAuthor) on \(issue.identifier): \(preview)",
                issueId: issueId,
                projectId: issue.projectId
            )
        }
        try await reloadAll()
        return comment
    }

    func setIssueLabels(issueId: String, labelNames: [String], actor: String = "Riyu") async throws {
        try await db.write { db in
            guard let issue = try Issue.fetchOne(db, key: issueId) else { throw StoreError.notFound }
            try db.execute(sql: "DELETE FROM issue_label WHERE issueId = ?", arguments: [issueId])
            var applied: [String] = []
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
                applied.append(label.name)
            }
            try ActivityLogger.insert(
                db,
                actor: actor,
                action: ActivityAction.updated_issue.rawValue,
                summary: "\(actor) set labels on \(issue.identifier): \(applied.isEmpty ? "(none)" : applied.joined(separator: ", "))",
                issueId: issueId,
                projectId: issue.projectId
            )
        }
        try await reloadAll()
    }

    /// Re-seed the Product/Ops/Comms demo conversation (for existing DBs / demos).
    func seedDemoAgentActivity() async {
        do {
            try await db.write { db in
                try SeedData.seedDemoAgentActivity(db)
            }
            try await reloadAll()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func listActivity(limit: Int = 50, projectKey: String? = nil) -> [Activity] {
        var items = activities
        if let projectKey,
           let p = projects.first(where: { $0.key.caseInsensitiveCompare(projectKey) == .orderedSame }) {
            items = items.filter { activity in
                if activity.projectId == p.id { return true }
                if let issue = issue(forActivity: activity), issue.projectId == p.id { return true }
                return false
            }
        }
        return Array(items.prefix(max(1, min(limit, 500))))
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

    func activityDictionary(_ activity: Activity) -> [String: Any] {
        [
            "id": activity.id,
            "createdAt": ISO8601DateFormatter().string(from: activity.createdAt),
            "actor": activity.actor,
            "action": activity.action,
            "issueId": activity.issueId ?? NSNull(),
            "projectId": activity.projectId ?? NSNull(),
            "issueIdentifier": issue(forActivity: activity)?.identifier ?? NSNull(),
            "projectKey": project(forActivity: activity)?.key ?? NSNull(),
            "summary": activity.summary,
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
