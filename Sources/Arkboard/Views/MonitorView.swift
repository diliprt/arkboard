import SwiftUI

struct MonitorView: View {
    @Environment(AppStore.self) private var store
    @State private var composerText = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(
                section: .monitor,
                subtitle: "Open questions and requirements that are not working"
            )
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    composer
                    questionsSection
                    notWorkingSection
                }
                .padding(20)
                .frame(maxWidth: 920, alignment: .leading)
            }
        }
        .sectionWash(.monitor)
        .onChange(of: store.composerFocusToken) { _, _ in
            composerFocused = true
        }
        .onAppear {
            if store.composerFocusToken > 0 {
                composerFocused = true
            }
        }
        .task {
            await store.productLibrary.prefetch(projects: store.projects)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ActorAvatar(name: "Riyu", size: 28)
            TextField("Tell the team…", text: $composerText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .appBodyFont()
                .lineLimit(1...4)
                .focused($composerFocused)
                .onSubmit { Task { await sendComposer() } }
            Button("Send") {
                Task { await sendComposer() }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .background(StudioSection.monitor.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sendComposer() async {
        let text = composerText
        do {
            _ = try await store.tellTheTeam(text)
            composerText = ""
        } catch {
            store.lastError = error.localizedDescription
        }
    }

    private var questionsSection: some View {
        let questions = store.productLibrary.questions(across: store.projects)
        return VStack(alignment: .leading, spacing: 10) {
            laneTitle("Open questions", count: questions.count, section: .decisions)
            if questions.isEmpty {
                emptyHint("No open questions in product/ yet. A director pass will write them.")
            } else {
                ForEach(questions) { question in
                    Button {
                        store.selection = .project(question.projectId)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "questionmark.bubble")
                                    .foregroundStyle(StudioSection.decisions.accent)
                                Text(question.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if let project = store.projects.first(where: { $0.id == question.projectId }) {
                                    Text(project.key)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if !question.excerpt.isEmpty {
                                Text(question.excerpt)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(StudioSection.decisions.wash)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var notWorkingSection: some View {
        let items = store.notWorkingRequirements
        return VStack(alignment: .leading, spacing: 10) {
            laneTitle("Not working", count: items.count, section: .design)
            if items.isEmpty {
                emptyHint("Every requirement is working — or none are filed yet.")
            } else {
                ForEach(items) { requirement in
                    Button {
                        store.selectProject(requirement.projectId)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: RequirementWorking.not_working.tintHex))
                                    .frame(width: 8, height: 8)
                                Text(requirement.identifier)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Text(requirement.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if let project = store.project(for: requirement) {
                                    Text(project.key)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if !requirement.bodyMarkdown.isEmpty {
                                MarkdownPreview(markdown: requirement.bodyMarkdown, accent: StudioSection.design.accent)
                                    .lineLimit(3)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(StudioSection.design.wash)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func laneTitle(_ title: String, count: Int, section: StudioSection) -> some View {
        HStack(spacing: 8) {
            Image(systemName: section.symbol)
                .foregroundStyle(section.accent)
            Text(title)
                .font(.headline)
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
