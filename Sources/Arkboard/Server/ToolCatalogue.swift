import Foundation

enum ToolCatalogue {
    static let names: [String] = [
        "list_projects", "create_project",
        "list_documents", "read_document",
        "list_issues", "get_issue", "create_issue", "update_issue", "delete_issue", "restore_issue",
        "add_comment", "post_note", "list_activity",
        "list_milestones", "create_milestone", "update_milestone",
        "list_capabilities", "create_capability", "update_capability",
    ]

    static func list() -> [[String: Any]] {
        [
            tool("list_projects", "List every project", [:]),
            tool("create_project", "Create a project", [
                "key": ["type": "string"],
                "name": ["type": "string"],
                "color": ["type": "string"],
                "summary": ["type": "string"],
                "repoPath": ["type": "string"],
                "githubRepo": ["type": "string"],
                "actor": ["type": "string"],
            ], required: ["key", "name"]),
            tool("list_documents", "List product/ documents for a project", [
                "projectKey": ["type": "string"],
                "tab": ["type": "string"],
            ], required: ["projectKey"]),
            tool("read_document", "Read one product/ document as markdown", [
                "projectKey": ["type": "string"],
                "path": ["type": "string"],
            ], required: ["projectKey", "path"]),
            tool("list_issues", "List issues", [
                "projectKey": ["type": "string"],
                "status": ["type": "string"],
                "query": ["type": "string"],
                "includeArchived": ["type": "boolean"],
                "limit": ["type": "integer"],
            ]),
            tool("get_issue", "One issue plus comments and activity", [
                "id": ["type": "string"],
                "identifier": ["type": "string"],
            ]),
            tool("create_issue", "Create an issue", [
                "title": ["type": "string"],
                "projectKey": ["type": "string"],
                "projectId": ["type": "string"],
                "body": ["type": "string"],
                "status": ["type": "string"],
                "priority": ["type": "string"],
                "labels": ["type": "array", "items": ["type": "string"]],
                "assignee": ["type": "string"],
                "actor": ["type": "string"],
            ], required: ["title"]),
            tool("update_issue", "Update an issue. Unknown status or priority rejects the whole call.", [
                "id": ["type": "string"],
                "identifier": ["type": "string"],
                "title": ["type": "string"],
                "body": ["type": "string"],
                "status": ["type": "string"],
                "priority": ["type": "string"],
                "labels": ["type": "array", "items": ["type": "string"]],
                "assignee": ["type": "string"],
                "actor": ["type": "string"],
            ]),
            tool("delete_issue", "Archive an issue (soft delete)", [
                "id": ["type": "string"],
                "identifier": ["type": "string"],
                "actor": ["type": "string"],
            ]),
            tool("restore_issue", "Restore an archived issue", [
                "id": ["type": "string"],
                "identifier": ["type": "string"],
                "actor": ["type": "string"],
            ]),
            tool("add_comment", "Comment on an issue. One activity row even with several @mentions.", [
                "identifier": ["type": "string"],
                "issueId": ["type": "string"],
                "body": ["type": "string"],
                "actor": ["type": "string"],
            ], required: ["body"]),
            tool("post_note", "Say something in Activity without an issue", [
                "body": ["type": "string"],
                "projectKey": ["type": "string"],
                "actor": ["type": "string"],
            ], required: ["body"]),
            tool("list_activity", "Recent activity, newest first", [
                "limit": ["type": "integer"],
                "projectKey": ["type": "string"],
                "kind": ["type": "string"],
                "since": ["type": "string"],
            ]),
            tool("list_milestones", "List milestones. Pass projectKey=studio for studio-wide.", [
                "projectKey": ["type": "string"],
                "status": ["type": "string"],
            ]),
            tool("create_milestone", "Create a milestone", [
                "title": ["type": "string"],
                "body": ["type": "string"],
                "targetDate": ["type": "string"],
                "status": ["type": "string"],
                "projectKey": ["type": "string"],
                "relatedIssueIdentifiers": ["type": "array", "items": ["type": "string"]],
                "actor": ["type": "string"],
            ], required: ["title"]),
            tool("update_milestone", "Update a milestone", [
                "id": ["type": "string"],
                "title": ["type": "string"],
                "body": ["type": "string"],
                "targetDate": ["type": "string"],
                "status": ["type": "string"],
                "projectKey": ["type": "string"],
                "relatedIssueIdentifiers": ["type": "array", "items": ["type": "string"]],
                "actor": ["type": "string"],
            ], required: ["id"]),
            tool("list_capabilities", "List capabilities", [
                "projectKey": ["type": "string"],
                "state": ["type": "string"],
                "health": ["type": "string"],
            ]),
            tool("create_capability", "Create a thin capability (title, ≤280 note, built?/working?)", [
                "title": ["type": "string"],
                "projectKey": ["type": "string"],
                "projectId": ["type": "string"],
                "note": ["type": "string"],
                "state": ["type": "string"],
                "health": ["type": "string"],
                "docPath": ["type": "string"],
                "docAnchor": ["type": "string"],
                "linkedIssueIdentifiers": ["type": "array", "items": ["type": "string"]],
                "actor": ["type": "string"],
            ], required: ["title"]),
            tool("update_capability", "Update a capability. Writing health stamps checkedAt.", [
                "id": ["type": "string"],
                "identifier": ["type": "string"],
                "title": ["type": "string"],
                "note": ["type": "string"],
                "state": ["type": "string"],
                "health": ["type": "string"],
                "docPath": ["type": "string"],
                "docAnchor": ["type": "string"],
                "linkedIssueIdentifiers": ["type": "array", "items": ["type": "string"]],
                "actor": ["type": "string"],
            ]),
        ]
    }

