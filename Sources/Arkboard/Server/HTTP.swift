import Foundation

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
        if contentLength > 1_000_000 { return nil }
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
                    query[kv[0].removingPercentEncoding ?? kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
                } else if kv.count == 1 {
                    query[kv[0].removingPercentEncoding ?? kv[0]] = ""
                }
            }
        }
        return HTTPRequest(method: String(parts[0]), path: path.removingPercentEncoding ?? path, query: query, headers: headers, body: body)
    }

    var json: [String: Any] {
        guard let body else { return [:] }
        return (try? JSONSerialization.jsonObject(with: body) as? [String: Any]) ?? [:]
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
                "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type",
                "Connection": "close",
            ],
            body: data
        )
    }

    static func empty(_ status: Int) -> HTTPResponse {
        HTTPResponse(
            status: status,
            headers: [
                "Access-Control-Allow-Origin": "*",
                "Connection": "close",
            ],
            body: Data()
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
        for (key, value) in hdrs {
            header += "\(key): \(value)\r\n"
        }
        header += "\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}

enum HTTPJSON {
    static func string(_ object: [String: Any], _ key: String) -> String? {
        if let value = object[key] as? String { return value }
        if let value = object[key] as? NSNumber { return value.stringValue }
        return nil
    }

    static func bool(_ object: [String: Any], _ key: String, default defaultValue: Bool = false) -> Bool {
        if let value = object[key] as? Bool { return value }
        if let value = object[key] as? String { return value == "true" || value == "1" }
        return defaultValue
    }

    static func int(_ object: [String: Any], _ key: String, default defaultValue: Int) -> Int {
        if let value = object[key] as? Int { return value }
        if let value = object[key] as? NSNumber { return value.intValue }
        if let value = object[key] as? String, let parsed = Int(value) { return parsed }
        return defaultValue
    }

    static func strings(_ object: [String: Any], _ key: String) -> [String] {
        object[key] as? [String] ?? []
    }
}
