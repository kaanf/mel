import SwiftUI

/// The honeycomb mark (design/v2 V2-2, Tell Mel bar and panel): an amber tile, an orange hexagon,
/// a dark core.
struct MelMark: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.224).fill(Theme.Colors.projectTile)
            Hexagon().fill(Theme.Colors.markHex).frame(width: size * 0.56, height: size * 0.485)
            Hexagon().fill(Theme.Colors.markCore).frame(width: size * 0.22, height: size * 0.19)
            RoundedRectangle(cornerRadius: size * 0.224).strokeBorder(Color.ink(0.1), lineWidth: 0.5)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A hexagon with points left and right.
nonisolated private struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let (w, h) = (rect.width, rect.height)
        return Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.minX + w / 4, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - w / 4, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX - w / 4, y: rect.minY + h))
            p.addLine(to: CGPoint(x: rect.minX + w / 4, y: rect.minY + h))
            p.closeSubpath()
        }
    }
}

#Preview("Mark") {
    HStack(spacing: 16) { MelMark(size: 20); MelMark(size: 32) }.padding()
}
