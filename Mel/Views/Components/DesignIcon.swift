import SwiftUI

/// Line icons drawn in design/v2 that have no matching SF Symbol, from their SVG paths (16-unit viewBox).
struct DesignIcon: View {
    nonisolated enum Glyph {
        /// "Project context" house (`M2.5 6.5L8 2.5l5.5 4v6.25a.75.75 0 0 1-.75.75h-9.5a.75.75 0 0 1-.75-.75z`), stroke 1.4.
        case house
        /// Disclosure chevron (`M4 6l4 4 4-4`), stroke 2.
        case chevronDown
        /// New Spec plus (`M8 3v10M3 8h10`), stroke 1.6.
        case plus
        /// "Needs you" in the toolbar pill (`circle r6.25`, `M8 4.75v3.75M8 11.1v.15`), stroke 1.7.
        case alert
    }

    let glyph: Glyph
    /// Drawn size in points (the SVG's width and height).
    let size: CGFloat

    var body: some View {
        GlyphShape(glyph: glyph)
            .stroke(style: StrokeStyle(lineWidth: lineWidth * size / 16, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var lineWidth: CGFloat {
        switch glyph {
        case .house: 1.4
        case .chevronDown: 2
        case .plus: 1.6
        case .alert: 1.7
        }
    }
}

nonisolated private struct GlyphShape: Shape {
    let glyph: DesignIcon.Glyph

    func path(in rect: CGRect) -> Path {
        let s = rect.width / 16
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        switch glyph {
        case .house:
            path.move(to: p(2.5, 6.5))
            path.addLine(to: p(8, 2.5))
            path.addLine(to: p(13.5, 6.5))
            path.addLine(to: p(13.5, 12.75))
            path.addArc(tangent1End: p(13.5, 13.5), tangent2End: p(12.75, 13.5), radius: 0.75 * s)
            path.addLine(to: p(3.25, 13.5))
            path.addArc(tangent1End: p(2.5, 13.5), tangent2End: p(2.5, 12.75), radius: 0.75 * s)
            path.closeSubpath()
        case .chevronDown:
            path.move(to: p(4, 6))
            path.addLine(to: p(8, 10))
            path.addLine(to: p(12, 6))
        case .alert:
            path.addEllipse(in: CGRect(origin: p(1.75, 1.75), size: CGSize(width: 12.5 * s, height: 12.5 * s)))
            path.move(to: p(8, 4.75))
            path.addLine(to: p(8, 8.5))
            path.move(to: p(8, 11.1))
            path.addLine(to: p(8, 11.25))
        case .plus:
            path.move(to: p(8, 3))
            path.addLine(to: p(8, 13))
            path.move(to: p(3, 8))
            path.addLine(to: p(13, 8))
        }
        return path
    }
}

#Preview("Glyphs") {
    HStack(spacing: Theme.Space.x12) {
        DesignIcon(glyph: .house, size: 15)
        DesignIcon(glyph: .chevronDown, size: 12)
        DesignIcon(glyph: .plus, size: 14)
        DesignIcon(glyph: .alert, size: 14).foregroundStyle(Theme.Colors.caution)
    }
    .foregroundStyle(Theme.Colors.secondaryLabel)
    .padding(Theme.Space.x20)
    .background(Theme.Colors.background)
}
