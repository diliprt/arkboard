import Foundation

/// Pure helpers for GitHub issue URL / repo normalization (no network).
enum GitHubIssueLink {
    /// Normalize `owner/name`, stripping `.git`, URLs, and whitespace. Returns nil if invalid.
    static func normalizeRepo(_ raw: String?) -> String? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return nil
        }
        if let url = URL(string: s), let host = url.host?.lowercased(),
           (host == "github.com" || host == "www.github.com") {
            let parts = url.path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
            if parts.count >= 2 {
                s = "\(parts[0])/\(parts[1])"
            }
        }
        if s.lowercased().hasPrefix("github.com/") {
            s = String(s.dropFirst("github.com/".count))
        }
        if s.hasSuffix(".git") {
            s = String(s.dropLast(4))
        }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = s.split(separator: "/").map(String.init)
        guard parts.count == 2 else { return nil }
        let owner = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        var name = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasSuffix(".git") { name = String(name.dropLast(4)) }
        guard !owner.isEmpty, !name.isEmpty else { return nil }
        guard owner.range(of: #"^[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil else { return nil }
        guard name.range(of: #"^[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil else { return nil }
        return "\(owner)/\(name)"
    }

    /// Parse a GitHub issue URL into `(repo, number)`.
    /// Accepts https://github.com/owner/name/issues/123 (optional trailing slash / query / fragment).
    static func parseIssueURL(_ raw: String?) -> (repo: String?, number: Int?) {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return (nil, nil)
        }
        if let url = URL(string: raw), let host = url.host?.lowercased(),
           host == "github.com" || host == "www.github.com" {
            let parts = url.path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
            guard parts.count >= 4, parts[2].lowercased() == "issues",
                  let number = Int(parts[3]), number > 0 else {
                let repoHint = parts.count >= 2 ? normalizeRepo("\(parts[0])/\(parts[1])") : nil
                return (repoHint, nil)
            }
            let repo = normalizeRepo("\(parts[0])/\(parts[1])")
            return (repo, number)
        }
        // Bare paths like github.com/owner/name/issues/1
        if raw.lowercased().contains("github.com/") {
            let prefixed = raw.lowercased().hasPrefix("http") ? raw : "https://\(raw)"
            return parseIssueURL(prefixed)
        }
        return (nil, nil)
    }

    static func buildIssueURL(repo: String, number: Int) -> String {
        "https://github.com/\(repo)/issues/\(number)"
    }
}
