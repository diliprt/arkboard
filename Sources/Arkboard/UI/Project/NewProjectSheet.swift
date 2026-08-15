import AppKit
import SwiftUI

struct NewProjectSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.typography) private var type
    @State private var name = ""
    @State private var key = ""
    @State private var color = Hue.indigo.light
    @State private var repoPath = ""
    @State private var githubRepo = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Project").font(type.title)
            TextField("Name", text: $name)
                .onChange(of: name) { _, value in
                    if key.isEmpty || key == Validation.deriveKey(from: String(value.dropLast())) {
                        key = Validation.deriveKey(from: value)
                    }
                }
            TextField("Key", text: $key)
                .onChange(of: key) { _, value in
                    key = value.uppercased().filter { ("A"..."Z").contains($0) || ("0"..."9").contains($0) }
                    if key.count > 6 { key = String(key.prefix(6)) }
                }
            HStack {
                ForEach(Hue.ramp, id: \.self) { hue in
                    Button {
                        color = hue.light
                    } label: {
                        Circle().fill(Color(hex: hue.light)).frame(width: 18, height: 18)
                            .overlay(Circle().stroke(color == hue.light ? StudioColor.primary : Color.clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("Documents folder", text: $repoPath)
                    .font(type.mono)
                Button("Choose…") { pickFolder() }
            }
            TextField("GitHub repository (owner/name)", text: $githubRepo)
                .font(type.mono)
            if let error {
                Text(error).font(type.callout).foregroundStyle(Hue.crimson.color(for: .light))
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create Project") { create() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || key.count < 2)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            repoPath = url.path
        }
    }

    private func create() {
        do {
            let project = try store.createProject(
                key: key,
                name: name,
                color: color,
                summary: "",
                repoPath: repoPath.isEmpty ? nil : repoPath,
                githubRepo: githubRepo.isEmpty ? nil : githubRepo,
                actor: "Riyu"
            )
            store.sidebarSelection = .project(project.id)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
