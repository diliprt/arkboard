import SwiftUI

struct ActivityFeedView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity")
                        .font(.title2.weight(.semibold))
                    Text("Agents talking — Product, Ops, Comms, and you")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Seed demo agent activity") {
                    Task { await store.seedDemoAgentActivity() }
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if store.activities.isEmpty {
                ContentUnavailableView {
                    Label("No activity yet", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("Mutations from the UI or MCP show up here. Seed a demo conversation to preview agents talking.")
                } actions: {
                    Button("Seed demo agent activity") {
                        Task { await store.seedDemoAgentActivity() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.activities) { activity in
                    ActivityRow(activity: activity)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let issue = store.issue(forActivity: activity) {
                                store.selection = .project(issue.projectId)
                                store.selectedIssueId = issue.id
                            } else if let project = store.project(forActivity: activity) {
                                store.selectProject(project.id)
                            }
                        }
                }
                .listStyle(.plain)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct ActivityRow: View {
    @Environment(AppStore.self) private var store
    let activity: Activity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ActorAvatar(name: activity.actor, size: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(activity.actor)
                        .font(.subheadline.weight(.semibold))
                    Text(actionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(activity.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(activity.summary)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if let issue = store.issue(forActivity: activity) {
                        Text(issue.identifier)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if let project = store.project(forActivity: activity) {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: project.color)).frame(width: 6, height: 6)
                            Text(project.key)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    if activity.action == ActivityAction.commented.rawValue {
                        Text("comment")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ActorStyle.color(for: activity.actor).opacity(0.18))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var actionLabel: String {
        ActivityAction(rawValue: activity.action)?.displayName ?? activity.action.replacingOccurrences(of: "_", with: " ")
    }
}
