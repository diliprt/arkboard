import SwiftUI

struct PortfolioView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                totalsRow
                if store.portfolioCards.isEmpty {
                    ContentUnavailableView(
                        "No projects yet",
                        systemImage: "square.grid.2x2",
                        description: Text("Create a project to see portfolio cards.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                        ForEach(store.portfolioCards) { card in
                            ProjectPortfolioCardView(card: card) {
                                store.selectProject(card.project.id)
                            }
                        }
                    }
                }
                seedBar
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Portfolio")
                .font(.title2.weight(.semibold))
            Text("Bird's-eye view across every project")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var totalsRow: some View {
        let t = store.portfolioTotals
        return HStack(spacing: 12) {
            PortfolioStatChip(title: "Open work", value: t.openWork, tint: Color(hex: "#5E6AD2"))
            PortfolioStatChip(title: "In progress", value: t.inProgress, tint: Color(hex: "#F2C94C"))
            PortfolioStatChip(title: "Features", value: t.features, tint: Color(hex: "#4EA7FC"))
            PortfolioStatChip(title: "Bugs", value: t.bugs, tint: Color(hex: "#EB5757"))
            Spacer(minLength: 0)
        }
    }

    private var seedBar: some View {
        HStack {
            Text("Need a demo of agents talking?")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Seed demo agent activity") {
                Task { await store.seedDemoAgentActivity() }
            }
            .controlSize(.small)
            Spacer()
        }
        .padding(.top, 8)
    }
}

private struct PortfolioStatChip: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ProjectPortfolioCardView: View {
    let card: ProjectPortfolioCard
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: card.project.color))
                        .frame(width: 10, height: 10)
                    Text(card.project.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(card.project.key)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Text("\(card.total) issue\(card.total == 1 ? "" : "s") · \(card.openCount) open")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Status breakdown
                HStack(spacing: 6) {
                    ForEach(IssueStatus.allCases) { status in
                        let count = card.byStatus[status] ?? 0
                        if count > 0 {
                            Text("\(status.displayName) \(count)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }

                HStack(spacing: 10) {
                    Label("\(card.featureCount) feature", systemImage: "sparkles")
                    Label("\(card.bugCount) bug", systemImage: "ant")
                    Label("\(card.otherCount) other", systemImage: "tag")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
        .help("Open \(card.project.name)")
    }
}
