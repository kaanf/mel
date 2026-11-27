import Foundation

/// The board's Roadmap (V2-15): TASKS.md as phases, each with its tasks in build order.
public struct RoadmapPhase: Hashable, Sendable {
    public var name: String
    public var tasks: [SpecTask]

    /// Phases from the `##` headings, a run of tasks under one heading each. A TASKS.md without
    /// headings is grouped by priority (P1, P2, P3), tasks keeping their order within a group.
    public static func phases(_ tasks: [SpecTask]) -> [RoadmapPhase] {
        var phases: [RoadmapPhase] = []
        if tasks.contains(where: { !$0.phase.isEmpty }) {
            for task in tasks {
                if let last = phases.last, last.name == task.phase {
                    phases[phases.count - 1].tasks.append(task)
                } else {
                    phases.append(RoadmapPhase(name: task.phase.isEmpty ? "Tasks" : task.phase, tasks: [task]))
                }
            }
        } else {
            for task in tasks {
                let name = task.priority.isEmpty ? "Tasks" : task.priority
                if let index = phases.firstIndex(where: { $0.name == name }) {
                    phases[index].tasks.append(task)
                } else {
                    phases.append(RoadmapPhase(name: name, tasks: [task]))
                }
            }
            phases.sort { $0.name < $1.name }
        }
        return phases
    }
}

/// A flow of EXPERIENCE.md for the board's Flow (V2-16): its screens in order with their states,
/// and its branches. `## Flow 1 · Book a class`, `Covers:`, `1. Schedule (1.1)`, `- Class is full: Waitlist sheet (1.2)`,
/// states from the Screens and states table.
public struct ExperienceFlow: Hashable, Sendable {
    public struct Screen: Hashable, Sendable {
        public var name: String
        public var ids: [String]
        /// As written; a state starting with `!` is missing.
        public var states: [String]
    }

    public struct Branch: Hashable, Sendable {
        /// "Class is full"
        public var when: String
        public var to: String
        public var ids: [String]
    }

    public var title: String
    public var covers: [String]
    public var screens: [Screen]
    public var branches: [Branch]

    public static func parse(_ experience: [Block]) -> [ExperienceFlow] {
        var flows: [ExperienceFlow] = []
        var states: [String: [String]] = [:]
        var inFlow = false
        for block in experience {
            switch block {
            case .heading(2, let text):
                inFlow = text.hasPrefix("Flow ")
                if inFlow {
                    let title = text.split(separator: "·", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? text
                    flows.append(ExperienceFlow(title: title, covers: [], screens: [], branches: []))
                }
            case .covers(let ids) where inFlow:
                flows[flows.count - 1].covers = ids
            case .orderedItem(_, let text) where inFlow:
                let (name, ids) = nameAndIDs(text)
                flows[flows.count - 1].screens.append(Screen(name: name, ids: ids, states: []))
            case .listItem(let text) where inFlow:
                guard let colon = text.range(of: ": ") else { continue }
                let (name, ids) = nameAndIDs(String(text[colon.upperBound...]))
                flows[flows.count - 1].branches.append(Branch(when: String(text[..<colon.lowerBound]), to: name, ids: ids))
            case .table(let header, let rows) where header.first == "Screen" && header.count > 1:
                for row in rows where row.count > 1 {
                    states[row[0]] = row[1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                }
            default:
                break
            }
        }
        return flows.filter { !$0.screens.isEmpty }.map { flow in
            var flow = flow
            for index in flow.screens.indices { flow.screens[index].states = states[flow.screens[index].name] ?? [] }
            return flow
        }
    }

    /// "Schedule (1.1, 1.2)" → ("Schedule", ["1.1", "1.2"])
    private static func nameAndIDs(_ text: String) -> (String, [String]) {
        guard let open = text.lastIndex(of: "("), text.hasSuffix(")") else { return (text.trimmingCharacters(in: .whitespaces), []) }
        let ids = text[text.index(after: open)..<text.index(before: text.endIndex)].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return (text[..<open].trimmingCharacters(in: .whitespaces), ids)
    }
}
