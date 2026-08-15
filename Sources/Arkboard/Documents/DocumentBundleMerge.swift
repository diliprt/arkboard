import Foundation

enum DocumentBundleMerge {
    /// Keep a successful `product/` load when a later refresh comes back empty.
    static func shouldReplace(
        currentCount: Int,
        incomingCount: Int,
        incomingError: String?,
        incomingSource: String,
        incomingHasRoot: Bool
    ) -> Bool {
        if incomingCount > 0 { return true }
        if currentCount == 0 { return true }
        if incomingSource == "local", incomingHasRoot, incomingError == nil { return true }
        return false
    }

    static func shouldReplace(current: DocumentBundle?, incoming: DocumentBundle) -> Bool {
        shouldReplace(
            currentCount: current?.documents.count ?? 0,
            incomingCount: incoming.documents.count,
            incomingError: incoming.error,
            incomingSource: incoming.source,
            incomingHasRoot: incoming.root != nil
        )
    }
}
