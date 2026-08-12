import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var showQuickAdd = false
    @State private var showNewProject = false

    var body: some View {
        NavigationSplitView {
            SidebarView(showNewProject: $showNewProject)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } content: {
            ContentColumn(showQuickAdd: $showQuickAdd)
                .navigationSplitViewColumnWidth(min: 360, ideal: 480, max: 720)
        } detail: {
            if let issue = store.selectedIssue {
                IssueDetailView(issue: issue)
            } else {
                ContentUnavailableView(
                    "Select an issue",
                    systemImage: "checkmark.circle",
                    description: Text("Choose an issue from the list or board, or press ⌘N to create one.")
                )
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet()
                .environment(store)
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet()
                .environment(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .arkboardQuickAdd)) { _ in
            showQuickAdd = true
        }
        .alert("Error", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
    }
}

struct ContentColumn: View {
    @Environment(AppStore.self) private var store
    @Binding var showQuickAdd: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedProject?.name ?? "Inbox")
                        .font(.title2.weight(.semibold))
                    Text("\(store.filteredIssues.count) issues")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("View", selection: Bindable(store).viewMode) {
                    ForEach(AppStore.ViewMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                Button {
                    showQuickAdd = true
                } label: {
                    Label("New Issue", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search issues", text: Bindable(store).filter.query)
                    .textFieldStyle(.plain)
                Toggle("Canceled", isOn: Bindable(store).filter.showCanceled)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            Group {
                switch store.viewMode {
                case .list:
                    IssueListView()
                case .board:
                    BoardView()
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
