import SwiftUI

struct BoardView: View {
    @Environment(AppStore.self) private var store

    private var columns: [IssueStatus] {
        var cols = IssueStatus.allCases
        if !store.filter.showCanceled {
            cols = cols.filter { $0 != .canceled }
        }
        return cols
    }

    var body: some View {
        Group {
            if store.projects.isEmpty {
                EmptyProjectsView()
            } else if !store.boardAvailable {
                ContentUnavailableView {
                    Label("Board is per-project", systemImage: "rectangle.split.3x1")
                } description: {
                    Text("Select a project in the sidebar to use the board. Inbox stays list-first so issues from different projects are not mixed into unlabeled columns.")
                }
            } else if store.filteredIssues.isEmpty {
                EmptyIssuesView(
                    hasActiveSearch: !store.filter.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(columns) { status in
                            BoardColumnView(status: status, issues: store.issues(for: status))
                        }
                    }
                    .padding(16)
                    .frame(minHeight: 420)
                }
                .accessibilityLabel("Issue board")
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }
}

struct BoardColumnView: View {
    @Environment(AppStore.self) private var store
    let status: IssueStatus
    let issues: [Issue]

    @State private var appendTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(status.displayName)
                    .font(.headline)
                Spacer()
                Text("\(issues.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
                    .accessibilityLabel("\(issues.count) issues")
            }
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if issues.isEmpty {
                        appendDropZone(minHeight: 72, label: "Drop issues here")
                    }

                    ForEach(issues) { issue in
                        BoardCardView(issue: issue)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.selectedIssueId = issue.id
                            }
                            .draggable(issue.id) {
                                BoardCardView(issue: issue)
                                    .frame(width: 240)
                                    .opacity(0.9)
                            }
                            // Card-level only: insert before this card.
                            // Column append uses a separate bottom zone (no nested outer dropDestination).
                            .dropDestination(for: String.self) { items, _ in
                                guard let id = items.first, id != issue.id else { return false }
                                guard looksLikeIssueID(id) else { return false }
                                Task {
                                    try? await store.moveIssue(id, to: status, before: issue.id)
                                    store.selectedIssueId = id
                                }
                                return true
                            }
                    }

                    if !issues.isEmpty {
                        appendDropZone(minHeight: 36, label: nil)
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(10)
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    appendTargeted ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.15),
                    lineWidth: appendTargeted ? 2 : 1
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(status.displayName) column")
    }

    @ViewBuilder
    private func appendDropZone(minHeight: CGFloat, label: String?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(appendTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
            if let label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(appendTargeted ? Color.accentColor : Color.secondary.opacity(0.7))
            } else if appendTargeted {
                Text("Drop to move here")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: minHeight)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: appendTargeted ? 2 : 1, dash: [5, 4])
                )
                .foregroundStyle(appendTargeted ? Color.accentColor : Color.secondary.opacity(0.35))
        )
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first, looksLikeIssueID(id) else { return false }
            Task {
                try? await store.moveIssue(id, to: status, before: nil)
                store.selectedIssueId = id
            }
            return true
        } isTargeted: { targeted in
            appendTargeted = targeted
        }
        .accessibilityLabel(label ?? "Drop zone to append in \(status.displayName)")
    }

    private func looksLikeIssueID(_ value: String) -> Bool {
        // Issue ids are UUID strings from createIssue / seed.
        UUID(uuidString: value) != nil
    }
}

struct BoardCardView: View {
    @Environment(AppStore.self) private var store
    let issue: Issue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(issue.identifier)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: issue.priority.symbolName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Text(issue.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            if !store.labels(for: issue).isEmpty {
                HStack(spacing: 4) {
                    ForEach(store.labels(for: issue).prefix(3)) { label in
                        Text(label.name)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(hex: label.color).opacity(0.18))
                            .foregroundStyle(Color(hex: label.color))
                            .clipShape(Capsule())
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Labels: \(store.labels(for: issue).prefix(3).map(\.name).joined(separator: ", "))")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    store.selectedIssueId == issue.id ? Color.accentColor : Color.secondary.opacity(0.12),
                    lineWidth: store.selectedIssueId == issue.id ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(issue.identifier). \(issue.title). Priority \(issue.priority.displayName)")
        .accessibilityAddTraits(store.selectedIssueId == issue.id ? .isSelected : [])
        .accessibilityHint("Drag to another column to change status")
    }
}
