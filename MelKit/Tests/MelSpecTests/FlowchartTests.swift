import Testing
@testable import MelSpec

struct FlowchartTests {
    /// OQ #46: the subset Mel draws, marks, chains and edge labels; layers follow the edges.
    @Test func flowchartSubsetParsesAndLayers() throws {
        let chart = try #require(Flowchart.parse("""
            flowchart LR
              S[Schedule screen] --> VM(ScheduleViewModel):::changed -->|reads| R[ClassRepository]
              R -.-> C((Local cache));
              P{Profile} -- opens --> T[TeacherRepository]
              class T added
              %% a comment
              subgraph Data
              end
            """))
        #expect(chart.direction == .right)
        #expect(chart.nodes.map(\.label) == ["Schedule screen", "ScheduleViewModel", "ClassRepository", "Local cache", "Profile", "TeacherRepository"])
        #expect(chart.nodes.first { $0.id == "VM" }?.mark == .changed)
        #expect(chart.nodes.first { $0.id == "T" }?.mark == .added)
        #expect(chart.edges.map(\.label) == [nil, "reads", nil, "opens"])
        #expect(chart.edges[2].dashed)
        #expect(chart.layers == [["S", "P"], ["VM", "T"], ["R"], ["C"]])
    }

    /// Anything outside the subset is shown as code; a cycle still lays out.
    @Test func unknownSyntaxFallsBackAndCyclesEnd() {
        #expect(Flowchart.parse("sequenceDiagram\n  A->>B: hi") == nil)
        #expect(Flowchart.parse("graph TD\n  A>flag] --> B") == nil)
        #expect(Flowchart.parse("graph TD\n  A --> B\n  B --> A")?.layers.flatMap { $0 }.count == 2)
    }

    @Test func mermaidFenceIsADiagramBlock() {
        #expect(MarkdownParser.blocks("```mermaid\ngraph TD\n  A --> B\n```") == [.diagram("graph TD\n  A --> B")])
        #expect(MarkdownParser.blocks("```swift\nlet a = 1\n```") == [.code("let a = 1")])
    }
}
