import SwiftUI

struct Typography: Equatable {
    var bodySize: CGFloat
    var family: FontFamilyID

    static let `default` = Typography(bodySize: 13, family: .system)

    var display: Font { face(size: bodySize + 10, weight: .semibold) }
    var title: Font { face(size: bodySize + 6, weight: .semibold) }
    var heading: Font { face(size: bodySize + 3, weight: .semibold) }
    var subheading: Font { face(size: bodySize + 1, weight: .medium) }
    var body: Font { face(size: bodySize, weight: .regular) }
    var bodyStrong: Font { face(size: bodySize, weight: .medium) }
    var callout: Font { face(size: bodySize - 1, weight: .regular) }
    var caption: Font { face(size: max(10, bodySize - 2), weight: .medium) }
    var mono: Font { .system(size: bodySize - 1, weight: .regular, design: .monospaced) }

    var lineSpacing: CGFloat { max(3, (bodySize * 0.3).rounded()) }
    var blockGap: CGFloat { bodySize }
    var headingAir: CGFloat { bodySize }
    var deepHeadingAir: CGFloat { bodySize / 2 }

    func face(size: CGFloat, weight: Font.Weight) -> Font {
        switch family {
        case .system:
            return .system(size: size, weight: weight, design: .default)
        case .newYork:
            return .system(size: size, weight: weight, design: .serif)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .sfMono:
            return .system(size: size, weight: weight, design: .monospaced)
        case .helveticaNeue:
            return .custom("Helvetica Neue", size: size).weight(weight)
        case .georgia:
            return .custom("Georgia", size: size).weight(weight)
        case .avenirNext:
            return .custom("Avenir Next", size: size).weight(weight)
        case .menlo:
            return .custom("Menlo", size: size).weight(weight)
        }
    }
}

private struct TypographyKey: EnvironmentKey {
    static let defaultValue = Typography.default
}

extension EnvironmentValues {
    var typography: Typography {
        get { self[TypographyKey.self] }
        set { self[TypographyKey.self] = newValue }
    }
}

enum Metrics {
    static let space: [CGFloat] = [2, 4, 8, 12, 16, 20, 24, 32, 40]
    static let paneX: CGFloat = 24
    static let paneY: CGFloat = 20
    static let cardPad: CGFloat = 14
    static let chipX: CGFloat = 10
    static let chipY: CGFloat = 4
    static let cardGap: CGFloat = 12
    static let sectionGap: CGFloat = 28
    static let sidebarIdeal: CGFloat = 232
    static let sidebarMin: CGFloat = 200
    static let sidebarMax: CGFloat = 300
    static let outlineIdeal: CGFloat = 220
    static let outlineMin: CGFloat = 180
    static let outlineMax: CGFloat = 280
    static let documentMin: CGFloat = 560
    static let documentIdeal: CGFloat = 720
    static let issuesIdeal: CGFloat = 420
    static let issuesMin: CGFloat = 340
    static let issuesMax: CGFloat = 620
    static let windowMin = CGSize(width: 1080, height: 700)
    static let windowDefault = CGSize(width: 1320, height: 860)
    // One radius family. A surface nested inside another takes the container's
    // radius less the inset between them, so the two curves share a centre.
    static let radiusSheet: CGFloat = 14
    static let radiusCard: CGFloat = 10
    static let radiusChip: CGFloat = Concentric.inner(of: radiusCard, inset: chipY)
    static let radiusMark: CGFloat = Concentric.inner(of: radiusCard, inset: 4)
    static let proseMax: CGFloat = 720
    static let gridMax: CGFloat = 1000
    static let markerColumn: CGFloat = 18
    static let tabFade: CGFloat = 24
    static let tabPillX: CGFloat = 10
    static let emptyPaneMin: CGFloat = 280
    static let ganttLabelColumn: CGFloat = 240
    static let ganttAxisHeight: CGFloat = 26
    static let ganttProjectRow: CGFloat = 34
    static let ganttMilestoneRow: CGFloat = 28
    static let ganttProjectBar: CGFloat = 14
    static let ganttMilestoneBar: CGFloat = 8
    static let ganttDiamond: CGFloat = 10
    static let ganttBarMin: CGFloat = 10
    static let ganttLinkElbow: CGFloat = 10
}

enum DocumentMeasure {
    /// Project-home page width. Fill the pane; never a 720 island or a 1000 grid.
    static func pageWidth(paneWidth: CGFloat) -> CGFloat {
        max(paneWidth, Metrics.documentMin)
    }
}
