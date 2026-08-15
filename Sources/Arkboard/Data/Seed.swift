import Foundation
import GRDB

enum Seed {
    static func runIfEmpty(_ db: Database) throws {
        if try Workspace.fetchCount(db) > 0 { return }
        let now = Date()
        let workspace = Workspace(id: UUID().uuidString, name: "Origin Ark", createdAt: now)
        try workspace.insert(db)

        let repoPath = DocumentLibrary.resolvedRepoRoot(repoPath: nil)
        let project = Project(
            id: UUID().uuidString,
            key: "ARK",
            name: "Arkboard",
            color: ProjectMark.arkboardColor,
            icon: ProjectMark.arkboardSymbol,
            summary: "Local studio board. Humans read. Agents execute.",
            repoPath: repoPath,
            githubRepo: "diliprt/arkboard",
            issueCounter: 0,
            capabilityCounter: 5,
            sortOrder: 0,
            pinned: true,
            createdAt: now
        )
        try project.insert(db)

        let capabilities: [(String, String, String, String, String?)] = [
            ("ARK-C1", "Document home", "Project page renders product/ as a rich preview.", "product/design.md", "reading-markdown"),
            ("ARK-C2", "Monitor", "Open questions and capabilities that are not working.", "product/ui-spec.md", "monitor"),
            ("ARK-C3", "Studio API", "Localhost MCP and REST on 127.0.0.1:7420.", "product/mcp.md", "connecting"),
            ("ARK-C4", "Type scale", "Body size and face apply from the root.", "product/design.md", "type"),
            ("ARK-C5", "One scroll", "Project home pins the tab bar; contents live in the right outline.", "product/ui-spec.md", "project-home"),
        ]
        for (index, item) in capabilities.enumerated() {
            let capability = Capability(
                id: UUID().uuidString,
                identifier: item.0,
                projectId: project.id,
                title: item.1,
                note: item.2,
                state: .notStarted,
                health: .unknown,
                docPath: item.3,
                docAnchor: item.4,
                linkedIssueIdentifiers: "[]",
                sortOrder: Double(index),
                checkedAt: nil,
                createdAt: now,
                updatedAt: now
            )
            try capability.insert(db)
        }

        let milestone = Milestone(
            id: UUID().uuidString,
            projectId: project.id,
            title: "Studio board v2",
            bodyMarkdown: "Ship the design pack as a native reading room with a localhost agent API.",
            targetDate: Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now,
            status: .inProgress,
            relatedIssueIdentifiers: "[]",
            createdAt: now,
            updatedAt: now
        )
        try milestone.insert(db)

        let welcome = Activity(
            id: UUID().uuidString,
            createdAt: now,
            actor: "Arkboard",
            kind: .note,
            action: .noted,
            body: "Welcome to Origin Ark. Documents live in Git. What happens next lives here.",
            targetActors: "[]",
            projectId: project.id,
            issueId: nil,
            capabilityId: nil,
            milestoneId: nil
        )
        try welcome.insert(db)
    }
}
