import Foundation

enum MCPRoutes {
    @MainActor
    static func handle(method: String, body: Data?, store: AppStore) async -> HTTPResponse {
        if method == "GET" {
            return .json(200, [
                "protocol": "mcp-jsonrpc-http",
                "name": "Arkboard",
                "version": "2.0.0",
                "tools": ToolCatalogue.names,
                "note": "POST JSON-RPC 2.0 messages (initialize, ping, tools/list, tools/call)",
            ])
        }
        guard method == "POST" else { return .json(404, ["error": "not found"]) }
        guard let body, let object = try? JSONSerialization.jsonObject(with: body) else {
            return .json(200, ["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32700, "message": "Parse error"]])
        }
        guard let message = object as? [String: Any] else {
            return .json(200, ["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32700, "message": "Parse error"]])
        }
        let id = message["id"]
        let rpcMethod = message["method"] as? String ?? ""
        if id == nil {
            return .empty(202)
        }
        do {
            let result = try await dispatch(method: rpcMethod, params: message["params"] as? [String: Any] ?? [:], store: store)
            return .json(200, ["jsonrpc": "2.0", "id": id ?? NSNull(), "result": result])
        } catch {
            let code = (error as? ServerError)?.code ?? -32000
            let messageText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return .json(200, ["jsonrpc": "2.0", "id": id ?? NSNull(), "error": ["code": code, "message": messageText]])
        }
    }

    @MainActor
    private static func dispatch(method: String, params: [String: Any], store: AppStore) async throws -> [String: Any] {
        switch method {
        case "initialize":
            return [
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": [:] as [String: Any]],
                "serverInfo": ["name": "arkboard", "version": "2.0.0"],
            ]
        case "ping":
            return [:]
        case "tools/list":
            return ["tools": ToolCatalogue.list()]
        case "tools/call":
            let name = params["name"] as? String ?? ""
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            let payload = try await ToolCatalogue.call(name, arguments: arguments, store: store)
            let text = String(data: (try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])) ?? Data(), encoding: .utf8) ?? "{}"
            return [
                "content": [["type": "text", "text": text]],
                "structuredContent": payload,
            ]
        default:
            throw ServerError.unknownMethod(method)
        }
    }
}
