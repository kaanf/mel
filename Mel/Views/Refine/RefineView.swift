import SwiftUI
import MelSpec

/// C1 Refine (design/v2 Native-3d-Refine): the user changed an approved file. Banner, the diff against
/// the approved text, what it affects downstream, why it changed (saved as a decision), Keep or Refine.
/// Inspector: the decisions log (the Agent tab is hidden in v0.3).
struct RefineView: View {
    let session: SpecSession
    let kind: DocKind
    @Binding var showInspector: Bool
    @State private var reason = ""
    @State private var error: String?

    private var spec: Spec { session.spec }
    private var stale: [DocKind] { spec.size.files.filter { spec.docs[$0] == .stale } }
    private var lines: [DiffLine] { DiffLine.hunks(old: session.snapshots[kind] ?? "", new: session.documents[kind] ?? "") }
    private var changes: Int { lines.split { $0.kind == .context || $0.kind == .heading }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x18) {
                banner
                section("Your change") { diff }
                if !stale.isEmpty { section("What this affects") { impact } }
                section("Why did this change?") { why }
                footer
            }
            .foregroundStyle(Theme.Colors.label)
            .frame(maxWidth: Theme.Size.refineMaxWidth)
            .padding(EdgeInsets(top: Theme.Space.x16, leading: Theme.Space.x32, bottom: Theme.Space.x40, trailing: Theme.Space.x32))
            .frame(maxWidth: .infinity)
        }
        .background(Theme.Colors.background)
        .navigationTitle(kind.fileName)
        .navigationSubtitle("Edited after approval · \(changes == 1 ? "1 change" : "\(changes) changes")")
        .toolbar {
            ToolbarItem {
                Button("Undo Change") { Task { await session.undoEdit(kind) } }
                    .buttonStyle(DesignButtonStyle(role: .secondary, height: Theme.Size.buttonToolbar, leading: Theme.Space.x14, trailing: Theme.Space.x14, text: Theme.Text.body))
                    .disabled(session.isRunning)
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem {
                Button { showInspector.toggle() } label: {
                    DesignIcon(glyph: .inspector, size: Theme.Size.settingsIcon).foregroundStyle(Theme.Colors.label)
                }
                .accessibilityLabel(showInspector ? "Hide decisions" : "Show decisions")
                .help("Show or hide the decisions")
            }
        }
        .inspector(isPresented: $showInspector) {
            DecisionsList(decisions: session.decisions, folder: spec.folder)
                .inspectorColumnWidth(min: Theme.Size.decisionsWidth, ideal: Theme.Size.decisionsWidth, max: Theme.Size.decisionsWidth)
        }
        .alert("Couldn’t Save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        } message: {
            Text(error ?? "")
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text(title).textStyle(Theme.Text.bodyBold).padding(.horizontal, Theme.Space.x4).accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private var banner: some View {
        HStack(alignment: .top, spacing: Theme.Space.x12) {
            DesignIcon(glyph: .warning, size: Theme.Size.bannerIcon)
                .foregroundStyle(Theme.Colors.warning)
                .padding(.top, Theme.Space.x1)
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                Text(stale.isEmpty ? "You changed an approved file." : "You changed an approved file. \(stale.count == 1 ? "1 file was" : "\(stale.count) files were") built on it.")
                    .textStyle(Theme.Text.bodyBold)
                Text("They are marked out of date. Refine rewrites only the affected parts, and you review each change like any other suggestion.")
                    .textStyle(Theme.Text.calloutLoose)
                    .foregroundStyle(Theme.Colors.bodyLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Theme.Space.x14)
        .padding(.horizontal, Theme.Space.x16)
        .surface(Theme.Colors.bannerFill, .banner, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    private var diff: some View {
        let lines = lines
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(lines.indices, id: \.self) { i in
                let line = lines[i]
                Text(line.text)
                    .textStyle(Theme.Text.codeDiff)
                    .foregroundStyle(line.kind.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: line.kind == .heading ? Theme.Space.x6 : Theme.Space.x4, leading: Theme.Space.x12,
                                        bottom: line.kind == .heading ? Theme.Space.x6 : i == lines.count - 1 ? Theme.Space.x8 : Theme.Space.x4, trailing: Theme.Space.x12))
                    .background(line.kind.fill)
            }
        }
        .textSelection(.enabled)
        .surface(.clear, .outlineCard, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.box))
    }

    private var impact: some View {
        VStack(spacing: 0) {
            ForEach(stale, id: \.self) { file in
                let item = session.impact?.items.first { $0.kind == file }
                HStack(spacing: Theme.Space.x10) {
                    StatusDot(style: .filled(Theme.Colors.warning))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(file.fileName).textStyle(Theme.Text.codeBold)
                        Text(item?.what ?? (session.impact == nil ? "Checking what changes here…" : "Every part that depends on the change"))
                            .textStyle(Theme.Text.callout)
                            .foregroundStyle(Theme.Colors.bodyLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let count = item?.count {
                        Text(count).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                    }
                }
                .frame(minHeight: Theme.Size.impactRow)   // CSS min-height leaves out the padding
                .padding(.vertical, Theme.Space.x8)
                .padding(.horizontal, Theme.Space.x14)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.separatorTable).frame(height: Theme.Size.hairline) }
                .accessibilityElement(children: .combine)
            }
        }
        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var why: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextEditor(text: $reason)
                .font(Theme.Text.bodyLoose.font)
                .lineHeight(.exact(points: Theme.Text.bodyLoose.lineHeight!))
                .scrollContentBackground(.hidden)
                .frame(height: Theme.Text.bodyLoose.lineHeight! * CGFloat(Theme.Size.whyLines))
                .padding(EdgeInsets(top: Theme.Space.x10, leading: Theme.Space.x14 - IdeaTextArea.inset, bottom: Theme.Space.x4, trailing: Theme.Space.x14 - IdeaTextArea.inset))
                .accessibilityLabel("Why did this change?")
            Text("Saved as decision \(Decision.nextID(after: session.decisions)), so agents and future you know why.")
                .textStyle(Theme.Text.caption)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .padding(EdgeInsets(top: 0, leading: Theme.Space.x14, bottom: Theme.Space.x10, trailing: Theme.Space.x14))
        }
        .surface(Theme.Colors.fill, .outlineFaint, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var footer: some View {
        HStack(spacing: Theme.Space.x10) {
            Text("Agents building from TASKS.md pause on out-of-date tasks until you refine or keep them.")
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Keep Them as They Are") { finish { session.keepAsIs() } }
                .buttonStyle(DesignButtonStyle(role: .secondary, leading: Theme.Space.x16, trailing: Theme.Space.x16, text: Theme.Text.body))
                .disabled(session.isRunning)
            if !stale.isEmpty {
                Button(stale.count == 1 ? "Refine 1 File" : "Refine \(stale.count) Files") { finish { await session.refine() } }
                    .buttonStyle(DesignButtonStyle(leading: Theme.Space.x18, trailing: Theme.Space.x18))
                    .disabled(session.isRunning)
            }
        }
    }

    /// Saves the reason as a decision (when there is one), then keeps or refines.
    private func finish(_ action: @escaping () async -> Void) {
        let reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            if !reason.isEmpty {
                do { try await session.saveDecision(title: "Changed \(kind.title)", reason: reason, for: kind) } catch { self.error = error.localizedDescription; return }
            }
            await action()
        }
    }
}

