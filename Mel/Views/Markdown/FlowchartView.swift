import SwiftUI
import MelSpec

/// V2-33: a ```mermaid flowchart drawn in the Formatted view, in layers (OQ #46). What the spec changes
/// is blue, what it adds green; edges are straight with an arrowhead. Wider than the column: it scrolls.
struct FlowchartView: View {
    let chart: Flowchart

    private static let node = CGSize(width: 150, height: 44)
    private static let gapMain: CGFloat = 56
    private static let gapCross: CGFloat = 20

    private struct Placed { var center: CGPoint }

    private var layout: (nodes: [String: CGPoint], size: CGSize) {
        let layers = chart.layers
        let widest = layers.map(\.count).max() ?? 1
        let (w, h) = (Self.node.width, Self.node.height)
        var centers: [String: CGPoint] = [:]
        for (r, layer) in layers.enumerated() {
            let offset = CGFloat(widest - layer.count) / 2
            for (i, id) in layer.enumerated() {
                let main = CGFloat(r) * ((chart.direction == .right ? w : h) + Self.gapMain) + (chart.direction == .right ? w : h) / 2
                let cross = (offset + CGFloat(i)) * ((chart.direction == .right ? h : w) + Self.gapCross) + (chart.direction == .right ? h : w) / 2
                centers[id] = chart.direction == .right ? CGPoint(x: main, y: cross) : CGPoint(x: cross, y: main)
            }
        }
        let mainLength = CGFloat(layers.count) * ((chart.direction == .right ? w : h) + Self.gapMain) - Self.gapMain
        let crossLength = CGFloat(widest) * ((chart.direction == .right ? h : w) + Self.gapCross) - Self.gapCross
        return (centers, chart.direction == .right ? CGSize(width: mainLength, height: crossLength) : CGSize(width: crossLength, height: mainLength))
    }

    var body: some View {
        let (centers, size) = layout
        ScrollView(.horizontal) {
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for edge in chart.edges {
                        guard let a = centers[edge.from], let b = centers[edge.to], edge.from != edge.to else { continue }
                        let start = Self.border(from: a, toward: b), end = Self.border(from: b, toward: a)
                        var line = Path()
                        line.move(to: start)
                        line.addLine(to: end)
                        context.stroke(line, with: .color(Theme.Colors.emptyGroup), style: StrokeStyle(lineWidth: 1.3, dash: edge.dashed ? [4, 3] : []))
                        context.fill(Self.arrow(at: end, from: start), with: .color(Theme.Colors.emptyGroup))
                        if let label = edge.label, !label.isEmpty {
                            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 - 8)
                            context.draw(Text(label).font(Theme.Text.diagramCaption.font).foregroundStyle(Theme.Colors.secondaryLabel), at: mid)
                        }
                    }
                }
                .frame(width: size.width, height: size.height)
                ForEach(chart.nodes, id: \.id) { node in
                    if let center = centers[node.id] { box(node).position(center) }
                }
            }
            .frame(width: size.width, height: size.height)
            .padding(Theme.Space.x16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .surface(Theme.Colors.fillSubtle, .outline, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func box(_ node: Flowchart.Node) -> some View {
        let (fill, ring, ink): (Color, Color, Color) = switch node.mark {
        case .changed: (Theme.Colors.accentTint, Theme.Colors.accent, Theme.Colors.likely)
        case .added: (Theme.Colors.keepFill, Theme.Colors.success, Theme.Colors.addedSign)
        case .plain: (Theme.Colors.background, Theme.Colors.radioRing, Theme.Colors.label)
        }
        return VStack(spacing: 1) {
            Text(node.label).font(.system(size: 12, weight: node.mark == .plain ? .regular : .semibold))
                .lineLimit(2).minimumScaleFactor(0.8).multilineTextAlignment(.center)
            if node.mark != .plain {
                Text(node.mark == .added ? "new" : "changed").font(.system(size: 10))
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, Theme.Space.x8)
        .frame(width: Self.node.width, height: Self.node.height)
        .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
        .overlay { RoundedRectangle(cornerRadius: Theme.Radius.box).strokeBorder(ring, lineWidth: 1) }
    }

    /// Where the line from `center` toward `target` leaves the node's box.
    private static func border(from center: CGPoint, toward target: CGPoint) -> CGPoint {
        let (dx, dy) = (target.x - center.x, target.y - center.y)
        guard dx != 0 || dy != 0 else { return center }
        let scale = min(abs(dx) > 0 ? (node.width / 2) / abs(dx) : .infinity, abs(dy) > 0 ? (node.height / 2) / abs(dy) : .infinity)
        return CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)
    }

    private static func arrow(at tip: CGPoint, from start: CGPoint) -> Path {
        let angle = atan2(tip.y - start.y, tip.x - start.x)
        let (length, spread): (CGFloat, CGFloat) = (7, 0.45)
        return Path { p in
            p.move(to: tip)
            p.addLine(to: CGPoint(x: tip.x - length * cos(angle - spread), y: tip.y - length * sin(angle - spread)))
            p.addLine(to: CGPoint(x: tip.x - length * cos(angle + spread), y: tip.y - length * sin(angle + spread)))
            p.closeSubpath()
        }
    }

    /// "Diagram: Schedule screen to ScheduleViewModel (changed), …"
    private var accessibilityText: String {
        let name = { (id: String) -> String in
            guard let node = chart.nodes.first(where: { $0.id == id }) else { return id }
            return node.label + (node.mark == .plain ? "" : " (\(node.mark.rawValue))")
        }
        return "Diagram: " + chart.edges.map { "\(name($0.from)) to \(name($0.to))" + ($0.label.map { ", \($0)" } ?? "") }.joined(separator: "; ")
    }
}

#Preview("V2-33 Diagram") {
    let chart = Flowchart.parse("""
        flowchart LR
          S[Schedule screen] --> VM[ScheduleViewModel]:::changed
          VM --> R[ClassRepository]
          R --> API[GET /classes]
          R --> C[Local cache]
          P[Teacher profile] --> T[TeacherRepository]:::added
          T --> TA[GET /teachers]
        """)!
    return FlowchartView(chart: chart).padding().frame(width: 720)
}
