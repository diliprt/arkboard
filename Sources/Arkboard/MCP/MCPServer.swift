import Foundation
import Network

/// Minimal localhost HTTP server exposing REST `/api/*` and MCP-shaped JSON-RPC at `/mcp`.
final class MCPServer: @unchecked Sendable {
    private let port: NWEndpoint.Port
    private weak var store: AppStore?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "studio.originark.arkboard.mcp")

    init(port: UInt16, store: AppStore) {
        self.port = NWEndpoint.Port(rawValue: port) ?? 7420
        self.store = store
    }

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.requiredInterfaceType = .loopback
        if let ipv4 = IPv4Address("127.0.0.1") {
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(ipv4), port: port)
        }

        let listener = try NWListener(using: params)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                NSLog("Arkboard MCP listening on http://127.0.0.1:\(self.port.rawValue)")
            case .failed(let error):
                NSLog("Arkboard MCP listener failed: \(error)")
            default:
                break
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }

            if let request = HTTPRequest.parse(buf) {
                self.respond(to: request, on: connection)
                return
            }

            if isComplete || error != nil {
                connection.cancel()
                return
            }
            // Keep reading until we can parse headers + body
            if buf.count > 1_000_000 {
                connection.cancel()
                return
            }
            self.receive(on: connection, buffer: buf)
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) {
        Task { @MainActor in
            let response = await self.route(request)
            let data = response.serialize()
            connection.send(content: data, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    @MainActor
    private func route(_ request: HTTPRequest) async -> HTTPResponse {
        let path = request.path
        let method = request.method.uppercased()

        // CORS / health
        if method == "OPTIONS" {
            return .json(200, ["ok": true])
        }
        if path == "/" || path == "/health" {
            return .json(200, [
                "name": "Arkboard",
                "version": "1.0.0",
                "mcp": "/mcp",
                "api": "/api",
            ])
        }

        // REST API
        if path.hasPrefix("/api/") {
            return await handleREST(method: method, path: path, query: request.query, body: request.body)
        }

        // MCP JSON-RPC (streamable-ish HTTP: single POST request/response)
        if path == "/mcp" || path == "/mcp/" {
            if method == "GET" {
                return .json(200, [
                    "protocol": "mcp-jsonrpc-http",
                    "tools": MCPToolCatalog.toolNames,
                    "note": "POST JSON-RPC 2.0 messages (initialize, tools/list, tools/call)",
                ])
            }
            if method == "POST" {
                return await handleMCP(body: request.body)
            }
        }

        return .json(404, ["error": "not found"])
    }

    // MARK: - REST

    @MainActor
    private func handleREST(method: String, path: String, query: [String: String], body: Data?) async -> HTTPResponse {
        guard let store else { return .json(503, ["error": "store unavailable"]) }
        let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]

        do {
            switch (method, path) {
            case ("GET", "/api/projects"):
                return .json(200, ["projects": store.projects.map { store.projectDictionary($0) }])

            case ("POST", "/api/projects"):
                let key = json["key"] as? String ?? ""
                let name = json["name"] as? String ?? key
                let color = json["color"] as? String ?? "#5E6AD2"
                let actor = (json["actor"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let project = try await store.createProject(
                    key: key,
                    name: name,
                    color: color,
                    actor: (actor?.isEmpty == false ? actor! : "Agent")
                )
                return .json(201, store.projectDictionary(project))

            case ("GET", "/api/activity"):
                let limit = Int(query["limit"] ?? "") ?? 50
                let projectKey = query["projectKey"]
                let items = store.listActivity(limit: limit, projectKey: projectKey)
                return .json(200, ["activities": items.map { store.activityDictionary($0) }])

            case ("GET", "/api/issues"):
                var issues = store.activeIssues
                if let projectKey = query["projectKey"] ?? (json["projectKey"] as? String) {
                    if let p = store.projects.first(where: { $0.key.caseInsensitiveCompare(projectKey) == .orderedSame }) {
                        issues = issues.filter { $0.projectId == p.id }
                    }
                }
                if let status = query["status"] ?? (json["status"] as? String),
                   let s = IssueStatus(rawValue: status) {
                    issues = issues.filter { $0.status == s }
                }
                if let q = query["query"], !q.isEmpty {
                    let lq = q.lowercased()
                    issues = issues.filter {
                        ($0.title + " " + $0.identifier + " " + $0.descriptionMarkdown).lowercased().contains(lq)
                    }
                }
                return .json(200, ["issues": issues.map { store.issueDictionary($0) }])

            case ("POST", "/api/issues"):
                let title = json["title"] as? String ?? ""
                let projectKey = json["projectKey"] as? String
                let projectId: String?
                if let projectKey, let p = store.projects.first(where: { $0.key.caseInsensitiveCompare(projectKey) == .orderedSame }) {
                    projectId = p.id
                } else {
                    projectId = json["projectId"] as? String
                }
                let status = try Self.parseStatusForCreate(json)
                let priority = try Self.parsePriorityForCreate(json)
                let description = json["description"] as? String ?? ""
                let labels = json["labels"] as? [String] ?? []
                let actor = (json["actor"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let issue = try await store.createIssue(
                    projectId: projectId,
                    title: title,
                    description: description,
                    status: status,
                    priority: priority,
                    assigneeName: json["assigneeName"] as? String,
                    labelNames: labels,
                    actor: (actor?.isEmpty == false ? actor! : "Agent")
                )
                return .json(201, store.issueDictionary(issue))

            case ("GET", _) where path.hasPrefix("/api/issues/"):
                let key = String(path.dropFirst("/api/issues/".count))
                guard let issue = store.issues.first(where: { $0.id == key || $0.identifier.caseInsensitiveCompare(key) == .orderedSame }) else {
                    return .json(404, ["error": "issue not found"])
                }
                var dict = store.issueDictionary(issue)
                dict["comments"] = store.comments(for: issue).map { c in
                    [
                        "id": c.id,
                        "body": c.bodyMarkdown,
                        "authorName": c.authorName,
                        "createdAt": ISO8601DateFormatter().string(from: c.createdAt),
                    ] as [String: Any]
                }
                return .json(200, dict)

            case ("PATCH", _) where path.hasPrefix("/api/issues/"),
                 ("PUT", _) where path.hasPrefix("/api/issues/"):
                let key = String(path.dropFirst("/api/issues/".count))
                guard let issue = store.issues.first(where: { $0.id == key || $0.identifier.caseInsensitiveCompare(key) == .orderedSame }) else {
                    return .json(404, ["error": "issue not found"])
                }
                let actor = (json["actor"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedActor = (actor?.isEmpty == false ? actor! : "Agent")
                let updated = try await store.updateIssue(
                    id: issue.id,
                    title: json["title"] as? String,
                    description: json["description"] as? String,
                    status: try Self.parseOptionalStatus(json),
                    priority: try Self.parseOptionalPriority(json),
                    assigneeName: json.keys.contains("assigneeName") ? .some(json["assigneeName"] as? String) : nil,
                    actor: resolvedActor
                )
                if let labels = json["labels"] as? [String] {
                    try await store.setIssueLabels(issueId: updated.id, labelNames: labels, actor: resolvedActor)
                }
                return .json(200, store.issueDictionary(store.issues.first(where: { $0.id == updated.id }) ?? updated))

            case ("POST", _) where path.hasSuffix("/comments") && path.hasPrefix("/api/issues/"):
                let mid = path.dropFirst("/api/issues/".count).dropLast("/comments".count)
                let key = String(mid)
                guard let issue = store.issues.first(where: { $0.id == key || $0.identifier.caseInsensitiveCompare(key) == .orderedSame }) else {
                    return .json(404, ["error": "issue not found"])
                }
                let bodyText = json["body"] as? String ?? ""
                let actor = (json["actor"] as? String) ?? (json["authorName"] as? String) ?? "Agent"
                let comment = try await store.addComment(issueId: issue.id, body: bodyText, authorName: actor, actor: actor)
                return .json(201, [
                    "id": comment.id,
                    "body": comment.bodyMarkdown,
                    "authorName": comment.authorName,
                ])


            case ("GET", "/api/milestones"):
                let projectKey = query["projectKey"]
                let status = (query["status"]).flatMap(MilestoneStatus.init(rawValue:))
                let items = store.listMilestones(projectKey: projectKey, status: status)
                return .json(200, ["milestones": items.map { store.milestoneDictionary($0) }])

            case ("POST", "/api/milestones"):
                let title = json["title"] as? String ?? ""
                let description = json["description"] as? String ?? ""
                let actor = (json["actor"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let status = (json["status"] as? String).flatMap(MilestoneStatus.init(rawValue:)) ?? .planned
                let projectKey = json["projectKey"] as? String
                let projectId = json["projectId"] as? String
                let related = json["relatedIssueIdentifiers"] as? [String] ?? []
                let defaultDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                let targetDate = try Self.parseDateOrDefault(json["targetDate"], default: defaultDate)
                let ms = try await store.createMilestone(
                    title: title,
                    description: description,
                    targetDate: targetDate,
                    status: status,
                    projectId: projectId,
                    projectKey: projectKey,
                    relatedIssueIdentifiers: related,
                    actor: (actor?.isEmpty == false ? actor! : "Agent")
                )
                return .json(201, store.milestoneDictionary(ms))

            default:
                return .json(404, ["error": "unknown endpoint", "path": path])
            }
        } catch {
            return .json(400, ["error": error.localizedDescription])
        }
    }

    // MARK: - MCP JSON-RPC

    @MainActor
    private func handleMCP(body: Data?) async -> HTTPResponse {
        guard let body,
              let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let method = obj["method"] as? String else {
            return .json(400, jsonrpcError(id: nil, code: -32700, message: "Parse error"))
        }
        let id = obj["id"]
        let params = obj["params"] as? [String: Any] ?? [:]

        // Notifications (no id) — acknowledge
        if id == nil && method.hasPrefix("notifications/") {
            return HTTPResponse(status: 202, headers: ["Content-Type": "application/json"], body: Data())
        }

        do {
            let result: Any
            switch method {
            case "initialize":
                result = [
                    "protocolVersion": "2024-11-05",
                    "capabilities": ["tools": [:] as [String: Any]],
                    "serverInfo": ["name": "arkboard", "version": "1.0.0"],
                ] as [String: Any]
            case "ping":
                result = [:] as [String: Any]
            case "tools/list":
                result = ["tools": MCPToolCatalog.tools]
            case "tools/call":
                result = try await callTool(params: params)
            default:
                return .json(200, jsonrpcError(id: id, code: -32601, message: "Method not found: \(method)"))
            }
            return .json(200, [
                "jsonrpc": "2.0",
                "id": id as Any,
                "result": result,
            ])
        } catch {
            return .json(200, jsonrpcError(id: id, code: -32000, message: error.localizedDescription))
        }
    }

    @MainActor
    private func callTool(params: [String: Any]) async throws -> [String: Any] {
        guard let store else { throw StoreError.notFound }
        let name = params["name"] as? String ?? ""
        let args = params["arguments"] as? [String: Any] ?? [:]

        func text(_ value: Any) throws -> [String: Any] {
            let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
            let str = String(data: data, encoding: .utf8) ?? "{}"
            return [
                "content": [["type": "text", "text": str]],
                "structuredContent": value,
            ]
        }

        switch name {
        case "list_projects":
            return try text(["projects": store.projects.map { store.projectDictionary($0) }])

        case "create_project":
            let actor = Self.resolvedActor(args)
            let project = try await store.createProject(
                key: args["key"] as? String ?? "",
                name: args["name"] as? String ?? (args["key"] as? String ?? "Project"),
                color: args["color"] as? String ?? "#5E6AD2",
                actor: actor
            )
            return try text(store.projectDictionary(project))

        case "list_issues", "search_issues":
            var issues = store.activeIssues
            if let key = args["projectKey"] as? String,
               let p = store.projects.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame }) {
                issues = issues.filter { $0.projectId == p.id }
            }
            if let pid = args["projectId"] as? String {
                issues = issues.filter { $0.projectId == pid }
            }
            if let status = args["status"] as? String, let s = IssueStatus(rawValue: status) {
                issues = issues.filter { $0.status == s }
            }
            if let priority = args["priority"] as? String, let p = IssuePriority(rawValue: priority) {
                issues = issues.filter { $0.priority == p }
            }
            if let q = args["query"] as? String, !q.isEmpty {
                let lq = q.lowercased()
                issues = issues.filter {
                    ($0.title + " " + $0.identifier + " " + $0.descriptionMarkdown).lowercased().contains(lq)
                }
            }
            return try text(["issues": issues.map { store.issueDictionary($0) }])

        case "get_issue":
            let key = (args["id"] as? String) ?? (args["identifier"] as? String) ?? ""
            guard let issue = store.issues.first(where: {
                $0.id == key || $0.identifier.caseInsensitiveCompare(key) == .orderedSame
            }) else { throw StoreError.notFound }
            var dict = store.issueDictionary(issue)
            dict["comments"] = store.comments(for: issue).map {
                ["id": $0.id, "body": $0.bodyMarkdown, "authorName": $0.authorName] as [String: Any]
            }
            return try text(dict)

        case "create_issue":
            let projectKey = args["projectKey"] as? String
            let projectId: String?
            if let projectKey, let p = store.projects.first(where: { $0.key.caseInsensitiveCompare(projectKey) == .orderedSame }) {
                projectId = p.id
            } else {
                projectId = args["projectId"] as? String
            }
            let actor = Self.resolvedActor(args)
            let issue = try await store.createIssue(
                projectId: projectId,
                title: args["title"] as? String ?? "",
                description: args["description"] as? String ?? "",
                status: try Self.parseStatusForCreate(args),
                priority: try Self.parsePriorityForCreate(args),
                assigneeName: args["assigneeName"] as? String,
                labelNames: args["labels"] as? [String] ?? [],
                actor: actor
            )
            return try text(store.issueDictionary(issue))

        case "update_issue":
            let key = (args["id"] as? String) ?? (args["identifier"] as? String) ?? ""
            guard let issue = store.issues.first(where: {
                $0.id == key || $0.identifier.caseInsensitiveCompare(key) == .orderedSame
            }) else { throw StoreError.notFound }
            let actor = Self.resolvedActor(args)
            let updated = try await store.updateIssue(
                id: issue.id,
                title: args["title"] as? String,
                description: args["description"] as? String,
                status: try Self.parseOptionalStatus(args),
                priority: try Self.parseOptionalPriority(args),
                assigneeName: args.keys.contains("assigneeName") ? .some(args["assigneeName"] as? String) : nil,
                actor: actor
            )
            if let labels = args["labels"] as? [String] {
                try await store.setIssueLabels(issueId: updated.id, labelNames: labels, actor: actor)
            }
            let fresh = store.issues.first(where: { $0.id == updated.id }) ?? updated
            return try text(store.issueDictionary(fresh))

        case "add_comment":
            let key = (args["issueId"] as? String) ?? (args["identifier"] as? String) ?? ""
            guard let issue = store.issues.first(where: {
                $0.id == key || $0.identifier.caseInsensitiveCompare(key) == .orderedSame
            }) else { throw StoreError.notFound }
            let actor = Self.resolvedActor(args, fallbackAuthor: args["authorName"] as? String)
            let comment = try await store.addComment(
                issueId: issue.id,
                body: args["body"] as? String ?? "",
                authorName: actor,
                actor: actor
            )
            return try text([
                "id": comment.id,
                "issueId": comment.issueId,
                "body": comment.bodyMarkdown,
                "authorName": comment.authorName,
            ])

        case "list_activity":
            let limit = args["limit"] as? Int ?? (args["limit"] as? NSNumber)?.intValue ?? 50
            let projectKey = args["projectKey"] as? String
            let items = store.listActivity(limit: limit, projectKey: projectKey)
            return try text(["activities": items.map { store.activityDictionary($0) }])


        case "list_milestones":
            let projectKey = args["projectKey"] as? String
            let status = (args["status"] as? String).flatMap(MilestoneStatus.init(rawValue:))
            let items = store.listMilestones(projectKey: projectKey, status: status)
            return try text(["milestones": items.map { store.milestoneDictionary($0) }])

        case "create_milestone":
            let actor = Self.resolvedActor(args)
            let status = (args["status"] as? String).flatMap(MilestoneStatus.init(rawValue:)) ?? .planned
            let related = args["relatedIssueIdentifiers"] as? [String] ?? []
            let defaultDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            let targetDate = try Self.parseDateOrDefault(args["targetDate"], default: defaultDate)
            let ms = try await store.createMilestone(
                title: args["title"] as? String ?? "",
                description: args["description"] as? String ?? "",
                targetDate: targetDate,
                status: status,
                projectId: args["projectId"] as? String,
                projectKey: args["projectKey"] as? String,
                relatedIssueIdentifiers: related,
                actor: actor
            )
            return try text(store.milestoneDictionary(ms))

        case "update_milestone":
            let id = args["id"] as? String ?? ""
            guard !id.isEmpty else { throw StoreError.notFound }
            let actor = Self.resolvedActor(args)
            var projectIdUpdate: String?? = nil
            if args.keys.contains("projectId") {
                projectIdUpdate = .some(args["projectId"] as? String)
            } else if let key = args["projectKey"] as? String {
                if key.lowercased() == "studio" || key.lowercased() == "studio-wide" {
                    projectIdUpdate = .some(nil)
                } else if let p = store.projects.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame }) {
                    projectIdUpdate = .some(p.id)
                }
            }
            let ms = try await store.updateMilestone(
                id: id,
                title: args["title"] as? String,
                description: args["description"] as? String,
                targetDate: try Self.parseDate(args["targetDate"]),
                status: (args["status"] as? String).flatMap(MilestoneStatus.init(rawValue:)),
                projectId: projectIdUpdate,
                relatedIssueIdentifiers: args["relatedIssueIdentifiers"] as? [String],
                actor: actor
            )
            return try text(store.milestoneDictionary(ms))

        case "list_bot_thread":
            let key = (args["issueId"] as? String) ?? (args["identifier"] as? String) ?? ""
            guard let thread = store.botThread(issueIdOrIdentifier: key) else { throw StoreError.notFound }
            return try text([
                "issue": store.issueDictionary(thread.issue),
                "comments": thread.comments.map {
                    [
                        "id": $0.id,
                        "body": $0.bodyMarkdown,
                        "authorName": $0.authorName,
                        "createdAt": ISO8601DateFormatter().string(from: $0.createdAt),
                    ] as [String: Any]
                },
                "activities": thread.activities.map { store.activityDictionary($0) },
            ])

        default:
            throw NSError(domain: "MCP", code: -32601, userInfo: [NSLocalizedDescriptionKey: "Unknown tool: \(name)"])
        }
    }


    /// MCP default actor is "Agent" when omitted; `actor` wins over legacy authorName.
    private static func resolvedActor(_ args: [String: Any], fallbackAuthor: String? = nil) -> String {
        if let actor = args["actor"] as? String {
            let t = actor.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        if let author = fallbackAuthor {
            let t = author.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return "Agent"
    }


    /// Parse status when the key is present. Unknown values throw; omitted → nil.
    private static func parseOptionalStatus(_ args: [String: Any], key: String = "status") throws -> IssueStatus? {
        guard args.keys.contains(key) else { return nil }
        guard let raw = args[key] as? String else {
            throw StoreError.invalidStatus(String(describing: args[key] ?? "null"))
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let status = IssueStatus(rawValue: trimmed) else {
            throw StoreError.invalidStatus(trimmed)
        }
        return status
    }

    /// Create path: omitted → default; present but unknown → error.
    private static func parseStatusForCreate(_ args: [String: Any], default defaultStatus: IssueStatus = .backlog) throws -> IssueStatus {
        try parseOptionalStatus(args) ?? defaultStatus
    }

    private static func parseOptionalPriority(_ args: [String: Any], key: String = "priority") throws -> IssuePriority? {
        guard args.keys.contains(key) else { return nil }
        guard let raw = args[key] as? String else {
            throw StoreError.invalidPriority(String(describing: args[key] ?? "null"))
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let priority = IssuePriority(rawValue: trimmed) else {
            throw StoreError.invalidPriority(trimmed)
        }
        return priority
    }

    private static func parsePriorityForCreate(_ args: [String: Any], default defaultPriority: IssuePriority = .none) throws -> IssuePriority {
        try parseOptionalPriority(args) ?? defaultPriority
    }

    /// ISO8601 kept as-is. Date-only `yyyy-MM-dd` stored as noon UTC.
    /// Unparseable non-empty strings throw. Nil/empty → nil (caller may default).
    private static func parseDate(_ value: Any?) throws -> Date? {
        guard let value else { return nil }
        if value is NSNull { return nil }
        guard let s = value as? String else {
            throw StoreError.invalidDate(String(describing: value))
        }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: trimmed) { return d }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: trimmed) { return d }

        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        if let day = f.date(from: trimmed) {
            // Noon UTC for date-only values (stable across agents/timezones).
            return day.addingTimeInterval(12 * 60 * 60)
        }
        throw StoreError.invalidDate(trimmed)
    }

    private static func parseDateOrDefault(_ value: Any?, default defaultDate: Date) throws -> Date {
        try parseDate(value) ?? defaultDate
    }

    private func jsonrpcError(id: Any?, code: Int, message: String) -> [String: Any] {
        var resp: [String: Any] = [
            "jsonrpc": "2.0",
            "error": ["code": code, "message": message],
        ]
        resp["id"] = id ?? NSNull()
        return resp
    }
}

enum MCPToolCatalog {
    static let toolNames = [
        "list_projects", "create_project", "list_issues", "get_issue",
        "create_issue", "update_issue", "add_comment", "search_issues", "list_activity",
        "list_milestones", "create_milestone", "update_milestone", "list_bot_thread",
    ]

    static var tools: [[String: Any]] {
        [
            tool("list_projects", "List all projects", [:]),
            tool("create_project", "Create a project", [
                "key": ["type": "string", "description": "Short key e.g. ARK"],
                "name": ["type": "string", "description": "Display name"],
                "color": ["type": "string", "description": "Hex color"],
                "actor": ["type": "string", "description": "Agent name for activity feed (default Agent)"],
            ], required: ["key", "name"]),
            tool("list_issues", "List issues with optional filters", [
                "projectKey": ["type": "string"],
                "projectId": ["type": "string"],
                "status": ["type": "string", "description": "backlog|todo|in_progress|done|canceled"],
                "priority": ["type": "string"],
                "query": ["type": "string"],
            ]),
            tool("search_issues", "Search issues by text", [
                "query": ["type": "string"],
                "projectKey": ["type": "string"],
            ], required: ["query"]),
            tool("get_issue", "Get one issue by id or identifier", [
                "id": ["type": "string"],
                "identifier": ["type": "string"],
            ]),
            tool("create_issue", "Create an issue", [
                "title": ["type": "string"],
                "projectKey": ["type": "string"],
                "projectId": ["type": "string"],
                "description": ["type": "string"],
                "status": ["type": "string"],
                "priority": ["type": "string"],
                "labels": ["type": "array", "items": ["type": "string"], "description": "Deduped case-insensitively; feature+bug together is allowed"],
                "assigneeName": ["type": "string"],
                "actor": ["type": "string", "description": "Agent name for activity feed (default Agent)"],
            ], required: ["title"]),
            tool("update_issue", "Update an issue (unknown status/priority rejected; labels replace + dedupe)", [
                "id": ["type": "string"],
                "identifier": ["type": "string"],
                "title": ["type": "string"],
                "description": ["type": "string"],
                "status": ["type": "string", "description": "backlog|todo|in_progress|done|canceled"],
                "priority": ["type": "string", "description": "none|low|medium|high|urgent"],
                "labels": ["type": "array", "items": ["type": "string"], "description": "Full replace; duplicates trimmed case-insensitively"],
                "assigneeName": ["type": "string"],
                "actor": ["type": "string", "description": "Agent name for activity feed (default Agent)"],
            ]),
            tool("add_comment", "Add a comment to an issue", [
                "issueId": ["type": "string"],
                "identifier": ["type": "string"],
                "body": ["type": "string"],
                "authorName": ["type": "string", "description": "Legacy; prefer actor"],
                "actor": ["type": "string", "description": "Sets authorName + activity actor (default Agent)"],
            ], required: ["body"]),
            tool("list_activity", "List recent agent/UI activity (reverse chronological)", [
                "limit": ["type": "integer", "description": "Max items (default 50)"],
                "projectKey": ["type": "string", "description": "Optional project filter e.g. ARK"],
            ]),
            tool("list_milestones", "List milestones (studio-wide and per-project)", [
                "projectKey": ["type": "string", "description": "ARK / OPS / studio"],
                "status": ["type": "string", "description": "planned|in_progress|done|missed"],
            ]),
            tool("create_milestone", "Create a milestone", [
                "title": ["type": "string"],
                "description": ["type": "string"],
                "targetDate": ["type": "string", "description": "ISO8601 or yyyy-MM-dd (date-only stored as noon UTC; unparseable rejected)"],
                "status": ["type": "string", "description": "planned|in_progress|done|missed"],
                "projectKey": ["type": "string", "description": "Omit or studio for studio-wide"],
                "projectId": ["type": "string"],
                "relatedIssueIdentifiers": ["type": "array", "items": ["type": "string"]],
                "actor": ["type": "string", "description": "Agent name for activity feed (default Agent)"],
            ], required: ["title"]),
            tool("update_milestone", "Update a milestone", [
                "id": ["type": "string"],
                "title": ["type": "string"],
                "description": ["type": "string"],
                "targetDate": ["type": "string", "description": "ISO8601 or yyyy-MM-dd (date-only noon UTC; unparseable rejected)"],
                "status": ["type": "string"],
                "projectKey": ["type": "string"],
                "projectId": ["type": "string"],
                "relatedIssueIdentifiers": ["type": "array", "items": ["type": "string"]],
                "actor": ["type": "string"],
            ], required: ["id"]),
            tool("list_bot_thread", "Comments + activity for one issue in chronological order", [
                "issueId": ["type": "string"],
                "identifier": ["type": "string", "description": "e.g. ARK-1"],
            ]),
        ]
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

// MARK: - Tiny HTTP helpers

struct HTTPRequest {
    var method: String
    var path: String
    var query: [String: String]
    var headers: [String: String]
    var body: Data?

    static func parse(_ data: Data) -> HTTPRequest? {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = data.subdata(in: data.startIndex..<headerRange.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let idx = line.firstIndex(of: ":") {
                let key = String(line[..<idx]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        let bodyStart = headerRange.upperBound
        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let available = data.endIndex - bodyStart
        if contentLength > available { return nil }
        let body: Data? = contentLength > 0 ? data.subdata(in: bodyStart..<(bodyStart + contentLength)) : nil
        let target = String(parts[1])
        var path = target
        var query: [String: String] = [:]
        if let q = target.firstIndex(of: "?") {
            path = String(target[..<q])
            let qs = String(target[target.index(after: q)...])
            for pair in qs.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                if kv.count == 2 {
                    query[kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
                } else if kv.count == 1 {
                    query[kv[0]] = ""
                }
            }
        }
        return HTTPRequest(method: String(parts[0]), path: path, query: query, headers: headers, body: body)
    }
}

struct HTTPResponse {
    var status: Int
    var headers: [String: String]
    var body: Data

    static func json(_ status: Int, _ object: [String: Any]) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
        return HTTPResponse(
            status: status,
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type",
                "Connection": "close",
            ],
            body: data
        )
    }

    func serialize() -> Data {
        let reason: String
        switch status {
        case 200: reason = "OK"
        case 201: reason = "Created"
        case 202: reason = "Accepted"
        case 400: reason = "Bad Request"
        case 404: reason = "Not Found"
        case 503: reason = "Service Unavailable"
        default: reason = "OK"
        }
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        var hdrs = headers
        hdrs["Content-Length"] = "\(body.count)"
        for (k, v) in hdrs {
            header += "\(k): \(v)\r\n"
        }
        header += "\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}
