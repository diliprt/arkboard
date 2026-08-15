import Foundation

enum RESTRoutes {
    @MainActor
    static func handle(method: String, path: String, query: [String: String], body: [String: Any], store: AppStore) async -> HTTPResponse {
        do {
            switch (method, path) {
            case ("GET", "/api/projects"):
                return .json(200, ["projects": store.projects.map { JSONPayload.project($0, openIssueCount: store.openIssueCount(for: $0)) }])
            case ("POST", "/api/projects"):
                let project = try store.createProject(
                    key: HTTPJSON.string(body, "key") ?? "",
                    name: HTTPJSON.string(body, "name") ?? "",
                    color: HTTPJSON.string(body, "color"),
                    icon: HTTPJSON.string(body, "icon"),
                    summary: HTTPJSON.string(body, "summary"),
                    repoPath: HTTPJSON.string(body, "repoPath"),
                    githubRepo: HTTPJSON.string(body, "githubRepo"),
                    actor: HTTPJSON.string(body, "actor") ?? "Agent"
                )
                return .json(201, JSONPayload.project(project, openIssueCount: 0))
            case ("GET", "/api/issues"):
                return .json(200, try await ToolCatalogue.call("list_issues", arguments: query as [String: Any], store: store))
            case ("POST", "/api/issues"):
                return .json(201, try await ToolCatalogue.call("create_issue", arguments: body, store: store))
            case ("GET", "/api/activity"):
                return .json(200, try await ToolCatalogue.call("list_activity", arguments: query as [String: Any], store: store))
            case ("POST", "/api/notes"):
                return .json(201, try await ToolCatalogue.call("post_note", arguments: body, store: store))
            case ("GET", "/api/milestones"):
                return .json(200, try await ToolCatalogue.call("list_milestones", arguments: query as [String: Any], store: store))
            case ("POST", "/api/milestones"):
                return .json(201, try await ToolCatalogue.call("create_milestone", arguments: body, store: store))
            case ("GET", "/api/capabilities"):
                return .json(200, try await ToolCatalogue.call("list_capabilities", arguments: query as [String: Any], store: store))
            case ("POST", "/api/capabilities"):
                return .json(201, try await ToolCatalogue.call("create_capability", arguments: body, store: store))
            case ("GET", "/api/documents"):
                return .json(200, try await ToolCatalogue.call("list_documents", arguments: query as [String: Any], store: store))
            default:
                return try await resource(method: method, path: path, body: body, store: store)
            }
        } catch {
            return errorResponse(error)
        }
    }

    @MainActor
    private static func resource(method: String, path: String, body: [String: Any], store: AppStore) async throws -> HTTPResponse {
        if path.hasPrefix("/api/documents/") {
            let docPath = String(path.dropFirst("/api/documents/".count))
            var args = body
            args["path"] = docPath.removingPercentEncoding ?? docPath
            if args["projectKey"] == nil { args["projectKey"] = "ARK" }
            return .json(200, try await ToolCatalogue.call("read_document", arguments: args, store: store))
        }
        if path.hasPrefix("/api/issues/") {
            let rest = String(path.dropFirst("/api/issues/".count))
            if rest.hasSuffix("/restore") {
                let id = String(rest.dropLast("/restore".count))
                var args = body
                args["id"] = id
                return .json(200, try await ToolCatalogue.call("restore_issue", arguments: args, store: store))
            }
            if rest.hasSuffix("/comments") {
                let id = String(rest.dropLast("/comments".count))
                var args = body
                args["issueId"] = id
                return .json(201, try await ToolCatalogue.call("add_comment", arguments: args, store: store))
            }
            var args = body
            args["id"] = rest
            switch method {
            case "GET":
                return .json(200, try await ToolCatalogue.call("get_issue", arguments: args, store: store))
            case "PATCH":
                return .json(200, try await ToolCatalogue.call("update_issue", arguments: args, store: store))
            case "DELETE":
                return .json(200, try await ToolCatalogue.call("delete_issue", arguments: args, store: store))
            default:
                return .json(404, ["error": "not found"])
            }
        }
        return .json(404, ["error": "not found"])
    }

    static func errorResponse(_ error: Error) -> HTTPResponse {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let status: Int
        if let validation = error as? ValidationError {
            switch validation {
            case .missingProject, .missingIssue, .missingMilestone, .missingCapability, .missingDocument:
                status = 404
            default:
                status = 400
            }
        } else {
            status = 400
        }
        return .json(status, ["error": message])
    }
}
