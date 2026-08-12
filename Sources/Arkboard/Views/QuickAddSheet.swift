import SwiftUI

struct QuickAddSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var projectId: String = ""
    @State private var status: IssueStatus = .backlog
    @State private var priority: IssuePriority = .none
    @State private var labelTokens: [String] = []
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Issue")
                .font(.title2.weight(.semibold))

            TextField("Issue title", text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await save() } }

            TextField("Description (optional)", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 60)

            if store.projects.isEmpty {
                Text("Create a project before adding issues.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                Picker("Project", selection: $projectId) {
                    ForEach(store.projects) { project in
                        Text("\(project.key) — \(project.name)").tag(project.id)
                    }
                }
            }

            HStack {
                Picker("Status", selection: $status) {
                    ForEach(IssueStatus.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                Picker("Priority", selection: $priority) {
                    ForEach(IssuePriority.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Labels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabelTokensField(tokens: $labelTokens, placeholder: "Add label, Return or comma")
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create Issue") {
                    Task { await save() }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || store.projects.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear {
            projectId = store.selectedProjectId ?? store.projects.first?.id ?? ""
        }
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await store.createIssue(
                projectId: projectId.isEmpty ? nil : projectId,
                title: title,
                description: description,
                status: status,
                priority: priority,
                labelNames: labelTokens
            )
            dismiss()
        } catch {
            store.lastError = error.localizedDescription
        }
    }
}

struct NewProjectSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var key = ""
    @State private var name = ""
    @State private var color = "#5E6AD2"

    private let swatches = ["#5E6AD2", "#26B5CE", "#4CB782", "#F2C94C", "#F2994A", "#EB5757", "#BB87FC"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Project")
                .font(.title2.weight(.semibold))

            TextField("Key (e.g. ARK)", text: $key)
                .textFieldStyle(.roundedBorder)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Color")
                ForEach(swatches, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color.primary, lineWidth: color == hex ? 2 : 0)
                        )
                        .onTapGesture { color = hex }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create") {
                    Task {
                        do {
                            _ = try await store.createProject(key: key, name: name.isEmpty ? key : name, color: color)
                            dismiss()
                        } catch {
                            store.lastError = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(key.trimmingCharacters(in: .whitespaces).count < 2)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
