import SwiftUI

/// The one floating element in the app, and the one shadow. Archiving is the
/// only mutation a human can make to an issue, so it is the only thing that
/// needs an undo.
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
                SwiftUI.Label("Dismiss", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(type.caption)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Concentric.shape(Metrics.radiusSheet))
        .shadow(color: StudioColor.shadow(scheme: scheme), radius: 12, y: 4)
    }
}
