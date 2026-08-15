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
        guard count == 0 else {
            try seedMilestonesIfNeeded(db)
            try seedDemoAgentActivityIfNeeded(db)
            try enrichBotDialogueIfThin(db)
            try seedRequirementsIfNeeded(db)
            try ensureArkGitHubRepo(db)
            return
        }

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
            issueCounter: 0,
            githubRepo: "diliprt/arkboard"
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

        try seedMilestonesIfNeeded(db)
        try seedDemoAgentActivity(db)
        try seedRequirementsIfNeeded(db)
    }

    /// Auto-seed when the activity table is empty (fresh install or post-migration).
    static func seedDemoAgentActivityIfNeeded(_ db: Database) throws {
        let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM activity") ?? 0
        guard count == 0 else { return }
        try seedDemoAgentActivity(db)
    }

    /// If activity exists but has no bot↔bot targeting, append the richer dialogue.
    static func enrichBotDialogueIfThin(_ db: Database) throws {
        let targeted = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM activity WHERE targetActor IS NOT NULL AND TRIM(targetActor) != ''"
        ) ?? 0
        if targeted > 0 { return }
        try seedDemoAgentActivity(db)
    }

    static func seedMilestonesIfNeeded(_ db: Database) throws {
        let count = try Milestone.fetchCount(db)
        guard count == 0 else { return }
        try seedMilestones(db)
    }

    static func seedMilestones(_ db: Database) throws {
        let ark = try Project.filter(Column("key") == "ARK").fetchOne(db)
        let ops = try Project.filter(Column("key") == "OPS").fetchOne(db)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        func day(_ offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: today) ?? today
        }

        struct SeedMS {
            let projectId: String?
            let title: String
            let description: String
            let targetOffset: Int
            let status: MilestoneStatus
            let related: [String]
        }

        let seeds: [SeedMS] = [
            SeedMS(projectId: nil, title: "Studio weekly sync", description: "Cross-project check-in for Origin Ark.",
                   targetOffset: -3, status: .done, related: []),
            SeedMS(projectId: ark?.id, title: "Portfolio + Activity ship", description: "Bird's-eye Portfolio and agent Activity feed live.",
                   targetOffset: -1, status: .done, related: ["ARK-1"]),
            SeedMS(projectId: ark?.id, title: "Milestones + Timeline", description: "Cross-project timeline and milestone cards.",
                   targetOffset: 2, status: .in_progress, related: ["ARK-1", "ARK-2"]),
            SeedMS(projectId: ark?.id, title: "Agent handoff polish", description: "Visible bot↔bot mentions in Activity.",
                   targetOffset: 5, status: .planned, related: ["ARK-3"]),
            SeedMS(projectId: ops?.id, title: "MCP bridge verified", description: "Cursor stdio bridge + smoke.sh green.",
                   targetOffset: 1, status: .in_progress, related: ["OPS-1"]),
            SeedMS(projectId: ops?.id, title: "Launch hold decision", description: "Comms gate before public mention.",
                   targetOffset: 7, status: .planned, related: ["OPS-2"]),
            SeedMS(projectId: nil, title: "Origin Ark demo day", description: "Studio-wide demo for Riyu.",
                   targetOffset: 10, status: .planned, related: ["ARK-1", "OPS-2"]),
            SeedMS(projectId: ark?.id, title: "Empty-state polish pass", description: "Missed earlier window — catch up.",
                   targetOffset: -10, status: .missed, related: ["ARK-5"]),
        ]

        let now = Date()
        for s in seeds {
            let ms = Milestone(
                id: UUID().uuidString,
                projectId: s.projectId,
                title: s.title,
                description: s.description,
                targetDate: day(s.targetOffset),
                status: s.status,
                relatedIssueIdentifiers: Milestone.encodeIdentifiers(s.related),
                createdAt: now.addingTimeInterval(-86400),
                updatedAt: now
            )
            try ms.insert(db)
        }
    }

    /// Scripted Product / Ops / Comms conversation with @mentions (bot↔bot).
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
            let targetActor: String?
            let kind: ActivityKind
        }

        let beats: [Beat] = [
            Beat(offset: 0, actor: "Product", action: ActivityAction.updated_issue.rawValue, issue: ship,
                 summary: "Product set \(ship.identifier) to in_progress — overnight ship is the focus.",
                 commentBody: nil, targetActor: nil, kind: .system),
            Beat(offset: 90, actor: "Product", action: ActivityAction.commented.rawValue, issue: ship,
                 summary: "Product → Ops, Comms on \(ship.identifier): Need MCP bind confirmation before we call it shippable.",
                 commentBody: "@Ops @Comms can you confirm MCP binds to 127.0.0.1:7420 only? Portfolio + Activity are ready for the morning demo — need your green light.",
                 targetActor: "Ops, Comms", kind: .mention),
            Beat(offset: 210, actor: "Ops", action: ActivityAction.commented.rawValue, issue: ship,
                 summary: "Ops → Product on \(ship.identifier): Confirmed loopback bind; smoke next.",
                 commentBody: "@Product confirmed — listener is loopback-only on :7420. I'll run smoke.sh after the next create_issue with actor. Handing off health check to myself once UI lands.",
                 targetActor: "Product", kind: .mention),
            Beat(offset: 360, actor: "Comms", action: ActivityAction.commented.rawValue, issue: ship,
                 summary: "Comms → Product on \(ship.identifier): Hold external launch language.",
                 commentBody: "@Product hold the public launch blurb — Activity + Milestones are internal-only until Riyu signs off. I'll draft the handoff note after Ops finishes smoke.",
                 targetActor: "Product", kind: .handoff),
            Beat(offset: 480, actor: "Ops", action: ActivityAction.commented.rawValue, issue: mcp,
                 summary: "Ops → Comms on \(mcp.identifier): smoke covers actor + list_activity.",
                 commentBody: "@Comms smoke.sh will cover create_issue with actor + list_activity so you can quote “agents are talking” truthfully.",
                 targetActor: "Comms", kind: .mention),
            Beat(offset: 600, actor: "Product", action: ActivityAction.commented.rawValue, issue: mcp,
                 summary: "Product → Ops on \(mcp.identifier): Pass optional actor on mutating tools.",
                 commentBody: "@Ops please pass optional `actor` on create/update/comment so Activity shows Product / Ops / Comms clearly — default Agent if omitted.",
                 targetActor: "Ops", kind: .mention),
            Beat(offset: 720, actor: "Ops", action: ActivityAction.commented.rawValue, issue: ship,
                 summary: "Ops → Comms on \(ship.identifier): Health OK — you can draft.",
                 commentBody: "@Comms health is green. Handing off: draft the morning blurb with one sentence on bot↔bot visibility (Product → Ops avatars).",
                 targetActor: "Comms", kind: .handoff),
            Beat(offset: 840, actor: "Comms", action: ActivityAction.commented.rawValue, issue: ship,
                 summary: "Comms → Riyu on \(ship.identifier): Activity copy ready; launch still on hold.",
                 commentBody: "@Riyu Activity feed shows Product → Ops with dual avatars. Launch language stays on hold until you say go.",
                 targetActor: "Riyu", kind: .mention),
            Beat(offset: 960, actor: "Riyu", action: ActivityAction.commented.rawValue, issue: ship,
                 summary: "Riyu → Product on \(ship.identifier): Ship Portfolio Timeline + Milestones.",
                 commentBody: "@Product looking good. Ship Portfolio Timeline + Milestones and keep the bot dialogue visible in Activity.",
                 targetActor: "Product", kind: .mention),
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
                createdAt: at,
                targetActor: beat.targetActor,
                kind: beat.kind
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
            let stamp = now.addingTimeInterval(Double(-idx) * 1800)
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
                updatedAt: stamp,
                completedAt: seed.status == .done ? stamp : nil,
                deletedAt: nil,
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

    static func seedRequirementsIfNeeded(_ db: Database) throws {
        let count = try Requirement.fetchCount(db)
        guard count == 0 else { return }
        try seedRequirements(db)
    }

    /// Seed design requirements from existing ARK feature titles. Does not touch issues.
    static func seedRequirements(_ db: Database) throws {
        guard var ark = try Project.filter(Column("key") == "ARK").fetchOne(db) else { return }
        let now = Date()
        struct SeedReq {
            let title: String
            let body: String
            let implementing: RequirementImplementing
            let working: RequirementWorking
            let linked: [String]
        }
        let seeds: [SeedReq] = [
            SeedReq(
                title: "Ship Arkboard v1 overnight",
                body: "Working Linear-style local macOS app with MCP. Human steers requirements; agents execute.",
                implementing: .implementing,
                working: .working,
                linked: ["ARK-1"]
            ),
            SeedReq(
                title: "List + Board views",
                body: "Segmented list and kanban by status for Inbox and per-project browsers.",
                implementing: .implemented,
                working: .working,
                linked: ["ARK-2"]
            ),
            SeedReq(
                title: "Local MCP HTTP on :7420",
                body: "Agents list/create/update issues and requirements via localhost with actor attribution.",
                implementing: .implementing,
                working: .working,
                linked: ["ARK-3"]
            ),
            SeedReq(
                title: "Seed demo data",
                body: "First-launch sample projects, issues, and design requirements so Monitor is not empty.",
                implementing: .implemented,
                working: .working,
                linked: ["ARK-4"]
            ),
            SeedReq(
                title: "Polish empty states",
                body: "Friendly empty project / no-issue UI that does not push New Issue as the primary action.",
                implementing: .not_started,
                working: .unknown,
                linked: ["ARK-5"]
            ),
        ]

        var inserted: [Requirement] = []
        for (idx, seed) in seeds.enumerated() {
            ark.requirementCounter += 1
            let stamp = now.addingTimeInterval(Double(-idx) * 900)
            let req = Requirement(
                id: UUID().uuidString,
                identifier: "\(ark.key)-R\(ark.requirementCounter)",
                projectId: ark.id,
                title: seed.title,
                bodyMarkdown: seed.body,
                implementing: seed.implementing,
                working: seed.working,
                sortOrder: Double(idx),
                createdAt: now.addingTimeInterval(Double(-idx) * 1800),
                updatedAt: stamp,
                linkedIssueIdentifiers: Requirement.encodeIdentifiers(seed.linked)
            )
            try req.insert(db)
            inserted.append(req)
            try ActivityLogger.insert(
                db,
                actor: "Product",
                action: ActivityAction.created_requirement.rawValue,
                summary: "Product created requirement \(req.identifier): \(req.title)",
                projectId: ark.id,
                requirementId: req.id,
                createdAt: stamp,
                kind: .system
            )
        }
        try ark.update(db)

        if let ship = inserted.first {
            let comment = RequirementComment(
                id: UUID().uuidString,
                requirementId: ship.id,
                bodyMarkdown: "@Riyu Monitor is now centered on this requirement — implementing and working are the only health signals.",
                authorName: "Product",
                createdAt: now.addingTimeInterval(-120)
            )
            try comment.insert(db)
            try ActivityLogger.insert(
                db,
                actor: "Product",
                action: ActivityAction.commented.rawValue,
                summary: "Product → Riyu on \(ship.identifier): Monitor centered on design requirements.",
                projectId: ark.id,
                requirementId: ship.id,
                createdAt: now.addingTimeInterval(-120),
                targetActor: "Riyu",
                kind: .mention
            )
        }
        if inserted.count > 2 {
            let mcp = inserted[2]
            let comment = RequirementComment(
                id: UUID().uuidString,
                requirementId: mcp.id,
                bodyMarkdown: "@Ops list_requirements / update_requirement need actor so Activity shows who steered the signals.",
                authorName: "Product",
                createdAt: now.addingTimeInterval(-60)
            )
            try comment.insert(db)
            try ActivityLogger.insert(
                db,
                actor: "Product",
                action: ActivityAction.commented.rawValue,
                summary: "Product → Ops on \(mcp.identifier): pass actor on requirement mutations.",
                projectId: ark.id,
                requirementId: mcp.id,
                createdAt: now.addingTimeInterval(-60),
                targetActor: "Ops",
                kind: .mention
            )
        }
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
        requirementId: String? = nil,
        createdAt: Date = Date(),
        targetActor: String? = nil,
        kind: ActivityKind = .system
    ) throws {
        let trimmedActor = actor.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = targetActor?.trimmingCharacters(in: .whitespacesAndNewlines)
        let activity = Activity(
            id: UUID().uuidString,
            createdAt: createdAt,
            actor: trimmedActor.isEmpty ? "Agent" : trimmedActor,
            action: action,
            issueId: issueId,
            projectId: projectId,
            requirementId: requirementId,
            summary: summary,
            targetActor: (trimmedTarget?.isEmpty == false) ? trimmedTarget : nil,
            kind: kind.rawValue
        )
        try activity.insert(db)
    }
}


extension SeedData {
    static func ensureArkGitHubRepo(_ db: Database) throws {
        guard var ark = try Project.filter(Column("key") == "ARK").fetchOne(db) else { return }
        if ark.githubRepo == nil || ark.githubRepo?.isEmpty == true {
            ark.githubRepo = "diliprt/arkboard"
            try ark.update(db)
        }
    }
}