    @MainActor
    static func call(_ name: String, arguments: [String: Any], store: AppStore) async throws -> [String: Any] {
        switch name {
        case "list_projects":
            return ["projects": store.projects.map { JSONPayload.project($0, openIssueCount: store.openIssueCount(for: $0)) }]
        case "create_project":
            let project = try store.createProject(
                key: HTTPJSON.string(arguments, "key") ?? "",
                name: HTTPJSON.string(arguments, "name") ?? "",
                color: HTTPJSON.string(arguments, "color"),
                summary: HTTPJSON.string(arguments, "summary"),
                repoPath: HTTPJSON.string(arguments, "repoPath"),
                githubRepo: HTTPJSON.string(arguments, "githubRepo"),
                actor: HTTPJSON.string(arguments, "actor") ?? "Agent"
            )
            return JSONPayload.project(project, openIssueCount: 0)
        case "list_documents":
            return try await listDocuments(arguments, store: store)
        case "read_document":
            return try await readDocument(arguments, store: store)
        case "list_issues":
            return listIssues(arguments, store: store)
        case "get_issue":
            return try getIssue(arguments, store: store)
        case "create_issue":
            let issue = try store.createIssue(
                projectKey: HTTPJSON.string(arguments, "projectKey"),
                projectId: HTTPJSON.string(arguments, "projectId"),
                title: HTTPJSON.string(arguments, "title") ?? "",
                body: HTTPJSON.string(arguments, "body") ?? "",
                status: HTTPJSON.string(arguments, "status") ?? "backlog",
                priority: HTTPJSON.string(arguments, "priority") ?? "none",
                labels: HTTPJSON.strings(arguments, "labels"),
                assignee: HTTPJSON.string(arguments, "assignee"),
                actor: HTTPJSON.string(arguments, "actor") ?? "Agent"
            )
            return store.issueJSON(issue)
        case "update_issue":
            let id = HTTPJSON.string(arguments, "id") ?? HTTPJSON.string(arguments, "identifier") ?? ""
            let issue = try store.updateIssue(
                idOrIdentifier: id,
                title: HTTPJSON.string(arguments, "title"),
                body: HTTPJSON.string(arguments, "body"),
                status: HTTPJSON.string(arguments, "status"),
                priority: HTTPJSON.string(arguments, "priority"),
                labels: arguments["labels"] == nil ? nil : HTTPJSON.strings(arguments, "labels"),
                assignee: HTTPJSON.string(arguments, "assignee"),
                actor: HTTPJSON.string(arguments, "actor") ?? "Agent"
            )
            return store.issueJSON(issue)
        case "delete_issue":
            let id = HTTPJSON.string(arguments, "id") ?? HTTPJSON.string(arguments, "identifier") ?? ""
            return store.issueJSON(try store.archiveIssue(idOrIdentifier: id, actor: HTTPJSON.string(arguments, "actor") ?? "Agent"))
        case "restore_issue":
            let id = HTTPJSON.string(arguments, "id") ?? HTTPJSON.string(arguments, "identifier") ?? ""
            return store.issueJSON(try store.restoreIssue(idOrIdentifier: id, actor: HTTPJSON.string(arguments, "actor") ?? "Agent"))
        case "add_comment":
            let id = HTTPJSON.string(arguments, "issueId") ?? HTTPJSON.string(arguments, "identifier") ?? ""
            let comment = try store.addComment(idOrIdentifier: id, body: HTTPJSON.string(arguments, "body") ?? "", actor: HTTPJSON.string(arguments, "actor") ?? "Agent")
            return JSONPayload.comment(comment, issue: store.issue(idOrIdentifier: comment.issueId))
        case "post_note":
            let activity = try store.postNote(body: HTTPJSON.string(arguments, "body") ?? "", projectKey: HTTPJSON.string(arguments, "projectKey"), actor: HTTPJSON.string(arguments, "actor") ?? "Agent")
            return store.activityJSON(activity)
        case "list_activity":
            return listActivity(arguments, store: store)
        case "list_milestones":
            return listMilestones(arguments, store: store)
        case "create_milestone":
            let milestone = try store.createMilestone(
                title: HTTPJSON.string(arguments, "title") ?? "",
                body: HTTPJSON.string(arguments, "body") ?? "",
                targetDate: HTTPJSON.string(arguments, "targetDate"),
                status: HTTPJSON.string(arguments, "status") ?? "planned",
                projectKey: HTTPJSON.string(arguments, "projectKey"),
                related: HTTPJSON.strings(arguments, "relatedIssueIdentifiers"),
                actor: HTTPJSON.string(arguments, "actor") ?? "Agent"
            )
            return store.milestoneJSON(milestone)
        case "update_milestone":
            let milestone = try store.updateMilestone(
                id: HTTPJSON.string(arguments, "id") ?? "",
                title: HTTPJSON.string(arguments, "title"),
                body: HTTPJSON.string(arguments, "body"),
                targetDate: HTTPJSON.string(arguments, "targetDate"),
                status: HTTPJSON.string(arguments, "status"),
                projectKey: HTTPJSON.string(arguments, "projectKey"),
                related: arguments["relatedIssueIdentifiers"] == nil ? nil : HTTPJSON.strings(arguments, "relatedIssueIdentifiers"),
                actor: HTTPJSON.string(arguments, "actor") ?? "Agent"
            )
            return store.milestoneJSON(milestone)
        case "list_capabilities":
            return listCapabilities(arguments, store: store)
        case "create_capability":
            let capability = try store.createCapability(
                projectKey: HTTPJSON.string(arguments, "projectKey"),
                projectId: HTTPJSON.string(arguments, "projectId"),
                title: HTTPJSON.string(arguments, "title") ?? "",
                note: HTTPJSON.string(arguments, "note") ?? "",
                state: HTTPJSON.string(arguments, "state") ?? "not_started",
                health: HTTPJSON.string(arguments, "health") ?? "unknown",
                docPath: HTTPJSON.string(arguments, "docPath"),
                docAnchor: HTTPJSON.string(arguments, "docAnchor"),
                linked: HTTPJSON.strings(arguments, "linkedIssueIdentifiers"),
                actor: HTTPJSON.string(arguments, "actor") ?? "Agent"
            )
            return store.capabilityJSON(capability)
        case "update_capability":
            let id = HTTPJSON.string(arguments, "id") ?? HTTPJSON.string(arguments, "identifier") ?? ""
            let capability = try store.updateCapability(
                idOrIdentifier: id,
                title: HTTPJSON.string(arguments, "title"),
                note: HTTPJSON.string(arguments, "note"),
                state: HTTPJSON.string(arguments, "state"),
                health: HTTPJSON.string(arguments, "health"),
                docPath: HTTPJSON.string(arguments, "docPath"),
                docAnchor: HTTPJSON.string(arguments, "docAnchor"),
                linked: arguments["linkedIssueIdentifiers"] == nil ? nil : HTTPJSON.strings(arguments, "linkedIssueIdentifiers"),
                actor: HTTPJSON.string(arguments, "actor") ?? "Agent"
            )
            return store.capabilityJSON(capability)
        default:
            throw ServerError.unknownTool(name)
        }
    }

