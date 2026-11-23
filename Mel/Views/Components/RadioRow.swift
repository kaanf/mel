import SwiftUI

/// One answer option (design/v2 B2): 14 pt radio, label with an optional "Suggested" tag, note, key hint.
/// A real button, so it works with VoiceOver and Full Keyboard Access.
struct RadioRow: View {
    let label: String
    var note: String?
    var suggested = false
    var keyHint: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Theme.Space.x8) {
                Circle()
                    .fill(Theme.Colors.background)
                    .frame(width: Theme.Size.radioDot, height: Theme.Size.radioDot)
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: Theme.Size.radio, height: Theme.Size.radio)
                    .surface(isSelected ? Theme.Colors.accent : Theme.Colors.background, isSelected ? .radioOn : .radioOff, in: Circle())
                    .padding(.top, Theme.Space.x2)
                VStack(alignment: .leading, spacing: Theme.Space.x1) {
                    HStack(spacing: Theme.Space.x6) {
                        Text(label)
                            .textStyle(Theme.Text.body)
                            .foregroundStyle(Theme.Colors.label)
                        if suggested {
                            Text("Suggested")
                                .textStyle(Theme.Text.caption)
                                .foregroundStyle(Theme.Colors.label)
                                .padding(.horizontal, Theme.Space.x6)
                                .surface(.clear, .outlineTag, in: RoundedRectangle(cornerRadius: Theme.Radius.keyHint))
                        }
                    }
                    if let note {
                        Text(note)
                            .textStyle(Theme.Text.caption)
                            .foregroundStyle(Theme.Colors.secondaryLabel)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let keyHint {
                    Text(keyHint)
                        .textStyle(Theme.Text.caption)
                        .foregroundStyle(Theme.Colors.label)
                        .padding(.horizontal, Theme.Space.x6)
                        .padding(.vertical, Theme.Space.x1)
                        .surface(Theme.Colors.background, .optionKey, in: RoundedRectangle(cornerRadius: Theme.Radius.keyHint))
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, Theme.Space.x9)
            .padding(.horizontal, Theme.Space.x12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(keyHint.map { "Shortcut \($0)" } ?? "")
    }
}

#Preview {
    VStack(spacing: 0) {
        RadioRow(label: "Class packs bought in the app", note: "You mentioned buying class packs in your idea", suggested: true, keyHint: "1", isSelected: true) {}
        RadioRow(label: "Paid at the desk, app only books", note: "No checkout in the app; staff adds credits", keyHint: "2", isSelected: false) {}
    }
    .frame(width: 520)
    .background(Theme.Colors.fill)
    .padding()
    .background(Theme.Colors.background)
}