/// One line of C1's diff: changed lines with the heading above them and one line after.
struct DiffLine: Hashable {
    enum Kind { case heading, removed, added, context }
    let kind: Kind
    let text: String

    static func hunks(old: String, new: String) -> [DiffLine] {
        let a = old.components(separatedBy: "\n"), b = new.components(separatedBy: "\n")
        let difference = b.difference(from: a)
        var removed = Set<Int>(), inserted = Set<Int>()
        for change in difference {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): inserted.insert(offset)
            }
        }
        // Walk both texts in order: "-" old line, "+" new line, or a line both share.
        var merged: [(kind: Kind, text: String)] = []
        var i = 0, j = 0
        while i < a.count || j < b.count {
            if i < a.count, removed.contains(i) { merged.append((.removed, marked("-", a[i]))); i += 1 }
            else if j < b.count, inserted.contains(j) { merged.append((.added, marked("+", b[j]))); j += 1 }
            else { if i < a.count { merged.append((.context, a[i])) }; i += 1; j += 1 }
        }
        var lines: [DiffLine] = []
        var lastHeading: Int?
        var shown = Set<Int>()
        for (index, line) in merged.enumerated() {
            if line.kind == .context, line.text.hasPrefix("#") { lastHeading = index }
            guard line.kind != .context else { continue }
            if let h = lastHeading, !shown.contains(h) {
                shown.insert(h)
                lines.append(DiffLine(kind: .heading, text: merged[h].text))
            }
            shown.insert(index)
            lines.append(DiffLine(kind: line.kind, text: line.text))
            let next = index + 1
            if next < merged.count, merged[next].kind == .context, !merged[next].text.trimmingCharacters(in: .whitespaces).isEmpty, !shown.contains(next) {
                shown.insert(next)
                lines.append(DiffLine(kind: .context, text: merged[next].text))
            }
        }
        return lines
    }

    /// "- 1.3 WHEN …" as drawn: the marker takes the place of a list item's own dash.
    private static func marked(_ marker: String, _ line: String) -> String {
        marker + " " + (line.hasPrefix("- ") ? String(line.dropFirst(2)) : line)
    }
}

