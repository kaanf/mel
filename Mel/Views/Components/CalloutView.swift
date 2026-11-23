import SwiftUI

/// Assumption callout in Review: the agent's assumption with Change… / Confirm.
/// Without actions (read-only live preview) the buttons are hidden.
struct CalloutView: View {
    let text: String
    var onChange: (() -> Void)?
    var onConfirm: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Assumption", systemImage: "questionmark.bubble")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.orange)
            Text(text)
                .textSelection(.enabled)
            if let onChange, let onConfirm {
                HStack {
                    Spacer()
                    Button("Change…", action: onChange)
                    Button("Confirm", action: onConfirm)
                        .buttonStyle(.borderedProminent)
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.quinary, in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).strokeBorder(.orange.tertiary)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview("Actions") {
    CalloutView(text: "Members can cancel up to 12 hours before class.", onChange: {}, onConfirm: {})
        .frame(width: 480)
        .padding()
}

#Preview("Read only") {
    CalloutView(text: "Members can cancel up to 12 hours before class.")
        .frame(width: 480)
        .padding()
}
