import Foundation
import Network

final class StudioServer: @unchecked Sendable {
    static let port: UInt16 = 7420

    private weak var store: AppStore?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "studio.originark.arkboard.server")

    init(store: AppStore) {
        self.store = store
    }

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = false
        params.requiredInterfaceType = .loopback
        if let ipv4 = IPv4Address("127.0.0.1") {
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(ipv4), port: NWEndpoint.Port(rawValue: Self.port) ?? 7420)
        }
        let listener = try NWListener(using: params)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
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
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            if buf.count > 1_000_000 {
                connection.cancel()
                return
            }
            if let request = HTTPRequest.parse(buf) {
                self.respond(to: request, on: connection)
                return
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receive(on: connection, buffer: buf)
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) {
        Task { @MainActor in
            let response = await self.route(request)
            connection.send(content: response.serialize(), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    @MainActor
    private func route(_ request: HTTPRequest) async -> HTTPResponse {
        let method = request.method.uppercased()
        let path = request.path
        if method == "OPTIONS" {
            return .json(200, ["ok": true])
        }
        if path == "/" || path == "/health" {
            return .json(200, [
                "name": "Arkboard",
                "version": "2.0.0",
                "mcp": "/mcp",
                "api": "/api",
                "database": "ok",
                "projects": store?.projects.count ?? 0,
            ])
        }
        guard let store else { return .json(503, ["error": "store is not ready"]) }
        if path == "/mcp" || path == "/mcp/" {
            return await MCPRoutes.handle(method: method, body: request.body, store: store)
        }
        if path.hasPrefix("/api/") {
            return await RESTRoutes.handle(method: method, path: path, query: request.query, body: request.json, store: store)
        }
        return .json(404, ["error": "not found"])
    }
}
