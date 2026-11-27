import SwiftUI
import MelSpec

/// A spec's token use (FLOW.md › V2 "Token use is visible"): the total, and the split by step in
/// a popover. Sits in the board's header.
struct TokenReadout: View {
    let spec: Spec
    @State private var showsSteps = false

    var body: some View {
        Button { showsSteps.toggle() } label: {
            Text("\(TokenStep.text(spec.tokenTotal)) tokens")
                .textStyle(Theme.Text.callout)
                .foregroundStyle(Theme.Colors.secondaryLabel)
                .monospacedDigit()
                .padding(.horizontal, Theme.Space.x6)
        }
        .buttonStyle(.plain)
        .help("Tokens this spec has used: output and uncached input")
        .popover(isPresented: $showsSteps, arrowEdge: .bottom) {
            Grid(alignment: .leading, horizontalSpacing: Theme.Space.x24, verticalSpacing: Theme.Space.x6) {
                ForEach(spec.tokenSteps, id: \.step) { row in
                    GridRow {
                        Text(row.step.title)
                            .textStyle(Theme.Text.callout)
                            .foregroundStyle(Theme.Colors.label)
                        Text(TokenStep.text(row.tokens))
                            .textStyle(Theme.Text.callout)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                            .monospacedDigit()
                            .gridColumnAlignment(.trailing)
                    }
                }
            }
            .padding(Theme.Space.x12)
        }
    }
}

#Preview("Total") {
    TokenReadout(spec: PreviewData.tokens).padding()
}

#Preview("By step") {
    Grid(alignment: .leading) {
        ForEach(PreviewData.tokens.tokenSteps, id: \.step) { row in
            GridRow {
                Text(row.step.title)
                Text(TokenStep.text(row.tokens))
            }
        }
    }
    .padding()
}
