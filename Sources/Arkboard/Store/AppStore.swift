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
    var milestones: [Milestone] = []
    /// Monitor is the default agent-first landing.
    var selection: SidebarSelection = .monitor
    var selectedIssueId: String? = nil
    var viewMode: ViewMode = .list
    var filter = IssueFilter()
    var activityFilter: ActivityFeedFilter = .mentions
    var mcpRunning = false
    var mcpPort: UInt16 = 7420
    var lastError: String?
    /// Bumped to focus the Monitor composer (⌘N).
    var composerFocusToken: UInt64 = 0
    /// Expanded Needs you / Review thread on Monitor.
    var expandedReviewIssueId: String? = nil
    /// Project shown in the Monitor inspector.
    var monitorProjectId: String? = nil
    /// Light is the product default; user can switch in Settings.
    var appearance: AppearancePreference = .load()
    /// Soft-delete undo banner (~10s).
    var undoDelete: UndoDeleteBanner?
    /// Bumped on every successful reload so SwiftUI views refresh after MCP mutations.
    var dataRevision: UInt64 = 0

    private var undoDeleteTask: Task<Void, Never>?

    struct UndoDeleteBanner: Equatable, Identifiable {
        var id: String { issueId }
        var issueId: String
        var identifier: String
        var title: String
        var expiresAt: Date
    }

    enum ViewMode: String, CaseIterable, Identifiable {
        case list, board
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    enum ActivityFeedFilter: String, CaseIterable, Identifiable {
        case all, bots, mentions
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "All"
            case .bots: return "Bots only"
            case .mentions: return "Mentions"
            }
        }
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
                try SeedData.seedMilestonesIfNeeded(db)
                try SeedData.seedDemoAgentActivityIfNeeded(db)
                try SeedData.enrichBotDialogueIfThin(db)
            }
            try await reloadAll()
            applyDefaultActivityFilter()
            startMCP()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Mentions if any exist; otherwise Bots-only.
    private func applyDefaultActivityFilter() {
        let hasMentions = activities.contains { activity in
            let kind = ActivityKind(rawValue: activity.kind)
            if kind == .mention || kind == .handoff { return true }
            return !activity.targetActors.isEmpty
        }
        activityFilter = hasMentions ? .mentions : .bots
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

    /// Board is per-project; Inbox / Portfolio / Activity / Monitor stay list-or-overview.
    var boardAvailable: Bool { selectedProjectId != nil }

    var showsIssueBrowser: Bool {
        switch selection {
        case .inbox, .project: return true
        case .monitor, .portfolio, .activity: return false
        }
    }

    /// GRDB write for extensions that cannot see `db`.
    func performWrite(_ body: (Database) throws -> Void) async throws {
        try await db.write { db in
            try body(db)
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

    /// Non-deleted issues (default working set for portfolio / MCP / timeline).
    var activeIssues: [Issue] {
        issues.filter { $0.deletedAt == nil }
    }

    var archivedIssues: [Issue] {
        issues.filter { $0.deletedAt != nil }
    }

    var filteredIssues: [Issue] {
        issues.filter { issue in
            if let pid = selectedProjectId ?? filter.projectId, issue.projectId != pid {
                return false
            }
            // Inbox / project browser only — portfolio/activity ignore filter project
            if case .monitor = selection { return false }
            if case .portfolio = selection { return false }
            if case .activity = selection { return false }
            if filter.showDeleted {
                if issue.deletedAt == nil { return false }
            } else if issue.deletedAt != nil {
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

    func project(forMilestone milestone: Milestone) -> Project? {
        guard let pid = milestone.projectId else { return nil }
        return projects.first { $0.id == pid }
    }

    var filteredActivities: [Activity] {
        let botNames: Set<String> = ["product", "ops", "comms", "agent"]
        let base: [Activity]
        switch activityFilter {
        case .all:
            base = activities
        case .bots:
            base = activities.filter {
                botNames.contains($0.actor.lowercased()) && ActivityKind(rawValue: $0.kind) != .system
            }
        case .mentions:
            base = activities.filter { activity in
                let kind = ActivityKind(rawValue: activity.kind)
                if kind == .mention || kind == .handoff { return true }
                if !activity.targetActors.isEmpty { return true }
                return false
            }
        }
        // Fallback: collapse legacy fan-out rows that share issue/actor/action/second + comment core.
        return Self.collapseDuplicateMentionRows(base)
    }

    /// Group legacy N-row multi-mention fan-out into one display row with merged targets.
    nonisolated static func collapseDuplicateMentionRows(_ items: [Activity]) -> [Activity] {
        var result: [Activity] = []
        var indexByKey: [String: Int] = [:]

        func coreSummary(_ summary: String) -> String {
            if let range = summary.range(of: #":\s+"#, options: .regularExpression) {
                return String(summary[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return summary
        }

        for item in items {
            let second = Int(item.createdAt.timeIntervalSince1970)
            let key = "\(item.issueId ?? "")|\(item.actor.lowercased())|\(item.action)|\(second)|\(coreSummary(item.summary))"
            if let idx = indexByKey[key] {
                var existing = result[idx]
                var merged = existing.targetActors
                for t in item.targetActors where !merged.map({ $0.lowercased() }).contains(t.lowercased()) {
                    merged.append(t)
                }
                existing.targetActor = Activity.encodeTargets(merged)
                if merged.count > 1, let encoded = Activity.encodeTargets(merged) {
                    let arrow = merged.joined(separator: ", ")
                    if let onRange = existing.summary.range(of: " on "),
                       let colon = existing.summary.range(of: ": ", range: onRange.upperBound..<existing.summary.endIndex) {
                        let issuePart = String(existing.summary[onRange.upperBound..<colon.lowerBound])
                        let tail = String(existing.summary[colon.upperBound...])
                        existing.summary = "\(existing.actor) → \(arrow) on \(issuePart): \(tail)"
                    }
                    _ = encoded
                }
                result[idx] = existing
            } else {
                indexByKey[key] = result.count
                result.append(item)
            }
        }
        return result
    }

    // MARK: - Portfolio

    var portfolioCards: [ProjectPortfolioCard] {
        projects.map { project in
            let projectIssues = activeIssues.filter { $0.projectId == project.id }
            var byStatus: [IssueStatus: Int] = [:]
            for status in IssueStatus.allCases {
                byStatus[status] = projectIssues.filter { $0.status == status }.count
            }
            var features = 0, bugs = 0, other = 0
            for issue in projectIssues {
                let names = Set(labels(for: issue).map { $0.name.lowercased() })
                let isBug = names.contains("bug")
                let isFeature = names.contains("feature")
                // Feature and bug counts are independent — an issue can contribute to both.
                if isBug { bugs += 1 }
                if isFeature { features += 1 }
                if !isBug && !isFeature { other += 1 }
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

    /// Milestones grouped: studio-wide first, then by project name.
    var milestonesGrouped: [(title: String, project: Project?, items: [Milestone])] {
        var groups: [(title: String, project: Project?, items: [Milestone])] = []
        let studio = milestones.filter { $0.projectId == nil }
            .sorted { $0.targetDate < $1.targetDate }
        if !studio.isEmpty {
            groups.append(("Studio-wide", nil, studio))
        }
        for project in projects.sorted(by: { $0.name < $1.name }) {
            let items = milestones.filter { $0.projectId == project.id }
                .sorted { $0.targetDate < $1.targetDate }
            if !items.isEmpty {
                groups.append((project.name, project, items))
            }
        }
        return groups
    }

    var timelineEvents: [TimelineEvent] {
        var events: [TimelineEvent] = []
        for ms in milestones {
            let p = project(forMilestone: ms)
            events.append(TimelineEvent(
                id: "ms-\(ms.id)",
                date: ms.targetDate,
                title: ms.title,
                subtitle: ms.description.isEmpty ? "Milestone" : ms.description,
                kind: .milestone,
                projectId: ms.projectId,
                projectKey: p?.key,
                projectColor: p?.color ?? "#8E8E93",
                statusLabel: ms.status.displayName,
                milestoneId: ms.id
            ))
        }
        for issue in activeIssues {
            let p = project(for: issue)
            let color = p?.color ?? "#8E8E93"
            events.append(TimelineEvent(
                id: "created-\(issue.id)",
                date: issue.createdAt,
                title: issue.identifier,
                subtitle: "Created · \(issue.title)",
                kind: .issueCreated,
                projectId: issue.projectId,
                projectKey: p?.key,
                projectColor: color,
                statusLabel: nil,
                issueId: issue.id
            ))
            if let doneAt = issue.completedAt ?? (issue.status == .done ? issue.updatedAt : nil) {
                events.append(TimelineEvent(
                    id: "done-\(issue.id)",
                    date: doneAt,
                    title: issue.identifier,
                    subtitle: "Done · \(issue.title)",
                    kind: .issueDone,
                    projectId: issue.projectId,
                    projectKey: p?.key,
                    projectColor: color,
                    statusLabel: "Done",
                    issueId: issue.id
                ))
            }
        }
        return events.sorted { $0.date < $1.date }
    }

    /// Plan = milestones + done completions; All also includes issue-created events.
    func timelineEvents(mode: TimelineMode) -> [TimelineEvent] {
        switch mode {
        case .plan:
            return timelineEvents.filter { $0.kind == .milestone || $0.kind == .issueDone }
        case .all:
            return timelineEvents
        }
    }

    enum TimelineMode: String, CaseIterable, Identifiable {
        case plan, all
        var id: String { rawValue }
        var title: String {
            switch self {
            case .plan: return "Plan"
            case .all: return "All"
            }
        }
    }

    /// True when the feed already has a rich bot↔bot dialogue (hide Seed CTA).
    var hasRichBotDialogue: Bool {
        let targeted = activities.filter { !$0.targetActors.isEmpty || ActivityKind(rawValue: $0.kind) == .mention || ActivityKind(rawValue: $0.kind) == .handoff }
        return targeted.count >= 3
    }

    private var labelMap: [String: [IssueTag]] = [:]

    // MARK: - Reload

    func reloadAll() async throws {
        let snapshot = try await db.read { db -> (Workspace?, [Project], [Issue], [IssueTag], [Comment], [IssueLabel], [Activity], [Milestone]) in
            let ws = try Workspace.fetchOne(db)
            let projects = try Project.order(Column("name")).fetchAll(db)
            let issues = try Issue.order(Column("updatedAt").desc).fetchAll(db)
            let labels = try IssueTag.order(Column("name")).fetchAll(db)
            let comments = try Comment.order(Column("createdAt")).fetchAll(db)
            let links = try IssueLabel.fetchAll(db)
            let activities = try Activity.order(Column("createdAt").desc).fetchAll(db)
            let milestones = try Milestone.order(Column("targetDate")).fetchAll(db)
            return (ws, projects, issues, labels, comments, links, activities, milestones)
        }

        workspace = snapshot.0
        projects = snapshot.1
        issues = snapshot.2
        labels = snapshot.3
        comments = snapshot.4
        activities = snapshot.6
        milestones = snapshot.7

        var map: [String: [IssueTag]] = [:]
        let labelById = Dictionary(uniqueKeysWithValues: snapshot.3.map { ($0.id, $0) })
        for link in snapshot.5 {
            if let label = labelById[link.labelId] {
                map[link.issueId, default: []].append(label)
            }
        }
        labelMap = map
        dataRevision &+= 1

        if monitorProjectId == nil || !projects.contains(where: { $0.id == monitorProjectId }) {
            monitorProjectId = projects.first?.id
        }

        if showsIssueBrowser {
            if selectedIssueId == nil {
                selectedIssueId = filteredIssues.first?.id
            } else if !filteredIssues.contains(where: { $0.id == selectedIssueId }) {
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
                projectId: project.id,
                kind: .system
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
        let trimmed = Self.normalizeTitle(title)
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
                completedAt: status == .done ? now : nil,
                deletedAt: nil,
                orderInStatus: maxOrder + 1
            )
            try project.update(db)
            try issue.insert(db)

            for labelName in Self.dedupeLabelNames(labelNames) {
                let label = try Self.resolveOrCreateLabel(named: labelName, db: db)
                try IssueLabel(issueId: issue.id, labelId: label.id).insert(db)
            }

            try ActivityLogger.insert(
                db,
                actor: actor,
                action: ActivityAction.created_issue.rawValue,
                summary: "\(actor) created \(issue.identifier): \(issue.title)",
                issueId: issue.id,
                projectId: pid,
                kind: .system
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
            if issue.deletedAt != nil { throw StoreError.notFound }
            var changes: [String] = []
            if let title {
                let t = Self.normalizeTitle(title)
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
                if status == .done {
                    issue.completedAt = Date()
                } else if issue.status == .done {
                    issue.completedAt = nil
                }
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
                    projectId: issue.projectId,
                    kind: .system
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
            if moving.deletedAt != nil { throw StoreError.notFound }
            let fromStatus = moving.status
            var siblings = try Issue
                .filter(Column("status") == status.rawValue)
                .filter(Column("projectId") == moving.projectId)
                .order(Column("orderInStatus"))
                .fetchAll(db)
                .filter { $0.id != issueId && $0.deletedAt == nil }

            if let beforeId, let idx = siblings.firstIndex(where: { $0.id == beforeId }) {
                siblings.insert(moving, at: idx)
            } else {
                siblings.append(moving)
            }

            let now = Date()
            for (index, var item) in siblings.enumerated() {
                if item.id == issueId {
                    if status == .done && fromStatus != .done {
                        item.completedAt = now
                    } else if status != .done && fromStatus == .done {
                        item.completedAt = nil
                    }
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
                    projectId: moving.projectId,
                    kind: .system
                )
            }
        }
        try await reloadAll()
    }

    func deleteIssue(_ id: String, actor: String = "Riyu") async throws {
        let banner: UndoDeleteBanner = try await db.write { db in
            guard var issue = try Issue.fetchOne(db, key: id) else { throw StoreError.notFound }
            if issue.deletedAt != nil { throw StoreError.notFound }
            let now = Date()
            issue.deletedAt = now
            issue.updatedAt = now
            try issue.update(db)
            try ActivityLogger.insert(
                db,
                actor: actor,
                action: ActivityAction.deleted_issue.rawValue,
                summary: "\(actor) archived \(issue.identifier): \(issue.title)",
                issueId: issue.id,
                projectId: issue.projectId,
                kind: .system
            )
            return UndoDeleteBanner(
                issueId: issue.id,
                identifier: issue.identifier,
                title: issue.title,
                expiresAt: now.addingTimeInterval(10)
            )
        }
        if selectedIssueId == id { selectedIssueId = nil }
        try await reloadAll()
        presentUndoDelete(banner)
    }

    func restoreIssue(_ id: String, actor: String = "Riyu") async throws {
        try await db.write { db in
            guard var issue = try Issue.fetchOne(db, key: id) else { throw StoreError.notFound }
            guard issue.deletedAt != nil else { return }
            issue.deletedAt = nil
            issue.updatedAt = Date()
            try issue.update(db)
            try ActivityLogger.insert(
                db,
                actor: actor,
                action: ActivityAction.restored_issue.rawValue,
                summary: "\(actor) restored \(issue.identifier): \(issue.title)",
                issueId: issue.id,
                projectId: issue.projectId,
                kind: .system
            )
        }
        if undoDelete?.issueId == id { clearUndoDelete() }
        try await reloadAll()
        selectedIssueId = id
    }

    func undoLastDelete() async {
        guard let banner = undoDelete else { return }
        do {
            try await restoreIssue(banner.issueId)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func presentUndoDelete(_ banner: UndoDeleteBanner) {
        undoDeleteTask?.cancel()
        undoDelete = banner
        undoDeleteTask = Task { @MainActor in
            let nanos = UInt64(max(0, banner.expiresAt.timeIntervalSinceNow) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            if undoDelete?.issueId == banner.issueId {
                undoDelete = nil
            }
        }
    }

    func clearUndoDelete() {
        undoDeleteTask?.cancel()
        undoDeleteTask = nil
        undoDelete = nil
    }

    @discardableResult
    func addComment(issueId: String, body: String, authorName: String = "Riyu", actor: String? = nil) async throws -> Comment {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyComment }
        let author = (actor ?? authorName).trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAuthor = author.isEmpty ? "Agent" : author
        let targets = MentionParser.allMentions(in: trimmed)
        let comment = Comment(
            id: UUID().uuidString,
            issueId: issueId,
            bodyMarkdown: trimmed,
            authorName: resolvedAuthor,
            createdAt: Date()
        )
        try await db.write { db in
            guard let issue = try Issue.fetchOne(db, key: issueId) else { throw StoreError.notFound }
            if issue.deletedAt != nil { throw StoreError.notFound }
            try comment.insert(db)
            if var issue = try Issue.fetchOne(db, key: issueId) {
                issue.updatedAt = Date()
                try issue.update(db)
            }
            let preview = trimmed.count > 80 ? String(trimmed.prefix(77)) + "…" : trimmed
            // One activity row per comment; multi-mention → multi-avatar targets in one event.
            let encodedTargets = Activity.encodeTargets(targets)
            let kind = MentionParser.inferKind(body: trimmed, targetActor: encodedTargets)
            let arrow = targets.isEmpty ? "" : " → \(targets.joined(separator: ", "))"
            try ActivityLogger.insert(
                db,
                actor: resolvedAuthor,
                action: ActivityAction.commented.rawValue,
                summary: "\(resolvedAuthor)\(arrow) on \(issue.identifier): \(preview)",
                issueId: issueId,
                projectId: issue.projectId,
                targetActor: encodedTargets,
                kind: kind
            )
        }
        try await reloadAll()
        return comment
    }

    func setIssueLabels(issueId: String, labelNames: [String], actor: String = "Riyu") async throws {
        try await db.write { db in
            guard let issue = try Issue.fetchOne(db, key: issueId) else { throw StoreError.notFound }
            // Replace-labels path: clear existing links, then insert the unique set.
            try db.execute(sql: "DELETE FROM issue_label WHERE issueId = ?", arguments: [issueId])
            var applied: [String] = []
            for labelName in Self.dedupeLabelNames(labelNames) {
                let label = try Self.resolveOrCreateLabel(named: labelName, db: db)
                try IssueLabel(issueId: issueId, labelId: label.id).insert(db)
                applied.append(label.name)
            }
            try ActivityLogger.insert(
                db,
                actor: actor,
                action: ActivityAction.updated_issue.rawValue,
                summary: "\(actor) set labels on \(issue.identifier): \(applied.isEmpty ? "(none)" : applied.joined(separator: ", "))",
                issueId: issueId,
                projectId: issue.projectId,
                kind: .system
            )
        }
        try await reloadAll()
    }

    // MARK: - Milestones

    @discardableResult
    func createMilestone(
        title: String,
        description: String = "",
        targetDate: Date,
        status: MilestoneStatus = .planned,
        projectId: String? = nil,
        projectKey: String? = nil,
        relatedIssueIdentifiers: [String] = [],
        actor: String = "Riyu"
    ) async throws -> Milestone {
        let trimmed = Self.normalizeTitle(title)
        guard !trimmed.isEmpty else { throw StoreError.emptyTitle }
        try ensureRelatedIssuesExist(relatedIssueIdentifiers)

        var resolvedProjectId = projectId
        if resolvedProjectId == nil, let projectKey,
           let p = projects.first(where: { $0.key.caseInsensitiveCompare(projectKey) == .orderedSame }) {
            resolvedProjectId = p.id
        }
        if let pid = resolvedProjectId, !projects.contains(where: { $0.id == pid }) {
            throw StoreError.noProject
        }

        let now = Date()
        let scopeKey = resolvedProjectId.flatMap { id in projects.first { $0.id == id }?.key } ?? "studio"
        let projectIdForInsert = resolvedProjectId
        let milestone = Milestone(
            id: UUID().uuidString,
            projectId: projectIdForInsert,
            title: trimmed,
            description: description,
            targetDate: targetDate,
            status: status,
            relatedIssueIdentifiers: Milestone.encodeIdentifiers(relatedIssueIdentifiers),
            createdAt: now,
            updatedAt: now
        )
        try await db.write { db in
            try milestone.insert(db)
            try ActivityLogger.insert(
                db,
                actor: actor,
                action: ActivityAction.created_milestone.rawValue,
                summary: "\(actor) created milestone “\(milestone.title)” (\(scopeKey))",
                projectId: projectIdForInsert,
                kind: .system
            )
        }
        try await reloadAll()
        return milestone
    }

    @discardableResult
    func updateMilestone(
        id: String,
        title: String? = nil,
        description: String? = nil,
        targetDate: Date? = nil,
        status: MilestoneStatus? = nil,
        projectId: String?? = nil,
        relatedIssueIdentifiers: [String]? = nil,
        actor: String = "Riyu"
    ) async throws -> Milestone {
        if let relatedIssueIdentifiers {
            try ensureRelatedIssuesExist(relatedIssueIdentifiers)
        }
        let updated = try await db.write { db -> Milestone in
            guard var ms = try Milestone.fetchOne(db, key: id) else { throw StoreError.notFound }
            var changes: [String] = []
            if let title {
                let t = Self.normalizeTitle(title)
                guard !t.isEmpty else { throw StoreError.emptyTitle }
                if t != ms.title {
                    ms.title = t
                    changes.append("title")
                }
            }
            if let description, description != ms.description {
                ms.description = description
                changes.append("description")
            }
            if let targetDate, targetDate != ms.targetDate {
                ms.targetDate = targetDate
                changes.append("targetDate")
            }
            if let status, status != ms.status {
                ms.status = status
                changes.append("status → \(status.rawValue)")
            }
            if let projectId {
                ms.projectId = projectId
                changes.append("project")
            }
            if let relatedIssueIdentifiers {
                // Existence checked on MainActor before write when possible; format always.
                try Self.validateRelatedIdentifierFormat(relatedIssueIdentifiers)
                let known = try Set(Issue.filter(sql: "deletedAt IS NULL").fetchAll(db).map { $0.identifier.uppercased() })
                let unknown = relatedIssueIdentifiers
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !known.contains($0.uppercased()) }
                if !unknown.isEmpty {
                    throw StoreError.unknownRelatedIssue(unknown.joined(separator: ", "))
                }
                ms.relatedIssueIdentifiers = Milestone.encodeIdentifiers(relatedIssueIdentifiers)
                changes.append("relatedIssues")
            }
            ms.updatedAt = Date()
            try ms.update(db)
            if !changes.isEmpty {
                try ActivityLogger.insert(
                    db,
                    actor: actor,
                    action: ActivityAction.updated_milestone.rawValue,
                    summary: "\(actor) updated milestone “\(ms.title)” (\(changes.joined(separator: ", ")))",
                    projectId: ms.projectId,
                    kind: .system
                )
            }
            return ms
        }
        try await reloadAll()
        return updated
    }

    func deleteMilestone(_ id: String) async throws {
        try await db.write { db in
            _ = try Milestone.deleteOne(db, key: id)
        }
        try await reloadAll()
    }

    /// Re-seed the Product/Ops/Comms demo conversation (for existing DBs / demos).
    func seedDemoAgentActivity() async {
        do {
            try await db.write { db in
                try SeedData.seedMilestonesIfNeeded(db)
                try SeedData.enrichBotDialogueIfThin(db)
                // If already rich, still append a fresh beat set for demos when user clicks.
                let targeted = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM activity WHERE targetActor IS NOT NULL AND TRIM(targetActor) != ''"
                ) ?? 0
                if targeted == 0 {
                    try SeedData.seedDemoAgentActivity(db)
                } else {
                    // Re-seed richer dialogue so the button always feels useful.
                    try SeedData.seedDemoAgentActivity(db)
                }
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

    func listMilestones(projectKey: String? = nil, status: MilestoneStatus? = nil) -> [Milestone] {
        var items = milestones
        if let projectKey {
            if projectKey.lowercased() == "studio" || projectKey.lowercased() == "studio-wide" {
                items = items.filter { $0.projectId == nil }
            } else if let p = projects.first(where: { $0.key.caseInsensitiveCompare(projectKey) == .orderedSame }) {
                items = items.filter { $0.projectId == p.id }
            }
        }
        if let status {
            items = items.filter { $0.status == status }
        }
        return items.sorted { $0.targetDate < $1.targetDate }
    }

    /// Chronological comments + activity for one issue (bot thread).
    func botThread(issueIdOrIdentifier: String) -> (issue: Issue, comments: [Comment], activities: [Activity])? {
        guard let issue = issues.first(where: {
            $0.id == issueIdOrIdentifier || $0.identifier.caseInsensitiveCompare(issueIdOrIdentifier) == .orderedSame
        }) else { return nil }
        let threadComments = comments(for: issue)
        let threadActivity = activities
            .filter { $0.issueId == issue.id }
            .sorted { $0.createdAt < $1.createdAt }
        return (issue, threadComments, threadActivity)
    }


    // MARK: - GitHub link / sync

    @discardableResult
    func setProjectGitHubRepo(projectKey: String? = nil, projectId: String? = nil, repo: String?, actor: String = "Riyu") async throws -> Project {
        let keyOrId = (projectId?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? (projectKey?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        guard let keyOrId else { throw StoreError.notFound }
        let normalized: String?
        if let repo, !repo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let n = GitHubIssueLink.normalizeRepo(repo) else { throw StoreError.invalidGitHubRepo(repo) }
            normalized = n
        } else {
            normalized = nil
        }
        let updated = try await db.write { db -> Project in
            guard var project = try Self.projectsLookup(db, keyOrId: keyOrId) else {
                throw StoreError.notFound
            }
            project.githubRepo = normalized
            try project.update(db)
            let summary: String
            if let normalized {
                summary = "\(actor) set \(project.key) GitHub repo to \(normalized)"
            } else {
                summary = "\(actor) cleared \(project.key) GitHub repo"
            }
            try ActivityLogger.insert(
                db,
                actor: actor,
                action: ActivityAction.set_project_github_repo.rawValue,
                summary: summary,
                projectId: project.id,
                kind: .system
            )
            return project
        }
        try await reloadAll()
        return projects.first(where: { $0.id == updated.id }) ?? updated
    }

    @discardableResult
    func linkIssueGitHub(
        identifier: String? = nil,
        id: String? = nil,
        number: Int? = nil,
        url: String? = nil,
        actor: String = "Riyu"
    ) async throws -> Issue {
        let key = (id?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? (identifier?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        guard let key else { throw StoreError.notFound }

        let parsed = GitHubIssueLink.parseIssueURL(url)
        var resolvedNumber = number ?? parsed.number
        var resolvedURL = url?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = resolvedURL, value.isEmpty { resolvedURL = nil }
        let urlRepo = parsed.repo

        if resolvedNumber == nil, let resolvedURL {
            resolvedNumber = GitHubIssueLink.parseIssueURL(resolvedURL).number
        }

        guard resolvedNumber != nil || resolvedURL != nil else {
            throw StoreError.invalidGitHubLink
        }

        let initialNumber = resolvedNumber
        let initialURL = resolvedURL
        let initialUrlRepo = urlRepo

        let updated = try await db.write { db -> Issue in
            guard var issue = try Self.fetchIssue(db, key: key) else { throw StoreError.notFound }
            if issue.deletedAt != nil { throw StoreError.notFound }
            guard var project = try Project.fetchOne(db, key: issue.projectId) else { throw StoreError.noProject }

            if (project.githubRepo == nil || project.githubRepo?.isEmpty == true), let initialUrlRepo {
                project.githubRepo = initialUrlRepo
                try project.update(db)
            }

            var finalNumber = initialNumber
            var finalURL = initialURL
            if finalURL == nil, let num = finalNumber {
                if let repo = GitHubIssueLink.normalizeRepo(project.githubRepo) ?? initialUrlRepo {
                    finalURL = GitHubIssueLink.buildIssueURL(repo: repo, number: num)
                } else {
                    throw StoreError.missingGitHubRepo
                }
            }
            if finalNumber == nil, let finalURL {
                finalNumber = GitHubIssueLink.parseIssueURL(finalURL).number
            }
            guard let number = finalNumber else {
                throw StoreError.invalidGitHubLink
            }
            guard let link = finalURL else {
                throw StoreError.missingGitHubRepo
            }

            issue.githubIssueNumber = number
            issue.githubIssueUrl = link
            issue.updatedAt = Date()
            try issue.update(db)
            try ActivityLogger.insert(
                db,
                actor: actor,
                action: ActivityAction.linked_github_issue.rawValue,
                summary: "\(actor) linked \(issue.identifier) to \(link)",
                issueId: issue.id,
                projectId: issue.projectId,
                kind: .system
            )
            return issue
        }
        try await reloadAll()
        return issues.first(where: { $0.id == updated.id }) ?? updated
    }

    @discardableResult
    func unlinkIssueGitHub(identifier: String? = nil, id: String? = nil, actor: String = "Riyu") async throws -> Issue {
        let key = (id?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? (identifier?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        guard let key else { throw StoreError.notFound }
        let updated = try await db.write { db -> Issue in
            guard var issue = try Self.fetchIssue(db, key: key) else { throw StoreError.notFound }
            if issue.deletedAt != nil { throw StoreError.notFound }
            issue.githubIssueNumber = nil
            issue.githubIssueUrl = nil
            issue.updatedAt = Date()
            try issue.update(db)
            try ActivityLogger.insert(
                db,
                actor: actor,
                action: ActivityAction.unlinked_github_issue.rawValue,
                summary: "\(actor) unlinked GitHub from \(issue.identifier)",
                issueId: issue.id,
                projectId: issue.projectId,
                kind: .system
            )
            return issue
        }
        try await reloadAll()
        return issues.first(where: { $0.id == updated.id }) ?? updated
    }

    @discardableResult
    func createGitHubIssue(identifier: String? = nil, id: String? = nil, actor: String = "Riyu") async throws -> Issue {
        let key = (id?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? (identifier?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        guard let key else { throw StoreError.notFound }
        guard let issue = issues.first(where: {
            $0.id == key || $0.identifier.caseInsensitiveCompare(key) == .orderedSame
        }), issue.deletedAt == nil else { throw StoreError.notFound }
        guard let project = project(for: issue) else { throw StoreError.noProject }
        guard let repo = GitHubIssueLink.normalizeRepo(project.githubRepo) else {
            throw StoreError.missingGitHubRepo
        }

        let body = """
        \(issue.descriptionMarkdown)

        ---
        Arkboard: \(issue.identifier)
        """
        let createdURL = try await Self.runGhIssueCreate(repo: repo, title: issue.title, body: body)
        let parsed = GitHubIssueLink.parseIssueURL(createdURL)
        guard let number = parsed.number else {
            throw StoreError.githubCLIFailed("Could not parse issue URL from gh: \(createdURL)")
        }
        let url = parsed.repo != nil ? createdURL.trimmingCharacters(in: .whitespacesAndNewlines) : GitHubIssueLink.buildIssueURL(repo: repo, number: number)

        let updated = try await db.write { db -> Issue in
            guard var fresh = try Issue.fetchOne(db, key: issue.id) else { throw StoreError.notFound }
            fresh.githubIssueNumber = number
            fresh.githubIssueUrl = url
            fresh.updatedAt = Date()
            try fresh.update(db)
            try ActivityLogger.insert(
                db,
                actor: actor,
                action: ActivityAction.created_github_issue.rawValue,
                summary: "\(actor) created GitHub issue for \(fresh.identifier): \(url)",
                issueId: fresh.id,
                projectId: fresh.projectId,
                kind: .system
            )
            return fresh
        }
        try await reloadAll()
        return issues.first(where: { $0.id == updated.id }) ?? updated
    }

    nonisolated private static func fetchIssue(_ db: Database, key: String) throws -> Issue? {
        if let byId = try Issue.fetchOne(db, key: key) { return byId }
        return try Issue
            .filter(sql: "LOWER(identifier) = LOWER(?)", arguments: [key])
            .fetchOne(db)
    }

    nonisolated private static func projectsLookup(_ db: Database, keyOrId: String) throws -> Project? {
        if let byId = try Project.fetchOne(db, key: keyOrId) { return byId }
        return try Project
            .filter(sql: "LOWER(key) = LOWER(?)", arguments: [keyOrId])
            .fetchOne(db)
    }

    nonisolated private static func runGhIssueCreate(repo: String, title: String, body: String) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let gh = Self.resolveGhPath()
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: gh)
                    process.arguments = ["issue", "create", "-R", repo, "--title", title, "--body", body]
                    let out = Pipe()
                    let err = Pipe()
                    process.standardOutput = out
                    process.standardError = err
                    try process.run()
                    process.waitUntilExit()
                    let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    guard process.terminationStatus == 0 else {
                        let msg = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                        cont.resume(throwing: StoreError.githubCLIFailed(msg.isEmpty ? "gh exited \(process.terminationStatus)" : msg))
                        return
                    }
                    let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    // gh prints the URL on its own line
                    if let line = trimmed.split(whereSeparator: { $0.isNewline }).map(String.init).first(where: { $0.contains("github.com/") }) {
                        cont.resume(returning: line.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else if trimmed.contains("github.com/") {
                        cont.resume(returning: trimmed)
                    } else {
                        cont.resume(throwing: StoreError.githubCLIFailed("Unexpected gh output: \(trimmed)"))
                    }
                } catch {
                    cont.resume(throwing: StoreError.githubCLIFailed(error.localizedDescription))
                }
            }
        }
    }

    nonisolated private static func resolveGhPath() -> String {
        let candidates = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return "/opt/homebrew/bin/gh"
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
            "completedAt": issue.completedAt.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull(),
            "deletedAt": issue.deletedAt.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull(),
            "githubIssueNumber": issue.githubIssueNumber ?? NSNull(),
            "githubIssueUrl": issue.githubIssueUrl ?? NSNull(),
        ]
    }

    func projectDictionary(_ project: Project) -> [String: Any] {
        [
            "id": project.id,
            "key": project.key,
            "name": project.name,
            "color": project.color,
            "issueCount": activeIssues.filter { $0.projectId == project.id }.count,
            "githubRepo": project.githubRepo ?? NSNull(),
            "createdAt": ISO8601DateFormatter().string(from: project.createdAt),
        ]
    }

    func activityDictionary(_ activity: Activity) -> [String: Any] {
        [
            "id": activity.id,
            "createdAt": ISO8601DateFormatter().string(from: activity.createdAt),
            "actor": activity.actor,
            "targetActor": activity.targetActor ?? NSNull(),
            "targetActors": activity.targetActors,
            "action": activity.action,
            "kind": activity.kind,
            "issueId": activity.issueId ?? NSNull(),
            "projectId": activity.projectId ?? NSNull(),
            "issueIdentifier": issue(forActivity: activity)?.identifier ?? NSNull(),
            "projectKey": project(forActivity: activity)?.key ?? NSNull(),
            "summary": activity.summary,
        ]
    }

    func milestoneDictionary(_ milestone: Milestone) -> [String: Any] {
        [
            "id": milestone.id,
            "projectId": milestone.projectId ?? NSNull(),
            "projectKey": project(forMilestone: milestone)?.key ?? NSNull(),
            "title": milestone.title,
            "description": milestone.description,
            "targetDate": ISO8601DateFormatter().string(from: milestone.targetDate),
            "status": milestone.status.rawValue,
            "relatedIssueIdentifiers": milestone.relatedIdentifiers,
            "createdAt": ISO8601DateFormatter().string(from: milestone.createdAt),
            "updatedAt": ISO8601DateFormatter().string(from: milestone.updatedAt),
        ]
    }

    /// Format + existence check for milestone related issues (active identifiers only).
    func ensureRelatedIssuesExist(_ ids: [String]) throws {
        try Self.validateRelatedIdentifierFormat(ids)
        let known = Set(activeIssues.map { $0.identifier.uppercased() })
        var unknown: [String] = []
        for raw in ids {
            let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { continue }
            if !known.contains(id.uppercased()) {
                unknown.append(id)
            }
        }
        if !unknown.isEmpty {
            throw StoreError.unknownRelatedIssue(unknown.joined(separator: ", "))
        }
    }

    /// Basic related-issue identifier check: KEY-123 (2–6 alnum key + digits).
    nonisolated static func validateRelatedIdentifierFormat(_ ids: [String]) throws {
        let pattern = #"^[A-Za-z][A-Za-z0-9]{1,5}-\d+$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        for raw in ids {
            let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { continue }
            let range = NSRange(id.startIndex..<id.endIndex, in: id)
            if regex.firstMatch(in: id, options: [], range: range) == nil {
                throw StoreError.invalidRelatedIssue(id)
            }
        }
    }

    /// Legacy name — format only. Prefer `ensureRelatedIssuesExist` for milestone writes.
    nonisolated static func validateRelatedIdentifiers(_ ids: [String]) throws {
        try validateRelatedIdentifierFormat(ids)
    }

    /// Collapse embedded/consecutive whitespace (including newlines) to single spaces for UI safety.
    nonisolated static func normalizeTitle(_ title: String) -> String {
        let parts = title.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return parts.joined(separator: " ")
    }

    /// Trim + case-insensitive dedupe, preserving first-seen spelling. Empty names dropped.
    /// An issue may carry both `feature` and `bug` (and any other distinct labels) at once.
    nonisolated static func dedupeLabelNames(_ names: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in names {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            if seen.insert(key).inserted {
                result.append(name)
            }
        }
        return result
    }

    nonisolated private static func resolveOrCreateLabel(named labelName: String, db: Database) throws -> IssueTag {
        if let existing = try IssueTag
            .filter(sql: "LOWER(name) = LOWER(?)", arguments: [labelName])
            .fetchOne(db) {
            return existing
        }
        let label = IssueTag(id: UUID().uuidString, name: labelName, color: Self.randomColor())
        try label.insert(db)
        return label
    }

    nonisolated private static func randomColor() -> String {
        let colors = ["#EB5757", "#F2C94C", "#27AE60", "#4EA7FC", "#BB87FC", "#F2994A", "#56CCF2"]
        return colors.randomElement() ?? "#5E6AD2"
    }
}

enum StoreError: LocalizedError {
    case emptyTitle
    case emptyComment
    case noProject
    case notFound
    case invalidProjectKey
    case invalidStatus(String)
    case invalidPriority(String)
    case invalidDate(String)
    case invalidRelatedIssue(String)
    case unknownRelatedIssue(String)
    case invalidGitHubRepo(String)
    case missingGitHubRepo
    case invalidGitHubLink
    case githubCLIFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyTitle: return "Title cannot be empty"
        case .emptyComment: return "Comment cannot be empty"
        case .noProject: return "No project selected"
        case .notFound: return "Item not found"
        case .invalidProjectKey: return "Project key must be at least 2 alphanumeric characters"
        case .invalidStatus(let value):
            return "Invalid status '\(value)'. Expected one of: backlog, todo, in_progress, done, canceled"
        case .invalidPriority(let value):
            return "Invalid priority '\(value)'. Expected one of: none, low, medium, high, urgent"
        case .invalidDate(let value):
            return "Invalid date '\(value)'. Expected ISO8601 or yyyy-MM-dd"
        case .invalidRelatedIssue(let value):
            return "Invalid related issue id '\(value)'. Expected KEY-123 (e.g. ARK-1)"
        case .unknownRelatedIssue(let value):
            return "Unknown related issue '\(value)'. No issue exists with that identifier."
        case .invalidGitHubRepo(let value):
            return "Invalid GitHub repository '\(value)'. Use owner/name (for example diliprt/arkboard)."
        case .missingGitHubRepo:
            return "This project has no GitHub repository set."
        case .invalidGitHubLink:
            return "Provide a GitHub issue URL or number (for example https://github.com/owner/repo/issues/1 or #12)."
        case .githubCLIFailed(let value):
            return "GitHub CLI failed: \(value)"
        }
    }
}
