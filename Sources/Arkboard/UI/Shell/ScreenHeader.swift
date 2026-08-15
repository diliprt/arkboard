import SwiftUI

struct ScreenHeader: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var section: StudioSection
    var subtitle: String
    var trailing: AnyView? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: section.symbol)
                    .font(type.heading)
                    .foregroundStyle(section.hue.color(for: scheme))
                Text(section.title)
                    .font(type.title)
                    .foregroundStyle(StudioColor.primary)
                Spacer()
                if let trailing { trailing }
            }
            Text(subtitle)
                .font(type.callout)
                .foregroundStyle(StudioColor.secondary)
        }
        .padding(.horizontal, Metrics.paneX)
        .padding(.top, Metrics.paneY)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StudioColor.divider(section.hue, scheme: scheme))
                .frame(height: 1)
        }
    }
}

struct UndoToast: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.typography) private var type
    var identifier: String
    var onUndo: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Archived \(identifier)")
                .font(type.body)
            Button("Undo", action: onUndo)
                .font(type.bodyStrong)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(type.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.radiusSheet, style: .continuous))
        .shadow(color: StudioColor.shadow(scheme: scheme), radius: 12, y: 4)
    }
}
