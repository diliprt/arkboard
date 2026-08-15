import Foundation
import AppKit
import Observation

struct ProductQuestion: Identifiable, Hashable {
    var id: String
    var title: String
    var excerpt: String
    var path: String
    var projectId: String
}

struct ProductFile: Identifiable, Hashable {
    var id: String { path }
    var path: String
    var markdown: String?
    var imageData: Data?
    var source: String

    var name: String { (path as NSString).lastPathComponent }
    var isMarkdown: Bool { path.lowercased().hasSuffix(".md") || path.lowercased().hasSuffix(".txt") }
    var isImage: Bool {
        let lower = path.lowercased()
        return lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")
            || lower.hasSuffix(".gif") || lower.hasSuffix(".webp")
    }

    var nsImage: NSImage? {
        guard let imageData else { return nil }
        return NSImage(data: imageData)
    }
}

struct ProductTree: Hashable {
    var files: [ProductFile]
    var sourceLabel: String
    var loadedAt: Date

    var isEmpty: Bool { files.isEmpty }

    func file(path: String) -> ProductFile? {
        files.first { $0.path == path || $0.path.hasSuffix("/\(path)") || $0.name == path }
    }

    func markdown(named names: [String]) -> String? {
        for name in names {
            if let file = files.first(where: { $0.name.lowercased() == name.lowercased() }),
               let md = file.markdown, !md.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return md
            }
        }
        return nil
    }

    func files(matching prefixes: [String], names: [String] = [], imagesOnly: Bool = false) -> [ProductFile] {
        files.filter { file in
            if isIgnored(file.path) { return false }
            if imagesOnly && !file.isImage { return false }
            let lower = file.path.lowercased()
            if names.contains(where: { file.name.lowercased() == $0.lowercased() }) { return true }
            return prefixes.contains { lower.hasPrefix($0.lowercased()) }
        }
        .sorted { $0.path < $1.path }
    }

    func overviewMarkdown() -> String? {
        markdown(named: ["README.md", "overview.md", "OVERVIEW.md"])
    }

    func overviewBlurb() -> String {
        guard let md = overviewMarkdown() else { return "" }
        return MarkdownDocument.firstParagraph(in: md)
    }

    func questions(projectId: String) -> [ProductQuestion] {
        var result: [ProductQuestion] = []
        let candidates = files.filter { file in
            let lower = file.path.lowercased()
            return lower.contains("decision") || lower.contains("question")
        }
        for file in candidates {
            guard let md = file.markdown else { continue }
            let blocks = MarkdownDocument.parse(md)
            var lastHeading: String?
            for block in blocks {
                switch block.kind {
                case .heading(_, let title):
                    lastHeading = title
                    let lower = title.lowercased()
                    if title.contains("?") || lower.contains("open") {
                        result.append(ProductQuestion(
                            id: "\(projectId)-\(file.path)-\(block.id)",
                            title: title,
                            excerpt: "",
                            path: file.path,
                            projectId: projectId
                        ))
                    }
                case .paragraph(let text), .quote(let text):
                    if let heading = lastHeading, heading.lowercased().contains("open") || heading.contains("?") {
                        if let idx = result.lastIndex(where: { $0.path == file.path && $0.title == heading && $0.excerpt.isEmpty }) {
                            var copy = result[idx]
                            copy.excerpt = String(text.prefix(180))
                            result[idx] = copy
                        }
                    }
                default:
                    break
                }
            }
        }
        return result
    }

    func resolveImage(_ ref: String) -> NSImage? {
        let cleaned = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = files.first(where: { $0.path == cleaned || $0.name == cleaned }) {
            return exact.nsImage
        }
        let suffix = cleaned.hasPrefix("product/") ? cleaned : "product/\(cleaned)"
        if let file = files.first(where: { $0.path == suffix || $0.path.hasSuffix("/\(cleaned)") }) {
            return file.nsImage
        }
        return nil
    }

    private func isIgnored(_ path: String) -> Bool {
        let lower = path.lowercased()
        return lower.hasPrefix("product/baseline/") || lower.hasPrefix("product/blueprint/")
    }
}

@MainActor
@Observable
final class ProductLibrary {
    private var trees: [String: ProductTree] = [:]
    private var errors: [String: String] = [:]
    private var inflight: Set<String> = []

    func tree(for project: Project) -> ProductTree? {
        trees[cacheKey(for: project)]
    }

    func error(for project: Project) -> String? {
        errors[cacheKey(for: project)]
    }

    func isLoading(_ project: Project) -> Bool {
        inflight.contains(cacheKey(for: project))
    }

    func prefetch(projects: [Project]) async {
        for project in projects {
            _ = await load(for: project)
        }
    }

    @discardableResult
    func load(for project: Project) async -> ProductTree {
        let key = cacheKey(for: project)
        if let cached = trees[key] { return cached }
        inflight.insert(key)
        defer { inflight.remove(key) }

        var files: [ProductFile] = []
        var sources: [String] = []

        if let local = Self.loadLocalProduct(for: project) {
            files.append(contentsOf: local.files)
            sources.append(local.label)
        }

        if let repo = Self.repoHint(for: project) {
            do {
                let remote = try await Self.fetchGitHubProduct(repo: repo)
                for file in remote {
                    if let idx = files.firstIndex(where: { $0.path == file.path }) {
                        // Local wins for arkboard while iterating; keep local.
                        if files[idx].source == "local" { continue }
                        files[idx] = file
                    } else {
                        files.append(file)
                    }
                }
                sources.append("github:\(repo)")
            } catch {
                errors[key] = error.localizedDescription
            }
        }

        let tree = ProductTree(files: files, sourceLabel: sources.joined(separator: " + "), loadedAt: Date())
        trees[key] = tree
        return tree
    }