extension DiffLine.Kind {
    var color: Color {
        switch self {
        case .heading: Theme.Colors.secondaryLabel
        case .removed: Theme.Colors.diffRemovedText
        case .added: Theme.Colors.diffAddedText
        case .context: Theme.Colors.label
        }
    }

    var fill: Color {
        switch self {
        case .heading: Theme.Colors.fill
        case .removed: Theme.Colors.diffRemovedFill
        case .added: Theme.Colors.diffAddedFill
        case .context: .clear
        }
    }
}

/// C1 inspector: DECISIONS.md, newest first; the newest is highlighted, replaced ones are faded.
private struct DecisionsList: View {
    let decisions: [Decision]
    let folder: URL

    private var sorted: [Decision] { decisions.sorted { (Int($0.id.dropFirst(2)) ?? 0) > (Int($1.id.dropFirst(2)) ?? 0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x10) {
                Text("Every answer and change, with the reason. Stored in specs/\(folder.lastPathComponent)/DECISIONS.md.")
                    .textStyle(Theme.Text.caption)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                let sorted = sorted
                ForEach(sorted.indices, id: \.self) { i in
                    card(sorted[i], isNewest: i == 0)
                }
            }
            .foregroundStyle(Theme.Colors.label)
            .padding(EdgeInsets(top: Theme.Space.x4, leading: Theme.Space.x16, bottom: Theme.Space.x16, trailing: Theme.Space.x16))
        }
        .background(Theme.Colors.background)
    }

    private func card(_ decision: Decision, isNewest: Bool) -> some View {
        let replacedBy = decision.replacedBy(in: decisions)
        return VStack(alignment: .leading, spacing: Theme.Space.x3) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x6) {
                Text(decision.id).textStyle(Theme.Text.codeCaption).foregroundStyle(Theme.Colors.secondaryLabel)
                Text(decision.title).textStyle(Theme.Text.bodyBold).frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(decision.reason).textStyle(Theme.Text.calloutLoose).foregroundStyle(Theme.Colors.bodyLabel)
            Text(meta(decision, replacedBy: replacedBy)).textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
        }
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(replacedBy != nil ? .clear : isNewest ? Theme.Colors.accentTint : Theme.Colors.fill,
                 replacedBy != nil ? .outlineReplaced : isNewest ? .accentBox : .init(),
                 in: RoundedRectangle(cornerRadius: Theme.Radius.box))
        .opacity(replacedBy != nil ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }

    /// "You · just now · replaces D-03 · affects 1.3", or "Replaced by D-07".
    private func meta(_ d: Decision, replacedBy: String?) -> String {
        if let replacedBy { return "Replaced by \(replacedBy)" }
        var parts = [d.source, d.date.formatted(.relative(presentation: .named))]
        if let replaces = d.replaces { parts.append("replaces \(replaces)") }
        if !d.affects.isEmpty { parts.append("affects \(d.affects.joined(separator: ", "))") }
        return parts.joined(separator: " · ")
    }
}

#Preview("Refine") {
    @Previewable @State var showInspector = true
    NavigationStack {
        RefineView(session: PreviewData.editedSession, kind: .requirements, showInspector: $showInspector)
    }
    .frame(width: 1048, height: 800)
}
