import SwiftUI
import MelSpec

/// B6 Analyze (design/v2 Native-3c-Analyze): all approved files checked against each other.
/// Stat tiles, issues with two actions each, the coverage matrix; Hand Off Anyway or Fix n Issues.
struct AnalyzeView: View {
    let session: SpecSession

    private var spec: Spec { session.spec }
    private var result: AnalyzeResult? { spec.analysis }

    /// "All 5 files checked against each other · 12:31"
    private var subtitle: String {
        let files = spec.size.files.count
        if isRunning { return "Checking \(files) files" }
        let checked = "All \(files) files checked against each other"
        return result.map { "\(checked) · \($0.analyzedAt.formatted(date: .omitted, time: .shortened))" } ?? checked
    }
    private var isRunning: Bool { spec.analyze == .running }
    private var issues: [AnalyzeResult.Issue] { result?.issues ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x20) {
                if isRunning {
                    HStack(spacing: Theme.Space.x8) {
                        StatusDot(style: .running)
                        Text("Claude Code is checking all \(spec.size.files.count) files against each other…")
                            .textStyle(Theme.Text.callout)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                    }
                    .padding(.horizontal, Theme.Space.x4)
                } else if let error = session.lastError {
                    VStack(alignment: .leading, spacing: Theme.Space.x8) {
                        Text("Analyze couldn’t finish").textStyle(Theme.Text.bodyBold)
                        Text(error).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                        Button("Try Again") { Task { await session.analyze() } }
                            .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.button, leading: Theme.Space.x16, trailing: Theme.Space.x16, text: Theme.Text.body))
                    }
                    .padding(Theme.Space.x12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
                }
                if let result {
                    stats(result.stats)
                    if !result.issues.isEmpty { issueList(result.issues) }
                    if !result.coverage.isEmpty { coverage(result.coverage) }
                }
            }
            .foregroundStyle(Theme.Colors.label)
            .frame(maxWidth: Theme.Size.analyzeMaxWidth)
            .padding(EdgeInsets(top: Theme.Space.x16, leading: Theme.Space.x32, bottom: Theme.Space.x40, trailing: Theme.Space.x32))
            .frame(maxWidth: .infinity)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Analyze")
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItem {
                Button("Hand Off Anyway") { session.handOffAnyway() }
                    .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.buttonToolbar, leading: Theme.Space.x14, trailing: Theme.Space.x14, text: Theme.Text.body))
                    .disabled(isRunning || result == nil)
            }
            .sharedBackgroundVisibility(.hidden)
            if !issues.isEmpty {
                ToolbarItem {
                    Button(issues.count == 1 ? "Fix 1 Issue with Claude Code" : "Fix \(issues.count) Issues with Claude Code") { Task { await session.fixIssues() } }
                        .buttonStyle(DesignButtonStyle(height: Theme.Size.buttonToolbar, leading: Theme.Space.x16, trailing: Theme.Space.x16))
                        .disabled(isRunning || session.isRunning)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
    }

    private func stats(_ stats: [AnalyzeResult.Stat]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.Size.statTileMin), spacing: Theme.Space.x10)], spacing: Theme.Space.x10) {
            ForEach(stats, id: \.self) { stat in
                VStack(alignment: .leading, spacing: Theme.Space.x2) {
                    Text(stat.value).textStyle(Theme.Text.title3).monospacedDigit()
                    Text(stat.label).textStyle(Theme.Text.callout).foregroundStyle(Theme.Colors.bodyLabel)
                }
                .padding(.vertical, Theme.Space.x12)
                .padding(.horizontal, Theme.Space.x14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func issueList(_ issues: [AnalyzeResult.Issue]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("Issues").textStyle(Theme.Text.bodyBold).padding(.horizontal, Theme.Space.x4).accessibilityAddTraits(.isHeader)
            ForEach(issues) { issue in
                // Dot at the top, actions centered vertically, as drawn.
                HStack(spacing: Theme.Space.x12) {
                    StatusDot(style: .filled(Self.serious(issue.kind) ? Theme.Colors.caution : Theme.Colors.warning))
                        .padding(.top, Theme.Space.x4)
                        .frame(maxHeight: .infinity, alignment: .top)
                    VStack(alignment: .leading, spacing: Theme.Space.x4) {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                            Text(Self.word(issue.kind)).textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.secondaryLabel)
                            Text(issue.location).textStyle(Theme.Text.codeCaption).foregroundStyle(Theme.Colors.secondaryLabel)
                        }
                        Text(issue.text).textStyle(Theme.Text.bodyLoose)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: Theme.Space.x6) {
                        ForEach(issue.actions.indices, id: \.self) { i in
                            Button(issue.actions[i].label) { Task { await session.apply(issue.actions[i]) } }
                                .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.buttonMini, leading: Theme.Space.x10, trailing: Theme.Space.x10,
                                                               text: i == issue.actions.count - 1 ? Theme.Text.calloutMedium : Theme.Text.callout))
                                .disabled(isRunning || session.isRunning)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, Theme.Space.x12)
                .padding(.horizontal, Theme.Space.x14)
                .surface(.clear, .outlineList, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                .accessibilityElement(children: .contain)
            }
        }
    }

    private func coverage(_ rows: [AnalyzeResult.CoverageRow]) -> some View {
        let hasScreens = rows.contains { $0.screen != nil }
        let columns = (hasScreens ? ["Screen"] : []) + ["Architecture", "Task", "Test"]
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                Text("Coverage").textStyle(Theme.Text.bodyBold).frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
                Text("Each requirement traced through every file").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
            }
            .padding(.horizontal, Theme.Space.x4)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("ID").frame(width: Theme.Size.coverageID, alignment: .leading)
                    Text("Requirement").frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(columns, id: \.self) { Text($0).frame(width: Theme.Size.coverageCell) }
                }
                .textStyle(Theme.Text.captionBold)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .padding(.vertical, Theme.Space.x8)
                .padding(.horizontal, Theme.Space.x14)
                .background(Theme.Colors.fill)
                ForEach(rows) { row in
                    let marks = (hasScreens ? [row.screen] : []) + [row.architecture, row.task, row.test]
                    HStack(spacing: 0) {
                        Text(row.id).textStyle(Theme.Text.code).foregroundStyle(Theme.Colors.secondaryLabel).frame(width: Theme.Size.coverageID, alignment: .leading)
                        Text(row.text).textStyle(Theme.Text.body).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(marks.indices, id: \.self) { i in
                            Text(Self.word(marks[i]))
                                .textStyle(Theme.Text.calloutMedium)
                                .foregroundStyle(marks[i] == .covered ? Theme.Colors.success : Theme.Colors.cautionText)
                                .frame(width: Theme.Size.coverageCell)
                                .accessibilityLabel("\(columns[i]): \(marks[i] == .covered ? "Covered" : Self.word(marks[i]))")
                        }
                    }
                    .padding(.vertical, Theme.Space.x7)
                    .padding(.horizontal, Theme.Space.x14)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.separatorTable).frame(height: Theme.Size.hairline) }
                    .accessibilityElement(children: .combine)
                }
            }
            .surface(.clear, .outlineCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    private static func serious(_ kind: AnalyzeResult.IssueKind) -> Bool { kind == .contradiction || kind == .noTask }

    private static func word(_ kind: AnalyzeResult.IssueKind) -> String {
        switch kind {
        case .contradiction: "Contradiction"
        case .noTask: "No task"
        case .qualityNotCovered: "Quality not covered"
        case .scopeCreep: "Possible scope creep"
        }
    }

    private static func word(_ mark: AnalyzeResult.Mark?) -> String {
        switch mark {
        case .covered?: "✓"
        case .missing?: "Missing"
        case .conflict?: "Conflict"
        case nil: ""
        }
    }
}

#Preview("Issues") {
    NavigationStack {
        AnalyzeView(session: PreviewData.session(PreviewData.analyzeIssues))
    }
    .frame(width: 1048, height: 800)
}

#Preview("Running") {
    NavigationStack {
        AnalyzeView(session: PreviewData.session(PreviewData.analyzeRunning, isRunning: true))
    }
    .frame(width: 1048, height: 600)
}
