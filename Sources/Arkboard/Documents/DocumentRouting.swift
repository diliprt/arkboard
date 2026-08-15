import Foundation

enum DocumentRouting {
    static func tab(for path: String) -> DocumentTab {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        let lower = normalized.lowercased()
        let filename = (normalized as NSString).lastPathComponent
        let fileStem = stem(filename)
        let trimmed = lower.hasPrefix("./") ? String(lower.dropFirst(2)) : lower

        if trimmed == "product/readme.md" || trimmed == "product/overview.md" {
            return .overview
        }

        let folder = folderName(in: lower)
        switch folder {
        case "design": return .design
        case "architecture": return .architecture
        case "mockups": return .mockups
        case "decisions", "questions": return .decisions
        default: break
        }

        switch fileStem {
        case "design": return .design
        case "architecture": return .architecture
        case "mockups": return .mockups
        case "decisions", "questions": return .decisions
        default: break
        }

        let keywords: [(DocumentTab, [String])] = [
            (.design, ["design", "ui", "ux", "visual", "brand", "spec"]),
            (.architecture, ["arch", "api", "mcp", "data", "schema", "engine", "infra"]),
            (.decisions, ["decision", "question", "rfc", "adr"]),
            (.mockups, ["mockup", "frame", "wireframe", "screen", "flow"]),
        ]
        for (tab, words) in keywords {
            if words.contains(where: { fileStem.contains($0) }) {
                return tab
            }
        }

        // Brand artwork at the root of product/ is the project's own face, not a
        // frame someone drew. It feeds the Portfolio card and the sidebar mark;
        // it never appears in the Mockups gallery. Inside product/mockups/ the
        // folder wins, and the switch above has already returned.
        if ProjectMark.isBrandAsset(path: filename) {
            return .more
        }

        if isImage(filename) {
            return .mockups
        }
        return .more
    }

    static func stem(_ path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return ((name as NSString).deletingPathExtension).lowercased()
    }

    static func title(for path: String) -> String {
        let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        if name.uppercased() == "README" { return "Overview" }
        return name.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
    }

    static func isImage(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "webp"].contains(ext)
    }

    static func isText(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return ext == "md" || ext == "txt" || isFlowJSON(path)
    }

    static func isFlowDocument(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent.lowercased()
        return name == "flow.json" || name == "flow.md" || name == "flow.txt"
    }

    static func isFlowJSON(_ path: String) -> Bool {
        (path as NSString).lastPathComponent.lowercased() == "flow.json"
    }

    static func shouldIgnore(_ path: String) -> Bool {
        let lower = path.lowercased().replacingOccurrences(of: "\\", with: "/")
        return lower.contains("/baseline/") || lower.contains("/blueprint/") || lower.hasPrefix("product/baseline/") || lower.hasPrefix("product/blueprint/")
    }

    private static func folderName(in lowerPath: String) -> String? {
        let parts = lowerPath.split(separator: "/").map(String.init)
        guard let product = parts.firstIndex(of: "product"), product + 1 < parts.count else { return nil }
        let next = parts[product + 1]
        if next.contains(".") { return nil }
        return next
    }
}
