import SwiftUI

/// Line icons drawn in design/v2 that have no matching SF Symbol, stroked from the design's own SVG path data.
struct DesignIcon: View {
    nonisolated enum Glyph {
        case house, chevronDown, chevronRight, arrowRight, plus, alert, terminal, check, folder, folderPlus, doc, gear, close, paperclip, popUp, draftNow, inspector

        /// SVG `d` attribute, as written in the `.dc.html` (circles written as two arcs).
        var path: String {
            switch self {
            case .house: "M2.5 6.5L8 2.5l5.5 4v6.25a.75.75 0 0 1-.75.75h-9.5a.75.75 0 0 1-.75-.75z"
            case .chevronDown: "M4 6l4 4 4-4"
            case .chevronRight: "M6 3l5 5-5 5"
            case .arrowRight: "M3 8h10M9 4l4 4-4 4"
            case .draftNow: "M3 3.5l5 4.5-5 4.5M8.5 3.5l5 4.5-5 4.5"
            case .inspector: "M3.75 2.75H12.25A2 2 0 0 1 14.25 4.75V11.25A2 2 0 0 1 12.25 13.25H3.75A2 2 0 0 1 1.75 11.25V4.75A2 2 0 0 1 3.75 2.75ZM10 2.75V13.25"
            case .plus: "M8 3v10M3 8h10"
            case .alert: "M8 1.75A6.25 6.25 0 1 1 8 14.25A6.25 6.25 0 1 1 8 1.75zM8 4.75v3.75M8 11.1v.15"
            case .terminal: "M4 5l3 3-3 3M8.5 11.5H12"
            case .check: "M3.5 8.5l3 3 6-7"
            case .folder: Self.folderPath
            case .folderPlus: Self.folderPath + "M8 7.25v4M6 9.25h4"
            case .doc: "M9.5 1.5H4.5a1.5 1.5 0 0 0-1.5 1.5v10a1.5 1.5 0 0 0 1.5 1.5h7a1.5 1.5 0 0 0 1.5-1.5V5zM9.5 1.5V5H13"
            case .gear: "M8 5.8A2.2 2.2 0 1 1 8 10.2A2.2 2.2 0 1 1 8 5.8zM8 1.5v1.6M8 12.9v1.6M1.5 8h1.6M12.9 8h1.6M3.4 3.4l1.1 1.1M11.5 11.5l1.1 1.1M3.4 12.6l1.1-1.1M11.5 4.5l1.1-1.1"
            case .close: "M4 4l8 8M12 4l-8 8"
            case .paperclip: "M13.5 7.5l-5.3 5.3a3.5 3.5 0 0 1-5-5l5.6-5.6a2.3 2.3 0 0 1 3.3 3.3L6.6 11a1.2 1.2 0 0 1-1.7-1.7l4.9-4.9"
            case .popUp: "M2 5l3-3 3 3M2 9l3 3 3-3"
            }
        }

        private static let folderPath = "M1.75 4.5a1.25 1.25 0 0 1 1.25-1.25h3l1.5 1.5H13a1.25 1.25 0 0 1 1.25 1.25v6.25A1.25 1.25 0 0 1 13 13.5H3a1.25 1.25 0 0 1-1.25-1.25z"

        /// SVG stroke-width as drawn.
        var lineWidth: CGFloat {
            switch self {
            case .house, .folder, .doc, .gear, .inspector: 1.4
            case .chevronDown, .check: 2
            case .chevronRight, .arrowRight: 2.2
            case .plus, .terminal, .popUp: 1.6
            case .alert: 1.7
            case .folderPlus: 1
            case .close: 2.6
            case .paperclip, .draftNow: 1.5
            }
        }

        /// SVG viewBox (16 × 16, except the pop-up arrows: 10 × 14).
        var viewBox: CGSize { self == .popUp ? CGSize(width: 10, height: 14) : CGSize(width: 16, height: 16) }
    }

    let glyph: Glyph
    /// Drawn width in points (the SVG's width); the height follows the viewBox.
    let size: CGFloat
    /// SVG stroke-width, when the design draws this glyph with another weight.
    var weight: CGFloat?

