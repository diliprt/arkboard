import Foundation

/// Brand mark for a project: a persisted SF Symbol plus colour, or an image in `product/`.
enum ProjectMark: Sendable {
    static let arkboardSymbol = "square.3.layers.3d"
    static let arkboardColor = "#5A62D6"

    /// Distinct SF Symbols so the portfolio is never a row of identical dots.
    static let symbols: [String] = [
        "square.3.layers.3d",
        "paintbrush.pointed.fill",
        "cube.transparent",
        "antenna.radiowaves.left.and.right",
        "leaf.fill",
        "bolt.horizontal.fill",
        "globe.desk",
        "camera.aperture",
        "shippingbox.fill",
        "waveform.path",
        "puzzlepiece.extension.fill",
        "compass.drawing",
        "book.closed.fill",
        "sparkle",
        "hammer.fill",
        "map.fill",
        "theatermasks.fill",
        "moon.stars.fill",
        "hare.fill",
        "tram.fill",
    ]

    static let productIconNames: [String] = [
        "icon.png", "icon.webp", "icon.jpg", "icon.jpeg",
        "mark.png", "mark.webp",
        "logo.png", "logo.webp",
    ]

    static func isArkboard(key: String, name: String) -> Bool {
        key.uppercased() == "ARK" || name.compare("Arkboard", options: .caseInsensitive) == .orderedSame
    }

    static func assigned(key: String, name: String, usedSymbols: Set<String>, existingColor: String? = nil) -> (symbol: String, color: String) {
        if isArkboard(key: key, name: name) {
            return (arkboardSymbol, arkboardColor)
        }
        let hash = Hue.fnv1a(key.lowercased())
        let start = Int(hash % UInt32(symbols.count))
        var symbol = symbols[start]
        for offset in 0..<symbols.count {
            let candidate = symbols[(start + offset) % symbols.count]
            if candidate == arkboardSymbol { continue }
            if !usedSymbols.contains(candidate) {
                symbol = candidate
                break
            }
        }
        if let existingColor, !existingColor.isEmpty, existingColor.uppercased() != arkboardColor {
            return (symbol, existingColor)
        }
        let color = Hue.ramp[Int(hash % UInt32(Hue.ramp.count))].light
        return (symbol, color)
    }

    static func isProductIcon(path: String) -> Bool {
        let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        return productIconNames.contains(name)
    }
}
