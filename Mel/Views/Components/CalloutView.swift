import SwiftUI

/// Assumption callout in Review: the agent's assumption with Change… / Confirm.
struct CalloutView: View {
    let text: String
    let onChange: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Assumption", systemImage: "questionmark.bubble")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.orange)
            Text(text)
                .textSelection(.enabled)
            HStack {
                Spacer()
                Button("Change…", action: onChange)
                Button("Confirm", action: onConfirm)
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(.orange.quinary, in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(.orange.tertiary)
        }
        .accessibilityElement(children: .contain)
    }
}