    @MainActor
    private static func listDocuments(_ arguments: [String: Any], store: AppStore) async throws -> [String: Any] {
        guard let key = HTTPJSON.string(arguments, "projectKey"), let project = store.project(key: key) else {
            throw ValidationError.missingProject
        }
        let bundle = await store.documents.bundle(for: project)
        store.documentBundles[project.id] = bundle
        var docs = bundle.documents
        if let tab = HTTPJSON.string(arguments, "tab"), let parsed = DocumentTab(rawValue: tab) {
            docs = docs.filter { $0.tab == parsed }
        }
        return [
            "source": bundle.source,
            "root": bundle.root ?? NSNull(),
            "documents": docs.map { JSONPayload.document($0) },
        ]
    }

    @MainActor
    private static func readDocument(_ arguments: [String: Any], store: AppStore) async throws -> [String: Any] {
        guard let key = HTTPJSON.string(arguments, "projectKey"), let project = store.project(key: key) else {
            throw ValidationError.missingProject
        }
        let path = try Validation.documentPath(HTTPJSON.string(arguments, "path") ?? "")
        let document = try await store.documents.read(project: project, path: path)
        let markdown = document.markdown ?? ""
        return [
            "path": document.path,
            "tab": document.tab.rawValue,
            "markdown": markdown,
            "headings": MarkdownParser.headings(in: markdown).map { ["level": $0.level, "title": $0.title, "anchor": $0.anchor] },
        ]
    }

