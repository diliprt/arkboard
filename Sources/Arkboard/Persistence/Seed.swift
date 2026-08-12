import Foundation
import GRDB

enum SeedData {
    private struct SeedIssue {
        let title: String
        let status: IssueStatus
        let priority: IssuePriority
        let description: String
        let labelNames: [String]
    }

    static func seedIfNeeded(_ db: Database) throws {
        let count = try Project.fetchCount(db)
        guard count == 0 else { return }

        let now = Date()

        let workspace = Workspace(
            id: UUID().uuidString,
            name: "Origin Ark",
            createdAt: now
        )
        try workspace.insert(db)

        let ark = Project(
            id: UUID().uuidString,
            key: "ARK",
            name: "Arkboard",
            color: "#5E6AD2",
            createdAt: now,
            issueCounter: 0
        )
        let ops = Project(
            id: UUID().uuidString,
            key: "OPS",
            name: "Operations",
            color: "#26B5CE",
            createdAt: now,
            issueCounter: 0
        )
        try ark.insert(db)
        try ops.insert(db)

        let labels: [IssueTag] = [
            IssueTag(id: UUID().uuidString, name: "bug", color: "#EB5757"),
            IssueTag(id: UUID().uuidString, name: "feature", color: "#4EA7FC"),
            IssueTag(id: UUID().uuidString, name: "agent", color: "#F2C94C"),
            IssueTag(id: UUID().uuidString, name: "design", color: "#BB87FC"),
        ]
        for label in labels { try label.insert(db) }

        let arkIssues: [SeedIssue] = [
            SeedIssue(title: "Ship Arkboard v1 overnight", status: .in_progress, priority: .urgent,
                      description: "Working Linear-style local macOS app with MCP.", labelNames: ["feature", "agent"]),
            SeedIssue(title: "List + Board views", status: .todo, priority: .high,
                      description: "Segmented list and kanban by status.", labelNames: ["feature", "design"]),
            SeedIssue(title: "Local MCP HTTP on :7420", status: .todo, priority: .high,
                      description: "Agents list/create/update issues via localhost.", labelNames: ["agent"]),
            SeedIssue(title: "Seed demo data", status: .done, priority: .medium,
                      description: "First-launch sample projects and issues.", labelNames: ["feature"]),
            SeedIssue(title: "Polish empty states", status: .backlog, priority: .low,
                      description: "Friendly empty project / no-issue UI.", labelNames: ["design"]),
            SeedIssue(title: "Investigate GRDB migration edge cases", status: .backlog, priority: .none,
                      description: "Ensure reinstall keeps schema clean.", labelNames: ["bug"]),
        ]

        let opsIssues: [SeedIssue] = [
            SeedIssue(title: "Wire Cursor MCP config", status: .todo, priority: .medium,
                      description: "Document ~/.cursor/mcp.json snippet.", labelNames: ["agent"]),
            SeedIssue(title: "Morning handoff notes", status: .backlog, priority: .medium,
                      description: "Summarize what's done / rough for Riyu.", labelNames: ["feature"]),
        ]

        try insertIssues(db, project: ark, seeds: arkIssues, labels: labels, now: now)
        try insertIssues(db, project: ops, seeds: opsIssues, labels: labels, now: now)

        // Fresh DB: scripted multi-agent conversation so Activity is alive immediately.
        try seedDemoAgentActivity(db)
    }

    /// Auto-seed when the activity table is empty (fresh install or post-migration).
    static func seedDemoAgentActivityIfNeeded(_ db: Database) throws {
        let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM activity") ?? 0
        guard count == 0 else { return }
        try seedDemoAgentActivity(db)
    }

