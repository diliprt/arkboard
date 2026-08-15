import Foundation

struct MockupFlow: Equatable {
    var nodes: [Node]
    var inferred: Bool

    struct Node: Identifiable, Equatable {
        var id: String
        var title: String
    }
}

enum MockupFlowParser {
    static func parse(flowJSON: String?, flowMarkdown: String?, imageNames: [String]) -> MockupFlow {
        if let flowJSON, let nodes = parseJSON(flowJSON), !nodes.isEmpty {
            return MockupFlow(nodes: nodes, inferred: false)
        }
        if let flowMarkdown, let nodes = parseMarkdown(flowMarkdown), !nodes.isEmpty {
            return MockupFlow(nodes: nodes, inferred: false)
        }
        return MockupFlow(nodes: infer(imageNames), inferred: true)
    }

    static func parseJSON(_ text: String) -> [MockupFlow.Node]? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = object["nodes"] as? [Any] else { return nil }
        var nodes: [MockupFlow.Node] = []
        var seen = Set<String>()
        for item in raw {
            let id: String
            let title: String
            if let string = item as? String {
                id = string
                title = string
            } else if let dict = item as? [String: Any] {
                id = (dict["id"] as? String) ?? (dict["title"] as? String) ?? ""
                title = (dict["title"] as? String) ?? id
            } else {
                continue
            }
            guard !id.isEmpty, !seen.contains(id) else { continue }
            seen.insert(id)
            nodes.append(MockupFlow.Node(id: id, title: title))
        }
        return nodes
    }

    static func parseMarkdown(_ text: String) -> [MockupFlow.Node]? {
        var nodes: [MockupFlow.Node] = []
        var seen = Set<String>()
        for raw in text.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("-") || line.hasPrefix("*") {
                line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            guard line.contains("→") || line.contains("->") else { continue }
            let parts = line.components(separatedBy: "→").flatMap { $0.components(separatedBy: "->") }
            for part in parts {
                let name = part.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "`"))
                guard !name.isEmpty, !name.hasPrefix("#"), !seen.contains(name) else { continue }
                seen.insert(name)
                nodes.append(MockupFlow.Node(id: name, title: name))
            }
        }
        return nodes
    }

    static func infer(_ imageNames: [String]) -> [MockupFlow.Node] {
        imageNames.sorted().map { name in
            let stem = ((name as NSString).lastPathComponent as NSString).deletingPathExtension
            let title = stem.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
            return MockupFlow.Node(id: stem, title: title)
        }
    }
}