    @MainActor
    private static func listIssues(_ arguments: [String: Any], store: AppStore) -> [String: Any] {
        let query = (HTTPJSON.string(arguments, "query") ?? "").lowercased()
        let includeArchived = HTTPJSON.bool(arguments, "includeArchived")
        let limit = min(500, max(1, HTTPJSON.int(arguments, "limit", default: 200)))
        let status = HTTPJSON.string(arguments, "status")
        let projectKey = HTTPJSON.string(arguments, "projectKey")
        var rows = store.issues
        if let projectKey, let project = store.project(key: projectKey) {
            rows = rows.filter { $0.projectId == project.id }
        }
        if let status {
            rows = rows.filter { $0.status.rawValue == status }
        }
        if !includeArchived {
            rows = rows.filter { $0.archivedAt == nil }
        }
        if !query.isEmpty {
            rows = rows.filter {
                ($0.identifier + " " + $0.title + " " + $0.bodyMarkdown).lowercased().contains(query)
            }
        }
        rows.sort { $0.updatedAt > $1.updatedAt }
        return ["issues": rows.prefix(limit).map { store.issueJSON($0) }]
    }

    @MainActor
    private static func getIssue(_ arguments: [String: Any], store: AppStore) throws -> [String: Any] {
        let id = HTTPJSON.string(arguments, "id") ?? HTTPJSON.string(arguments, "identifier") ?? ""
        guard let issue = store.issue(idOrIdentifier: id) else { throw ValidationError.missingIssue }
        var payload = store.issueJSON(issue)
        payload["comments"] = store.comments(for: issue).map { JSONPayload.comment($0, issue: issue) }
        payload["activity"] = store.activities.filter { $0.issueId == issue.id }.reversed().map { store.activityJSON($0) }
        return payload
    }