    var body: some View {
        let scale = size / glyph.viewBox.width
        SVGPathShape(data: glyph.path, viewBox: glyph.viewBox)
            .stroke(style: StrokeStyle(lineWidth: (weight ?? glyph.lineWidth) * scale, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: glyph.viewBox.height * scale)
            .accessibilityHidden(true)
    }
}

/// SVG path data (M L H V A Z, absolute and relative) scaled from its viewBox into the rect.
nonisolated struct SVGPathShape: Shape {
    let data: String
    let viewBox: CGSize

    func path(in rect: CGRect) -> Path {
        Self.parse(data).applying(
            CGAffineTransform(translationX: rect.minX, y: rect.minY)
                .scaledBy(x: rect.width / viewBox.width, y: rect.height / viewBox.height)
        )
    }

    static func parse(_ data: String) -> Path {
        var path = Path()
        var scanner = Scanner(Array(data))
        var current = CGPoint.zero, start = CGPoint.zero
        var command: Character = "M"
        while let c = scanner.command() {
            if let c { command = c }
            let relative = command.isLowercase
            func point() -> CGPoint {
                let p = CGPoint(x: scanner.number(), y: scanner.number())
                return relative ? CGPoint(x: current.x + p.x, y: current.y + p.y) : p
            }
            switch command.uppercased() {
            case "M":
                current = point(); start = current
                path.move(to: current)
                command = relative ? "l" : "L"   // further pairs are lines
            case "L":
                current = point(); path.addLine(to: current)
            case "H":
                let x = scanner.number(); current.x = relative ? current.x + x : x; path.addLine(to: current)
            case "V":
                let y = scanner.number(); current.y = relative ? current.y + y : y; path.addLine(to: current)
            case "A":
                let rx = scanner.number(), ry = scanner.number(), angle = scanner.number()
                let large = scanner.flag(), sweep = scanner.flag()
                let end = point()
                addArc(to: &path, from: current, to: end, rx: rx, ry: ry, degrees: angle, large: large, sweep: sweep)
                current = end
            case "Z":
                path.closeSubpath(); current = start
            default:
                return path
            }
        }
        return path
    }

    /// SVG endpoint arc to center form (SVG 1.1 F.6.5), drawn as short line segments.
    private static func addArc(to path: inout Path, from p0: CGPoint, to p1: CGPoint, rx: CGFloat, ry: CGFloat, degrees: CGFloat, large: Bool, sweep: Bool) {
        guard rx > 0, ry > 0, p0 != p1 else { path.addLine(to: p1); return }
        let phi = degrees * .pi / 180, cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy, y1 = -sinPhi * dx + cosPhi * dy
        var rx = rx, ry = ry
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let coef = (large == sweep ? -1 : 1) * sqrt(max(0, num / den))
        let cx1 = coef * rx * y1 / ry, cy1 = -coef * ry * x1 / rx
        let cx = cosPhi * cx1 - sinPhi * cy1 + (p0.x + p1.x) / 2
        let cy = sinPhi * cx1 + cosPhi * cy1 + (p0.y + p1.y) / 2
        let theta = atan2((y1 - cy1) / ry, (x1 - cx1) / rx)
        var delta = atan2((-y1 - cy1) / ry, (-x1 - cx1) / rx) - theta
        if sweep && delta < 0 { delta += 2 * .pi }
        if !sweep && delta > 0 { delta -= 2 * .pi }
        let segments = max(2, Int(ceil(abs(delta) / (.pi / 16))))
        for i in 1...segments {
            let t = theta + delta * CGFloat(i) / CGFloat(segments)
            let x = rx * cos(t), y = ry * sin(t)
            path.addLine(to: CGPoint(x: cx + cosPhi * x - sinPhi * y, y: cy + sinPhi * x + cosPhi * y))
        }
    }

    private struct Scanner {
        let chars: [Character]
        var index = 0

        init(_ chars: [Character]) { self.chars = chars }

        mutating func skip() { while index < chars.count, chars[index] == " " || chars[index] == "," { index += 1 } }

        /// The next command letter, `.some(nil)` when the next token is a number (repeat the last command), nil at the end.
        mutating func command() -> Character?? {
            skip()
            guard index < chars.count else { return nil }
            if chars[index].isLetter { index += 1; return .some(chars[index - 1]) }
            return .some(nil)
        }

        /// One number; SVG allows "1.2.3" (two numbers) and "-5-5".
        mutating func number() -> CGFloat {
            skip()
            let begin = index
            if index < chars.count, chars[index] == "-" || chars[index] == "+" { index += 1 }
            var seenDot = false
            while index < chars.count {
                if chars[index].isNumber { index += 1 } else if chars[index] == ".", !seenDot { seenDot = true; index += 1 } else { break }
            }
            return CGFloat(Double(String(chars[begin..<index])) ?? 0)
        }

        /// Arc flags are single digits and may be written without a separator ("0 0 1-5-5", "011").
        mutating func flag() -> Bool {
            skip()
            defer { index += 1 }
            return index < chars.count && chars[index] == "1"
        }
    }
}

#Preview("Glyphs") {
    HStack(spacing: Theme.Space.x12) {
        DesignIcon(glyph: .house, size: 15)
        DesignIcon(glyph: .chevronDown, size: 12)
        DesignIcon(glyph: .plus, size: 14)
        DesignIcon(glyph: .alert, size: 14).foregroundStyle(Theme.Colors.caution)
        DesignIcon(glyph: .check, size: 14).foregroundStyle(Theme.Colors.success)
        DesignIcon(glyph: .folder, size: 15).foregroundStyle(Theme.Colors.accent)
        DesignIcon(glyph: .folderPlus, size: 40).foregroundStyle(Theme.Colors.accent)
        DesignIcon(glyph: .doc, size: 14).foregroundStyle(Theme.Colors.accent)
        DesignIcon(glyph: .gear, size: 16)
        DesignIcon(glyph: .close, size: 8)
        DesignIcon(glyph: .paperclip, size: 13)
        DesignIcon(glyph: .popUp, size: 9)
        DesignIcon(glyph: .terminal, size: 16).foregroundStyle(.white).padding(7).background(Theme.Colors.label, in: RoundedRectangle(cornerRadius: Theme.Radius.field))
    }
    .foregroundStyle(Theme.Colors.secondaryLabel)
    .padding(Theme.Space.x20)
    .background(Theme.Colors.background)
}
