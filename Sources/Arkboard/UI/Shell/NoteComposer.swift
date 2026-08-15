import SwiftUI

struct NoteComposer: View {
    @Environment(AppStore.self) private var store
    @Environment(\.typography) private var type
    var projectKey: String?
    var allowStudioScope: Bool = false
    @State private var draft = ""
    @State private var scopeKey: String = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        CardSurface(hue: .indigo) {
            HStack(alignment: .top, spacing: 12) {
                ProjectDot(hex: Hue.moss.light, size: 10)
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Tell the team…", text: $draft, axis: .vertical)
                        .font(type.body)
                        .lineLimit(1...5)
                        .focused($composerFocused)
                        .textFieldStyle(.plain)
                    HStack {
                        if allowStudioScope {
                            Picker("Scope", selection: $scopeKey) {
                                Text("to Studio").tag("studio")
                                ForEach(store.projects) { project in
                                    Text("to \(project.name)").tag(project.key)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 200)
                        }
                        Spacer()
                        Text("⌘↩")
                            .font(type.caption)
                            .foregroundStyle(StudioColor.tertiary)
                        Button("Send", action: send)
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .keyboardShortcut(.return, modifiers: .command)
                    }
                }
            }
        }
        .onAppear {
            if scopeKey.isEmpty {
                scopeKey = projectKey ?? "studio"
            }
        }
        .onChange(of: store.focusComposer) { _, _ in
            composerFocused = true
        }
    }

    private func send() {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let key: String?
        if allowStudioScope {
            key = scopeKey == "studio" ? nil : scopeKey
        } else {
            key = projectKey
        }
        _ = try? store.postNote(body: body, projectKey: key, actor: "Riyu")
        draft = ""
    }
}
