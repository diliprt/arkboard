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