    func reload(for project: Project) async -> ProductTree {
        trees.removeValue(forKey: cacheKey(for: project))
        return await load(for: project)
    }

    func questions(across projects: [Project]) -> [ProductQuestion] {
        var result: [ProductQuestion] = []
        for project in projects {
            if let tree = trees[cacheKey(for: project)] {
                result.append(contentsOf: tree.questions(projectId: project.id))
            }
        }
        return result
    }

    private func cacheKey(for project: Project) -> String {
        Self.repoHint(for: project) ?? project.id
    }

    static func repoHint(for project: Project) -> String? {
        if let repo = GitHubIssueLink.normalizeRepo(project.githubRepo) {
            return repo
        }
        if project.key.caseInsensitiveCompare("ARK") == .orderedSame
            || project.name.localizedCaseInsensitiveContains("arkboard") {
            return "diliprt/arkboard"
        }
        return nil
    }

    // MARK: - Local

    private static func loadLocalProduct(for project: Project) -> (files: [ProductFile], label: String)? {
        guard isArkboard(project), let root = findLocalProductRoot() else { return nil }
        var files: [ProductFile] = []
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        for case let url as URL in enumerator {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { continue }
            let rel = "product/" + url.path.replacingOccurrences(of: root.path + "/", with: "")
            if shouldSkip(rel) { continue }
            files.append(readLocalFile(url: url, path: rel))
        }
        return files.isEmpty ? nil : (files, "local")
    }

    private static func isArkboard(_ project: Project) -> Bool {
        project.key.caseInsensitiveCompare("ARK") == .orderedSame
            || project.name.localizedCaseInsensitiveContains("arkboard")
    }

    static func findLocalProductRoot() -> URL? {
        var url = Bundle.main.bundleURL
        for _ in 0..<10 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent("product", isDirectory: true)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        let known = URL(fileURLWithPath: "/Users/dilipreddy/Origin Ark Studio/arkboard/product")
        if FileManager.default.fileExists(atPath: known.path) {
            return known
        }
        return nil
    }

    private static func readLocalFile(url: URL, path: String) -> ProductFile {
        let data = (try? Data(contentsOf: url)) ?? Data()
        let lower = path.lowercased()
        if lower.hasSuffix(".md") || lower.hasSuffix(".txt") {
            return ProductFile(path: path, markdown: String(data: data, encoding: .utf8), imageData: nil, source: "local")
        }
        if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")
            || lower.hasSuffix(".gif") || lower.hasSuffix(".webp") {
            return ProductFile(path: path, markdown: nil, imageData: data, source: "local")
        }
        return ProductFile(path: path, markdown: String(data: data, encoding: .utf8), imageData: nil, source: "local")
    }

    // MARK: - GitHub

    private static func fetchGitHubProduct(repo: String) async throws -> [ProductFile] {
        let treeData = try await runGhData([
            "api", "repos/\(repo)/git/trees/HEAD?recursive=1"
        ])
        guard let obj = try JSONSerialization.jsonObject(with: treeData) as? [String: Any],
              let tree = obj["tree"] as? [[String: Any]] else {
            return []
        }
        let paths = tree.compactMap { item -> String? in
            guard (item["type"] as? String) == "blob",
                  let path = item["path"] as? String,
                  path.hasPrefix("product/"),
                  !shouldSkip(path) else { return nil }
            return path
        }
        var files: [ProductFile] = []
        for path in paths {
            do {
                let raw = try await runGhData([
                    "api", "repos/\(repo)/contents/\(path)",
                    "-H", "Accept: application/vnd.github.raw"
                ])
                let lower = path.lowercased()
                if lower.hasSuffix(".md") || lower.hasSuffix(".txt") {
                    files.append(ProductFile(path: path, markdown: String(data: raw, encoding: .utf8), imageData: nil, source: "github"))
                } else if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")
                    || lower.hasSuffix(".gif") || lower.hasSuffix(".webp") {
                    files.append(ProductFile(path: path, markdown: nil, imageData: raw, source: "github"))
                } else if let text = String(data: raw, encoding: .utf8), !text.isEmpty {
                    files.append(ProductFile(path: path, markdown: text, imageData: nil, source: "github"))
                }
            } catch {
                continue
            }
        }
        return files
    }

    private static func shouldSkip(_ path: String) -> Bool {
        let lower = path.lowercased()
        if lower.hasPrefix("product/baseline/") { return true }
        if lower.hasPrefix("product/blueprint/") { return true }
        if lower.hasSuffix(".html") || lower.hasSuffix(".json") { return true }
        if lower.hasSuffix(".gitkeep") { return true }
        return false
    }

    nonisolated private static func runGhData(_ arguments: [String]) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: resolveGhPath())
                    process.arguments = arguments
                    let out = Pipe()
                    let err = Pipe()
                    process.standardOutput = out
                    process.standardError = err
                    try process.run()
                    process.waitUntilExit()
                    let stdout = out.fileHandleForReading.readDataToEndOfFile()
                    let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    guard process.terminationStatus == 0 else {
                        let msg = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                        cont.resume(throwing: StoreError.githubCLIFailed(msg.isEmpty ? "gh exited \(process.terminationStatus)" : msg))
                        return
                    }
                    cont.resume(returning: stdout)
                } catch {
                    cont.resume(throwing: StoreError.githubCLIFailed(error.localizedDescription))
                }
            }
        }
    }

    nonisolated private static func resolveGhPath() -> String {
        let candidates = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return "/opt/homebrew/bin/gh"
    }
}
