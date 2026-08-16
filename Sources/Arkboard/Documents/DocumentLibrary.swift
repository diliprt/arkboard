import Foundation

actor DocumentLibrary {
    private var cache: [String: DocumentBundle] = [:]

    func bundle(for project: Project) async -> DocumentBundle {
        if let cached = cache[project.id] { return cached }
        let loaded = await load(project)
        cache[project.id] = loaded
        return loaded
    }

    func refresh(project: Project) async -> DocumentBundle {
        let loaded = await load(project)
        if let cached = cache[project.id],
           !DocumentBundleMerge.shouldReplace(current: cached, incoming: loaded) {
            return cached
        }
        cache[project.id] = loaded
        return loaded
    }

    func dropAll() {
        cache.removeAll()
    }

    func read(project: Project, path: String) async throws -> StudioDocument {
        let safe = try Validation.documentPath(path)
        let bundle = await self.bundle(for: project)
        if let document = bundle.documents.first(where: { $0.path == safe }) {
            return document
        }
        throw ValidationError.missingDocument
    }

    private func load(_ project: Project) async -> DocumentBundle {
        if let local = localRoot(for: project) {
            do {
                let documents = try readTree(root: local)
                return DocumentBundle(source: "local", root: local.path, documents: documents, loadedAt: Date(), error: nil)
            } catch {
                return DocumentBundle(source: "local", root: local.path, documents: [], loadedAt: Date(), error: error.localizedDescription)
            }
        }
        if let repo = project.githubRepo, !repo.isEmpty {
            do {
                let documents = try await fetchGitHub(repo: repo)
                return DocumentBundle(source: "github", root: "github://\(repo)/product", documents: documents, loadedAt: Date(), error: nil)
            } catch {
                return DocumentBundle(source: "github", root: nil, documents: [], loadedAt: Date(), error: error.localizedDescription)
            }
        }
        return DocumentBundle(source: "none", root: nil, documents: [], loadedAt: Date(), error: nil)
    }

    func localRoot(for project: Project) -> URL? {
        if let path = project.repoPath, FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent("product")) {
            return URL(fileURLWithPath: path).appendingPathComponent("product", isDirectory: true)
        }
        if let env = ProcessInfo.processInfo.environment["ARKBOARD_REPO_ROOT"],
           FileManager.default.fileExists(atPath: (env as NSString).appendingPathComponent("product")) {
            return URL(fileURLWithPath: env).appendingPathComponent("product", isDirectory: true)
        }
        if let walked = walkFromBundle() {
            return walked
        }
        return nil
    }

    nonisolated static func resolvedRepoRoot(repoPath: String?) -> String? {
        if let path = repoPath, FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent("product")) {
            return path
        }
        if let env = ProcessInfo.processInfo.environment["ARKBOARD_REPO_ROOT"],
           FileManager.default.fileExists(atPath: (env as NSString).appendingPathComponent("product")) {
            return env
        }
        if let product = walkFromBundleStatic() {
            return product.deletingLastPathComponent().path
        }
        return nil
    }

    private func walkFromBundle() -> URL? {
        Self.walkFromBundleStatic()
    }

    nonisolated private static func walkFromBundleStatic() -> URL? {
        var url = Bundle.main.bundleURL
        for _ in 0..<10 {
            let product = url.appendingPathComponent("product", isDirectory: true)
            let git = url.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: product.path),
               FileManager.default.fileExists(atPath: git.path) {
                return product
            }
            url.deleteLastPathComponent()
        }
        return nil
    }

    private func readTree(root: URL) throws -> [StudioDocument] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        var documents: [StudioDocument] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
            guard values.isRegularFile == true else { continue }
            let relative = "product/" + fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
            if DocumentRouting.shouldIgnore(relative) { continue }
            if DocumentRouting.isText(relative) {
                let markdown = try String(contentsOf: fileURL, encoding: .utf8)
                documents.append(
                    StudioDocument(
                        path: relative,
                        tab: DocumentRouting.tab(for: relative),
                        title: DocumentRouting.title(for: relative),
                        markdown: markdown,
                        imageData: nil,
                        isImage: false,
                        bytes: markdown.utf8.count,
                        modifiedAt: values.contentModificationDate ?? Date(),
                        absoluteURL: fileURL
                    )
                )
            } else if DocumentRouting.isImage(relative) {
                let data = try Data(contentsOf: fileURL)
                documents.append(
                    StudioDocument(
                        path: relative,
                        // Ask the router. Most images are frames, but a project's
                        // own poster and mark are brand artwork and must not turn
                        // up in the Mockups gallery.
                        tab: DocumentRouting.tab(for: relative),
                        title: DocumentRouting.title(for: relative),
                        markdown: nil,
                        imageData: data,
                        isImage: true,
                        bytes: data.count,
                        modifiedAt: values.contentModificationDate ?? Date(),
                        absoluteURL: fileURL
                    )
                )
            }
        }
        return documents.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }

    private func fetchGitHub(repo: String) async throws -> [StudioDocument] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "api", "repos/\(repo)/git/trees/HEAD?recursive=1"]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "DocumentLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: err.isEmpty ? "gh could not read \(repo)" : err.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tree = object["tree"] as? [[String: Any]] else {
            throw NSError(domain: "DocumentLibrary", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected GitHub tree response for \(repo)."])
        }
        var documents: [StudioDocument] = []
        for item in tree {
            guard let path = item["path"] as? String, path.hasPrefix("product/") else { continue }
            if DocumentRouting.shouldIgnore(path) { continue }
            if DocumentRouting.isText(path) {
                let markdown = try await fetchGitHubFile(repo: repo, path: path)
                documents.append(
                    StudioDocument(
                        path: path,
                        tab: DocumentRouting.tab(for: path),
                        title: DocumentRouting.title(for: path),
                        markdown: markdown,
                        imageData: nil,
                        isImage: false,
                        bytes: markdown.utf8.count,
                        modifiedAt: Date(),
                        absoluteURL: nil
                    )
                )
            } else if DocumentRouting.isImage(path) {
                // Remote mockups and brand artwork live in the same tree as
                // the prose. Skip a single failed image rather than failing
                // the whole product/ read.
                if let data = try? await fetchGitHubBytes(repo: repo, path: path) {
                    documents.append(
                        StudioDocument(
                            path: path,
                            tab: DocumentRouting.tab(for: path),
                            title: DocumentRouting.title(for: path),
                            markdown: nil,
                            imageData: data,
                            isImage: true,
                            bytes: data.count,
                            modifiedAt: Date(),
                            absoluteURL: nil
                        )
                    )
                }
            }
        }
        return documents.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }

    private func fetchGitHubFile(repo: String, path: String) async throws -> String {
        let data = try await fetchGitHubBytes(repo: repo, path: path)
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "DocumentLibrary", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not decode \(path) from \(repo)."])
        }
        return text
    }

    private func fetchGitHubBytes(repo: String, path: String) async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "api", "repos/\(repo)/contents/\(path)", "--jq", ".content"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        let raw = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let cleaned = raw.replacingOccurrences(of: "\n", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, let data = Data(base64Encoded: cleaned) else {
            throw NSError(domain: "DocumentLibrary", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not decode \(path) from \(repo)."])
        }
        return data
    }
}
