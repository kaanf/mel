import Foundation

/// A ```mermaid flowchart in a spec file (V2-33, OQ #46): the subset Mel draws itself. `flowchart` or
/// `graph` with TD / TB / LR, nodes `A[label]` `A(label)` `A{label}` `A((label))`, edges `-->` `---`
/// `-.->` `==>` with `|label|` or `-- label -->`, chains, and `:::changed` / `:::added` (or
/// `class A changed`) for what the spec changes and adds. Anything else: nil, and the code is shown.
public struct Flowchart: Hashable, Sendable {
    public enum Direction: Hashable, Sendable { case down, right }
    public enum Mark: String, Hashable, Sendable { case plain, changed, added }

    public struct Node: Hashable, Sendable {
        public var id: String
        public var label: String
        public var mark: Mark
    }

    public struct Edge: Hashable, Sendable {
        public var from: String
        public var to: String
        public var label: String?
        public var dashed: Bool
    }

    public var direction: Direction
    public var nodes: [Node]
    public var edges: [Edge]

    public static func parse(_ text: String) -> Flowchart? {
        var lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("%%") }
        guard let header = lines.first?.split(separator: " "), ["flowchart", "graph"].contains(header.first ?? "") else { return nil }
        let direction: Direction = header.count > 1 && ["LR", "RL"].contains(header[1]) ? .right : .down
        lines.removeFirst()
        var chart = Flowchart(direction: direction, nodes: [], edges: [])
        for raw in lines {
            let line = raw.hasSuffix(";") ? String(raw.dropLast()) : raw
            let word = line.split(separator: " ").first.map(String.init) ?? ""
            if ["subgraph", "end", "classDef", "style", "linkStyle", "click", "direction"].contains(word) { continue }
            if word == "class" {
                let parts = line.split(separator: " ")
                guard parts.count == 3, let mark = Mark(rawValue: String(parts[2])) else { continue }
                for id in parts[1].split(separator: ",") { chart.mark(String(id), mark) }
                continue
            }
            guard chart.statement(line) else { return nil }
        }
        return chart.nodes.isEmpty ? nil : chart
    }

    private mutating func mark(_ id: String, _ mark: Mark) {
        if let i = nodes.firstIndex(where: { $0.id == id }) { nodes[i].mark = mark }
    }

    /// One line: a node, or nodes joined by edges.
    private mutating func statement(_ line: String) -> Bool {
        var rest = Substring(line)
        guard var from = node(&rest) else { return false }
        while true {
            rest = rest.drop { $0 == " " }
            if rest.isEmpty { return true }
            guard let (dashed, label) = edge(&rest) else { return false }
            rest = rest.drop { $0 == " " }
            guard let to = node(&rest) else { return false }
            edges.append(Edge(from: from, to: to, label: label, dashed: dashed))
            from = to
        }
    }

    /// `A`, `A[label]`, `A(label)`, `A{label}`, `A((label))`, `A[[label]]`, each optionally `:::mark`.
    private mutating func node(_ rest: inout Substring) -> String? {
        let id = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        guard !id.isEmpty else { return nil }
        rest = rest.dropFirst(id.count)
        var label: String?
        let closers: [Character: Character] = ["[": "]", "(": ")", "{": "}"]
        if let open = rest.first, let close = closers[open] {
            var inner = rest.dropFirst()
            var depth = 1
            while inner.first == open { inner = inner.dropFirst(); depth += 1 }
            guard let end = inner.firstIndex(of: close) else { return nil }
            label = String(inner[..<end]).trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            rest = inner[end...].dropFirst(depth)
        }
        var mark = Mark.plain
        if rest.hasPrefix(":::") {
            let name = rest.dropFirst(3).prefix { $0.isLetter }
            mark = Mark(rawValue: String(name)) ?? .plain
            rest = rest.dropFirst(3 + name.count)
        }
        let key = String(id)
        if let i = nodes.firstIndex(where: { $0.id == key }) {
            if let label { nodes[i].label = label }
            if mark != .plain { nodes[i].mark = mark }
        } else {
            nodes.append(Node(id: key, label: label ?? key, mark: mark))
        }
        return key
    }

    /// `-->`, `---`, `-.->`, `==>`, then `|label|`; or `-- label -->`.
    private func edge(_ rest: inout Substring) -> (dashed: Bool, label: String?)? {
        for op in ["-.->", "-.-", "==>", "-->", "---"] where rest.hasPrefix(op) {
            rest = rest.dropFirst(op.count).drop { $0 == " " }
            var label: String?
            if rest.first == "|", let end = rest.dropFirst().firstIndex(of: "|") {
                label = String(rest[rest.index(after: rest.startIndex)..<end]).trimmingCharacters(in: .whitespaces)
                rest = rest[end...].dropFirst()
            }
            return (op.contains("."), label)
        }
        if rest.hasPrefix("-- "), let end = rest.range(of: " -->") {
            let label = rest[rest.index(rest.startIndex, offsetBy: 3)..<end.lowerBound].trimmingCharacters(in: .whitespaces)
            rest = rest[end.upperBound...]
            return (false, label)
        }
        return nil
    }

    /// Layers for drawing: each node one step past the furthest node that points to it (a cycle stops
    /// growing after one round per node); within a layer, the order the nodes first appear.
    public var layers: [[String]] {
        var rank = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, 0) })
        for _ in nodes {
            var moved = false
            for edge in edges where edge.from != edge.to {
                let next = (rank[edge.from] ?? 0) + 1
                if next > rank[edge.to] ?? 0, next < nodes.count { rank[edge.to] = next; moved = true }
            }
            if !moved { break }
        }
        let count = (rank.values.max() ?? 0) + 1
        return (0..<count).map { r in nodes.map(\.id).filter { rank[$0] == r } }.filter { !$0.isEmpty }
    }
}
