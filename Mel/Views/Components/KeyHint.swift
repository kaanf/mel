import SwiftUI

/// Small key cap showing a keyboard shortcut, e.g. "1" or "↩".
struct KeyHint: View {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(key)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(.quaternary, in: .rect(cornerRadius: 4))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        KeyHint("1")
        KeyHint("4")
        KeyHint("↩")
    }
    .padding()
}
