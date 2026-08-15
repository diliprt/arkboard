import Foundation

enum JSONPayload {
    static func json(_ value: String?) -> Any {
        value ?? NSNull()
    }

    static func json(_ value: Date?) -> Any {
        guard let value else { return NSNull() }
        return StudioISO8601.string(from: value)
    }

    static func metadataObject(_ raw: String) -> Any {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
        else { return [:] }
        return object
    }

    static func project(_ project: Project, openIssueCount: Int) -> [String: Any] {
        [
            "id": project.id,
            "key": project.key,
            "name": project.name,
            "color": project.color,
            "icon": project.icon,
            "summary": project.summary,
            "repoPath": json(project.repoPath),
            "githubRepo": json(project.githubRepo),
            "pinned": project.pinned,
            "openIssueCount": openIssueCount,
            "createdAt": StudioISO8601.string(from: project.createdAt),
        ]
    }

    static func issue(_ issue: Issue, project: Project?, labels: [String]) -> [String: Any] {
        [
            "id": issue.id,
            "identifier": issue.identifier,
            "projectId": issue.projectId,
            "projectKey": project?.key ?? NSNull(),
            "title": issue.title,
            "body": issue.bodyMarkdown,
            "status": issue.status.rawValue,
            "priority": issue.priority.rawValue,
            "assignee": json(issue.assignee),
            "labels": labels,
            "createdAt": StudioISO8601.string(from: issue.createdAt),
            "updatedAt": StudioISO8601.string(from: issue.updatedAt),
            "completedAt": json(issue.completedAt),
            "archivedAt": json(issue.archivedAt),
        ]
    }

    static func comment(_ comment: Comment, issue: Issue?) -> [String: Any] {
        [
            "id": comment.id,
            "issueId": comment.issueId,
            "issueIdentifier": issue?.identifier ?? NSNull(),
            "body": comment.bodyMarkdown,
            "author": comment.author,
            "createdAt": StudioISO8601.string(from: comment.createdAt),
        ]
    }

    static func activity(_ row: Activity, project: Project?, issue: Issue?, capability: Capability?) -> [String: Any] {
        [
            "id": row.id,
            "createdAt": StudioISO8601.string(from: row.createdAt),
            "actor": row.actor,
            "targetActors": row.targets,
            "kind": row.kind.rawValue,
            "action": row.action.rawValue,
            "body": row.body,
            "projectId": json(row.projectId),
            "projectKey": json(project?.key),
            "issueId": json(row.issueId),
            "issueIdentifier": json(issue?.identifier),
            "capabilityId": json(row.capabilityId),
            "capabilityIdentifier": json(capability?.identifier),
            "milestoneId": json(row.milestoneId),
            "metadata": metadataObject(row.metadata),
        ]
    }

    static func milestone(_ milestone: Milestone, project: Project?) -> [String: Any] {
        [
            "id": milestone.id,
            "projectId": json(milestone.projectId),
            "projectKey": json(project?.key),
            "title": milestone.title,
            "body": milestone.bodyMarkdown,
            "targetDate": StudioISO8601.string(from: milestone.targetDate),
            "status": milestone.status.rawValue,
            "relatedIssueIdentifiers": milestone.relatedIdentifiers,
            "dependsOn": milestone.dependencyIds,
            "createdAt": StudioISO8601.string(from: milestone.createdAt),
            "updatedAt": StudioISO8601.string(from: milestone.updatedAt),
        ]
    }

    static func capability(_ capability: Capability, project: Project?) -> [String: Any] {
        [
            "id": capability.id,
            "identifier": capability.identifier,
            "projectId": capability.projectId,
            "projectKey": project?.key ?? NSNull(),
            "title": capability.title,
            "note": capability.note,
            "state": capability.state.rawValue,
            "health": capability.health.rawValue,
            "docPath": json(capability.docPath),
            "docAnchor": json(capability.docAnchor),
            "linkedIssueIdentifiers": capability.linkedIdentifiers,
            "checkedAt": json(capability.checkedAt),
            "createdAt": StudioISO8601.string(from: capability.createdAt),
            "updatedAt": StudioISO8601.string(from: capability.updatedAt),
        ]
    }

    static func document(_ document: StudioDocument) -> [String: Any] {
        [
            "path": document.path,
            "tab": document.tab.rawValue,
            "title": document.title,
            "bytes": document.bytes,
            "isImage": document.isImage,
            "modifiedAt": StudioISO8601.string(from: document.modifiedAt),
        ]
    }
}
