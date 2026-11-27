import SwiftUI
import UniformTypeIdentifiers
import MelSpec

/// Tell Mel (V2-2, under the center): one request at a time against the current files, with the
/// result line (V2-4) or the unplaced offer (V2-7) above the box. On Build it fills the right
/// panel, stacked for its width, carries the task a request came from and shows the working line itself.
struct BoardTell: View {
    let session: SpecSession
    var building = false
    /// Build: "Tell Mel about this" on a task card puts the task here.
    var task: Binding<SpecTask?> = .constant(nil)

    @State private var text = ""
    @State private var files: [URL] = []
    @State private var isAttaching = false
    /// Build: the request just sent, shown above like a chat message; back in the box if the run fails.
    @State private var sent: (text: String, task: SpecTask?)?
    @FocusState private var isFocused: Bool

    private var spec: Spec { session.spec }
    private var request: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !request.isEmpty && !session.isRunning && spec.unplacedChange == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            if building, let sent { message(sent.text, task: sent.task) }
            if building, !session.isRunning, let error = session.lastError { errorLine(error) }
            if let unplaced = spec.unplacedChange {
                if building, session.isRunning { working(rewriting: unplaced.files.first) } else { unplacedBanner(unplaced) }
            } else if building, session.isRunning {
                working(rewriting: nil)
            } else if let change = session.lastChange {
                result(change)
            }
            // Build: the box sits at the bottom of the panel, like a chat's.
            if building { Spacer(minLength: 0) }
            box
        }
        .frame(maxHeight: building ? .infinity : nil, alignment: .top)
        .onChange(of: task.wrappedValue) { _, new in if new != nil { isFocused = true } }
        .fileImporter(isPresented: $isAttaching, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { files += urls.filter { !files.contains($0) } }
        }
    }

    @ViewBuilder
    private func result(_ change: SpecSession.ChangeResult) -> some View {
        if building {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.x8) {
                    DesignIcon(glyph: .check, size: Theme.Size.checkIcon, weight: 2.2).foregroundStyle(Theme.Colors.success)
                    Text(change.line).textStyle(Theme.Text.bodyBold).fixedSize(horizontal: false, vertical: true)
                }
                Text(sub(change))
                    .textStyle(Theme.Text.captionLoose)
                    .foregroundStyle(Theme.Colors.bodyLabel)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Undo") { session.undoChange() }
                    .buttonStyle(BoardPillStyle())
                    .disabled(session.isRunning)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Space.x10)
            .padding(.horizontal, Theme.Space.x12)
            .surface(Theme.Colors.resultFill, .result, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .accessibilityElement(children: .contain)
        } else {
            resultRow(change)
        }
    }

    private func resultRow(_ change: SpecSession.ChangeResult) -> some View {
        HStack(spacing: Theme.Space.x10) {
            DesignIcon(glyph: .check, size: Theme.Size.checkIcon, weight: 2.2).foregroundStyle(Theme.Colors.success)
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                Text(change.line).textStyle(Theme.Text.bodyBold)
                Text(sub(change))
                    .textStyle(Theme.Text.captionLoose)
                    .foregroundStyle(Theme.Colors.bodyLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Undo") { session.undoChange() }
                .buttonStyle(BoardPillStyle())
                .disabled(session.isRunning)
            Button { session.dismissChange() } label: {
                DesignIcon(glyph: .close, size: Theme.Size.readyCheck, weight: 2)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .frame(width: Theme.Size.buttonMini, height: Theme.Size.buttonMini)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .surface(Theme.Colors.resultFill, .result, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .contain)
    }

    private func sub(_ change: SpecSession.ChangeResult) -> String {
        let tokens = change.tokens > 0 ? " \(TokenStep.text(change.tokens)) tokens." : ""
        guard building else { return (change.passages.isEmpty ? "" : "Highlighted in the files. ") + "Saved to DECISIONS.md." + tokens }
        return taskNote(change) + "Saved to DECISIONS.md with your words." + tokens
    }

    /// V2-13: "3 tasks updated, 1 added in step 2. Task 1 changed after it was done: …"
    private func taskNote(_ change: SpecSession.ChangeResult) -> String {
        var parts: [String] = []
        if !change.updatedTasks.isEmpty { parts.append("\(change.updatedTasks.count) \(change.updatedTasks.count == 1 ? "task" : "tasks") updated") }
        if !change.newTasks.isEmpty {
            let steps = Set(change.newTasks.compactMap { number in session.steps.firstIndex { $0.tasks.contains { $0.number == number } } }).sorted()
            parts.append("\(change.newTasks.count) added" + (steps.isEmpty ? "" : " in step " + steps.map { String($0 + 1) }.joined(separator: " and ")))
        }
        var note = parts.isEmpty ? "" : parts.joined(separator: ", ").capitalizedFirst + ". "
        let doneChanged = session.tasks.filter { task in
            guard change.updatedTasks.contains(task.number), case .done = session.status(of: task) else { return false }
            return session.promptChanged(task)
        }.map(\.number)
        if !doneChanged.isEmpty {
            let names = doneChanged.map(String.init).joined(separator: " and ")
            note += "\(doneChanged.count == 1 ? "Task" : "Tasks") \(names) changed after \(doneChanged.count == 1 ? "it was" : "they were") done: reopen \(doneChanged.count == 1 ? "it" : "them") if you want the change built. "
        }
        return note
    }

    /// Build: what the user sent, right-aligned like a chat message.
    private func message(_ text: String, task: SpecTask?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x4) {
            if let task {
                Text("Task \(task.number) · \(task.title.capitalizedFirst)").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.likely).lineLimit(1)
            }
            Text(text).textStyle(Theme.Text.calloutLoose).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }
        .padding(.vertical, Theme.Space.x8)
        .padding(.horizontal, Theme.Space.x10)
        .background(Theme.Colors.changedFill, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, Theme.Space.x24)
    }

    private func errorLine(_ error: String) -> some View {
        Text(error + " Nothing was changed; your request is back in the box.")
            .textStyle(Theme.Text.captionLoose)
            .foregroundStyle(Theme.Colors.cautionText)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// V2-12: the board's working line, where the user is looking on Build.
    private func working(rewriting: DocKind?) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.x8) {
            StatusDot(style: .ring(Theme.Colors.accent)).padding(.top, Theme.Space.x4)
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                if let rewriting {
                    Text(rewriting.fileName).textStyle(Theme.Text.codeBold)
                }
                Text(rewriting == nil ? "Changing the passages your request touches" : "Rewriting the whole file, as you chose")
                    .textStyle(Theme.Text.callout)
                    .foregroundStyle(Theme.Colors.bodyLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Stop") { Task { await session.stop() } }
                .buttonStyle(DesignLinkStyle())
                .padding(.horizontal, Theme.Space.x4)
                .help("Stops Mel. Nothing changes.")
        }
        .padding(.vertical, Theme.Space.x8)
        .padding(.horizontal, Theme.Space.x12)
        .surface(Theme.Colors.accentTint, .editBanner, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .contain)
    }

    /// V2-11: the task a request came from.
    private func chip(_ task: SpecTask) -> some View {
        HStack(spacing: Theme.Space.x6) {
            Text("Task \(task.number) · \(task.title.capitalizedFirst)").textStyle(Theme.Text.caption).lineLimit(1)
            Button { self.task.wrappedValue = nil } label: {
                DesignIcon(glyph: .close, size: Theme.Size.removeIcon, weight: 2.4)
                    .frame(width: Theme.Size.removeButton, height: Theme.Size.removeButton)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove task \(task.number)")
        }
        .foregroundStyle(Theme.Colors.likely)
        .padding(.leading, Theme.Space.x8)
        .padding(.trailing, Theme.Space.x4)
        .frame(height: Theme.Size.buttonMini)
        .background(Theme.Colors.changedFill, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
    }

    /// V2-7: nothing was changed. A whole-file rewrite only ever starts from this button.
    private func unplacedBanner(_ unplaced: UnplacedChange) -> some View {
        let file = unplaced.files.first
        let cost = file.flatMap { spec.tokens?[TokenStep(file: $0)] }
        return VStack(alignment: .leading, spacing: Theme.Space.x8) {
            Text("Mel couldn’t find where this goes in \(file?.fileName ?? "the files").")
                .textStyle(Theme.Text.bodyBold)
                .foregroundStyle(Theme.Colors.bannerTitle)
            Text((unplaced.answers ? "Your answers don’t" : "“\(unplaced.request)” doesn’t") + " fit a single passage there. Nothing was changed.")
                .textStyle(Theme.Text.calloutLoose)
                .foregroundStyle(Theme.Colors.bodyLabel)
            FlowLayout(spacing: Theme.Space.x8) {
                Button { Task { await session.rewriteUnplaced() } } label: {
                    HStack(spacing: Theme.Space.x6) {
                        Text("Rewrite \(file?.fileName ?? "")")
                        if let cost {
                            Text("about \(TokenStep.text(cost)) tokens").textStyle(Theme.Text.caption).foregroundStyle(Theme.Colors.secondaryLabel)
                        }
                    }
                }
                .buttonStyle(BoardPillStyle())
                Button("Cancel") {
                    Task {
                        text = await session.cancelUnplaced()
                        sent = nil
                    }
                }
                    .buttonStyle(BoardPillStyle())
            }
            .disabled(session.isRunning)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Space.x12)
        .padding(.horizontal, Theme.Space.x14)
        .surface(Theme.Colors.bannerFill, .banner, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var box: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x8) {
            if !building {
                Text("Tell Mel").textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.bodyLabel)
            }
            if let task = task.wrappedValue { chip(task) }
            TextField(building ? "What did you find while building?" : "Tell Mel what to change, add or remove…", text: $text, axis: .vertical)
                .lineLimit(building ? Theme.Size.buildTellLines...12 : Theme.Size.tellLines...8)
                .textFieldStyle(.plain)
                .textStyle(Theme.Text.bodyLoose)
                .focused($isFocused)
                .accessibilityLabel("Tell Mel")
            if !files.isEmpty {
                FlowLayout(spacing: Theme.Space.x6) {
                    ForEach(files, id: \.self) { file in
                        HStack(spacing: Theme.Space.x6) {
                            Text(file.lastPathComponent).textStyle(Theme.Text.caption)
                            Button { files.removeAll { $0 == file } } label: {
                                DesignIcon(glyph: .close, size: Theme.Size.removeIcon, weight: 2.4)
                                    .foregroundStyle(Theme.Colors.secondaryLabel)
                                    .frame(width: Theme.Size.removeButton, height: Theme.Size.removeButton)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(file.lastPathComponent)")
                        }
                        .padding(.leading, Theme.Space.x8)
                        .padding(.trailing, Theme.Space.x4)
                        .frame(height: Theme.Size.buttonMini)
                        .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.code))
                    }
                }
            }
            if building {
                Text(hint)
                    .textStyle(Theme.Text.captionLoose)
                    .foregroundStyle(Theme.Colors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Space.x8) {
                    attachButton
                    Spacer(minLength: 0)
                    sendButton
                }
            } else {
                HStack(spacing: Theme.Space.x8) {
                    attachButton
                    Text(hint)
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    sendButton
                }
            }
        }
        .padding(.vertical, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x12)
        .surface(Theme.Colors.background, .storyCard, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var hint: String {
        building ? "Mel edits only the passages it touches. Prompts you already copied keep running; changed ones are marked." : "One request at a time. Mel edits only the passages it touches and logs why in DECISIONS.md."
    }

    private var attachButton: some View {
        Button { isAttaching = true } label: {
            HStack(spacing: Theme.Space.x5) {
                DesignIcon(glyph: .attach, size: Theme.Size.smallCheck)
                Text("Attach")
            }
        }
        .buttonStyle(BoardPillStyle(kind: .quiet, height: Theme.Size.buttonSmall, padding: Theme.Space.x10))
    }

    private var sendButton: some View {
        Button(building && session.isRunning ? "Changing…" : "Send") {
            let (request, attached, about) = (self.request, files, task.wrappedValue)
            if building {
                // Chat-like: the request leaves the box at once and comes back only if the run fails.
                sent = (request, about)
                text = ""
                files = []
                task.wrappedValue = nil
                Task {
                    guard await !session.tell(request, files: attached, task: about) else { return }
                    sent = nil
                    if text.isEmpty {
                        text = request
                        files = attached
                        task.wrappedValue = about
                    }
                }
                return
            }
            let sent = request
            Task {
                // The request stays in the box until the run has finished.
                if await session.tell(sent, files: attached, task: about), text.trimmingCharacters(in: .whitespacesAndNewlines) == sent {
                    text = ""
                    files = []
                    if task.wrappedValue == about { task.wrappedValue = nil }
                }
            }
        }
        .buttonStyle(BoardPillStyle(kind: .accent, padding: Theme.Space.x14))
        .disabled(!canSend)
        .keyboardShortcut(.return, modifiers: .command)
    }
}