    @MainActor
    private static func listActivity(_ arguments: [String: Any], store: AppStore) -> [String: Any] {
        let limit = min(500, max(1, HTTPJSON.int(arguments, "limit", default: 50)))
        let projectKey = HTTPJSON.string(arguments, "projectKey")
        let kind = HTTPJSON.string(arguments, "kind")
        let since = try? HTTPJSON.string(arguments, "since").map { try Validation.date($0) }
        var rows = store.activities
        if let projectKey, let project = store.project(key: projectKey) {
            rows = rows.filter { $0.projectId == project.id }
        }
        if let kind {
            rows = rows.filter { $0.kind.rawValue == kind }
        }
        if let since {
            rows = rows.filter { $0.createdAt >= since }
        }
        return ["activities": rows.prefix(limit).map { store.activityJSON($0) }]
    }

    @MainActor
    private static func listMilestones(_ arguments: [String: Any], store: AppStore) -> [String: Any] {
        var rows = store.milestones
        if let key = HTTPJSON.string(arguments, "projectKey") {
            if key.lowercased() == "studio" {
                rows = rows.filter { $0.projectId == nil }
            } else if let project = store.project(key: key) {
                rows = rows.filter { $0.projectId == project.id }
            }
        }
        if let status = HTTPJSON.string(arguments, "status") {
            rows = rows.filter { $0.status.rawValue == status }
        }
        return ["milestones": rows.map { store.milestoneJSON($0) }]
    }

    @MainActor
    private static func listCapabilities(_ arguments: [String: Any], store: AppStore) -> [String: Any] {
        var rows = store.capabilities
        if let key = HTTPJSON.string(arguments, "projectKey"), let project = store.project(key: key) {
            rows = rows.filter { $0.projectId == project.id }
        }
        if let state = HTTPJSON.string(arguments, "state") {
            rows = rows.filter { $0.state.rawValue == state }
        }
        if let health = HTTPJSON.string(arguments, "health") {
            rows = rows.filter { $0.health.rawValue == health }
        }
        return ["capabilities": rows.map { store.capabilityJSON($0) }]
    }

    private static func tool(_ name: String, _ description: String, _ properties: [String: Any], required: [String] = []) -> [String: Any] {
        [
            "name": name,
            "description": description,
            "inputSchema": [
                "type": "object",
                "properties": properties,
                "required": required,
            ] as [String: Any],
        ]
    }
}

enum ServerError: LocalizedError {
    case unknownTool(String)
    case unknownMethod(String)
    case parse

    var errorDescription: String? {
        switch self {
        case .unknownTool(let name): return "Unknown tool '\(name)'."
        case .unknownMethod(let name): return "Method not found: \(name)"
        case .parse: return "Parse error"
        }
    }

    var code: Int {
        switch self {
        case .parse: return -32700
        case .unknownTool, .unknownMethod: return -32601
        }
    }
}

extension AppStore {
    func issueJSON(_ issue: Issue) -> [String: Any] {
        JSONPayload.issue(issue, project: project(id: issue.projectId), labels: labels(for: issue))
    }

    func activityJSON(_ row: Activity) -> [String: Any] {
        JSONPayload.activity(
            row,
            project: row.projectId.flatMap { project(id: $0) },
            issue: row.issueId.flatMap { issue(idOrIdentifier: $0) },
            capability: row.capabilityId.flatMap { capability(idOrIdentifier: $0) }
        )
    }

    func milestoneJSON(_ milestone: Milestone) -> [String: Any] {
        JSONPayload.milestone(milestone, project: milestone.projectId.flatMap { project(id: $0) })
    }

    func capabilityJSON(_ capability: Capability) -> [String: Any] {
        JSONPayload.capability(capability, project: project(id: capability.projectId))
    }
}
