import SwiftUI

/// One answer option in Discovery. A real button, so it works with VoiceOver and Full Keyboard Access.
struct RadioRow: View {
    let label: String
    var note: String?
    var suggested = false
    var keyHint: String?
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(label)
                        if suggested {
                            Text("Suggested")
                                .font(.caption)
                                .foregroundStyle(.tint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(.tint.quaternary, in: .capsule)
                        }
                    }
                    if let note {
                        Text(note)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let keyHint {
                    KeyHint(keyHint)
                }
            }
            .padding(10)
            .contentShape(.rect)
            .background(
                isSelected ? AnyShapeStyle(.tint.quinary) : AnyShapeStyle(.clear),
                in: .rect(cornerRadius: 8)
            )
            .overlay {
                if isSelected && contrast == .increased {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(.tint)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(keyHint.map { "Shortcut \($0)" } ?? "")
    }
}

#Preview {
    VStack(spacing: 4) {
        RadioRow(label: "Members book themselves", note: "Simplest for the studio.", suggested: true, keyHint: "1", isSelected: true) {}
        RadioRow(label: "Front desk books for them", note: "More control, more work.", keyHint: "2", isSelected: false) {}
        RadioRow(label: "You decide", note: "The agent picks the best option and marks it as an assumption", keyHint: "3", isSelected: false) {}
    }
    .frame(width: 480)
    .padding()
}
