import AppKit
import SwiftUI

/// Local checkout and GitHub remote for an existing project.
/// Same fields as New Project; this is the edit surface after create.
struct ProjectSourcesEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.typography) private var type
    var project: Project
    var compact: Bool = false
    @State private var githubDraft = ""
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            sourceLine
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Local")
                    .font(type.caption)
                    .foregroundStyle(StudioColor.secondary)
                    .frame(width: compact ? 52 : 64, alignment: .leading)
                Text(project.repoPath ?? "—")
                    .font(type.mono)
                    .foregroundStyle(StudioColor.secondary)
                    .lineLimit(1)
                    .help(project.repoPath ?? "")
                Spacer(minLength: 8)
                Button("Choose…") { pickFolder() }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("GitHub")
                    .font(type.caption)
                    .foregroundStyle(StudioColor.secondary)
                    .frame(width: compact ? 52 : 64, alignment: .leading)
                TextField("owner/name", text: $githubDraft)
                    .font(type.mono)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveGitHub() }
                Button("Set") { saveGitHub() }
                    .disabled(githubDraft == (project.githubRepo ?? ""))
            }
            if let saveError {
                Text(saveError)
                    .font(type.caption)
                    .foregroundStyle(StudioColor.secondary)
            }
        }
        .onAppear { githubDraft = project.githubRepo ?? "" }
        .onChange(of: project.githubRepo) { _, next in
            if githubDraft == (project.githubRepo ?? "") || githubDraft.isEmpty {
                githubDraft = next ?? ""
            }
        }
    }

    private var sourceLine: some View {
        HStack(spacing: 6) {
            Image(systemName: sourceSymbol)
                .font(type.caption)
                .foregroundStyle(OriginArkBrand.sageColor)
            Text(DocumentSource.label(project: project, bundle: store.documentBundles[project.id]))
                .font(type.caption)
                .foregroundStyle(StudioColor.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live source \(DocumentSource.label(project: project, bundle: store.documentBundles[project.id]))")
    }

    private var sourceSymbol: String {
        DocumentSource.kind(project: project, bundle: store.documentBundles[project.id]).symbol
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Choose the local checkout that contains product/"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try store.updateRepoPath(projectId: project.id, path: url.path)
                saveError = nil
                Task { await store.refreshDocuments(projectId: project.id) }
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

    private func saveGitHub() {
        do {
            try store.updateGitHubRepo(projectId: project.id, repo: githubDraft)
            githubDraft = store.project(id: project.id)?.githubRepo ?? githubDraft
            saveError = nil
            Task { await store.refreshDocuments(projectId: project.id) }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

enum DocumentSource {
    case local
    case github
    case none

    var symbol: String {
        switch self {
        case .local: return "folder"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .none: return "questionmark.folder"
        }
    }

    static func kind(project: Project, bundle: DocumentBundle?) -> DocumentSource {
        if let source = bundle?.source {
            if source == "github" { return .github }
            if source == "local" { return .local }
            if source == "none" { return .none }
        }
        if project.repoPath != nil { return .local }
        if let repo = project.githubRepo, !repo.isEmpty { return .github }
        return .none
    }

    static func label(project: Project, bundle: DocumentBundle?) -> String {
        switch kind(project: project, bundle: bundle) {
        case .github:
            return "github · \(project.githubRepo ?? "")"
        case .local:
            return "local · product/"
        case .none:
            return "no product/"
        }
    }
}