    /// Scripted Product / Ops / Comms conversation across a couple ARK issues.
    static func seedDemoAgentActivity(_ db: Database) throws {
        guard let ark = try Project.filter(Column("key") == "ARK").fetchOne(db) else { return }
        let issues = try Issue
            .filter(Column("projectId") == ark.id)
            .order(Column("identifier"))
            .fetchAll(db)
        guard let ship = issues.first(where: { $0.identifier.hasSuffix("-1") }) ?? issues.first else { return }
        let mcp = issues.first(where: { $0.title.localizedCaseInsensitiveContains("MCP") }) ?? issues.dropFirst().first ?? ship

        let base = Date().addingTimeInterval(-3600)
        struct Beat {
            let offset: TimeInterval
            let actor: String
            let action: String
            let issue: Issue
            let summary: String
            let commentBody: String?
        }

        let beats: [Beat] = [
            Beat(offset: 0, actor: "Product", action: ActivityAction.updated_issue.rawValue, issue: ship,
                 summary: "Product set \(ship.identifier) to in_progress — overnight ship is the focus.",
                 commentBody: nil),
            Beat(offset: 120, actor: "Product", action: ActivityAction.commented.rawValue, issue: ship,
                 summary: "Product on \(ship.identifier): Scoped List + Board + local MCP for morning demo.",
                 commentBody: "Scoped for morning: List + Board + local MCP. Portfolio overview is next so we can see the whole studio at a glance."),
            Beat(offset: 300, actor: "Ops", action: ActivityAction.commented.rawValue, issue: ship,
                 summary: "Ops on \(ship.identifier): Confirming MCP binds to 127.0.0.1:7420.",
                 commentBody: "Confirming MCP binds to 127.0.0.1:7420 only. I'll wire the Cursor stdio bridge once health returns OK."),
            Beat(offset: 480, actor: "Comms", action: ActivityAction.commented.rawValue, issue: ship,
                 summary: "Comms on \(ship.identifier): Drafting the morning handoff blurb.",
                 commentBody: "Drafting the morning handoff blurb — need one sentence on agent collaboration visibility for Riyu."),
            Beat(offset: 720, actor: "Ops", action: ActivityAction.commented.rawValue, issue: mcp,
                 summary: "Ops on \(mcp.identifier): smoke.sh covers create/list/update.",
                 commentBody: "smoke.sh will cover create_issue with actor + list_activity so we can prove agents are talking in the feed."),
            Beat(offset: 900, actor: "Product", action: ActivityAction.commented.rawValue, issue: mcp,
                 summary: "Product on \(mcp.identifier): Pass optional actor on mutating tools.",
                 commentBody: "Please pass optional `actor` on create/update/comment so Activity shows Product / Ops / Comms clearly — default Agent if omitted."),
            Beat(offset: 1080, actor: "Comms", action: ActivityAction.commented.rawValue, issue: ship,
                 summary: "Comms on \(ship.identifier): Activity feed copy is ready.",
                 commentBody: "Activity feed copy is ready: avatar initials + color per agent. Opening Activity should feel like the team is already talking."),
            Beat(offset: 1200, actor: "Riyu", action: ActivityAction.commented.rawValue, issue: ship,
                 summary: "Riyu on \(ship.identifier): Looking good — ship Portfolio + Activity.",
                 commentBody: "Looking good. Ship Portfolio + Activity; keep List/Board for project detail work."),
        ]

        for beat in beats {
            let at = base.addingTimeInterval(beat.offset)
            if let body = beat.commentBody {
                let comment = Comment(
                    id: UUID().uuidString,
                    issueId: beat.issue.id,
                    bodyMarkdown: body,
                    authorName: beat.actor,
                    createdAt: at
                )
                try comment.insert(db)
            }
            try ActivityLogger.insert(
                db,
                actor: beat.actor,
                action: beat.action,
                summary: beat.summary,
                issueId: beat.issue.id,
                projectId: ark.id,
                createdAt: at
            )
        }
    }

    private static func insertIssues(
        _ db: Database,
        project: Project,
        seeds: [SeedIssue],
        labels: [IssueTag],
        now: Date
    ) throws {
        var project = project
        let labelByName = Dictionary(uniqueKeysWithValues: labels.map { ($0.name, $0) })

        for (idx, seed) in seeds.enumerated() {
            project.issueCounter += 1
            let issue = Issue(
                id: UUID().uuidString,
                identifier: "\(project.key)-\(project.issueCounter)",
                projectId: project.id,
                title: seed.title,
                descriptionMarkdown: seed.description,
                status: seed.status,
                priority: seed.priority,
                assigneeName: nil,
                estimatePoints: nil,
                createdAt: now.addingTimeInterval(Double(-idx) * 3600),
                updatedAt: now.addingTimeInterval(Double(-idx) * 1800),
                orderInStatus: Double(idx)
            )
            try issue.insert(db)

            for name in seed.labelNames {
                if let label = labelByName[name] {
                    try IssueLabel(issueId: issue.id, labelId: label.id).insert(db)
                }
            }

            if seed.status == .in_progress {
                let comment = Comment(
                    id: UUID().uuidString,
                    issueId: issue.id,
                    bodyMarkdown: "Overnight build in progress — targeting runnable app by morning.",
                    authorName: "Riyu",
                    createdAt: now
                )
                try comment.insert(db)
            }
        }

        try project.update(db)
    }
}

enum ActivityLogger {
    static func insert(
        _ db: Database,
        actor: String,
        action: String,
        summary: String,
        issueId: String? = nil,
        projectId: String? = nil,
        createdAt: Date = Date()
    ) throws {
        let trimmedActor = actor.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity = Activity(
            id: UUID().uuidString,
            createdAt: createdAt,
            actor: trimmedActor.isEmpty ? "Agent" : trimmedActor,
            action: action,
            issueId: issueId,
            projectId: projectId,
            summary: summary
        )
        try activity.insert(db)
    }
}
