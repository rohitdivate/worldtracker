import SwiftUI
import WorldTrackerKit

/// A six-sided swatch with softened corners.
struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let points = (0..<6).map { index -> CGPoint in
            let angle = CGFloat(index) * .pi / 3 - .pi / 2
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }
        var path = Path()
        let corner = radius * 0.16
        for index in 0..<6 {
            let current = points[index]
            let next = points[(index + 1) % 6]
            let previous = points[(index + 5) % 6]
            let start = toward(current, previous, by: corner)
            let end = toward(current, next, by: corner)
            if index == 0 { path.move(to: start) } else { path.addLine(to: start) }
            path.addQuadCurve(to: end, control: current)
        }
        path.closeSubpath()
        return path
    }

    private func toward(_ from: CGPoint, _ to: CGPoint, by distance: CGFloat) -> CGPoint {
        let dx = to.x - from.x, dy = to.y - from.y
        let length = max(0.001, sqrt(dx * dx + dy * dy))
        return CGPoint(x: from.x + dx / length * distance, y: from.y + dy / length * distance)
    }
}

/// Skins as a shelf of swatches: tap one to wear it. Each tile is drawn in
/// its own skin, so the choice is visible before the whole app changes.
struct SkinPicker: View {
    let selected: ThemeID
    let onSelect: (ThemeID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ThemeID.allCases.filter { !$0.isClassic }) { tile($0) }
                    Rectangle()
                        .fill(Theme.hairline2)
                        .frame(width: 1, height: 44)
                        .padding(.horizontal, 2)
                    ForEach(ThemeID.allCases.filter(\.isClassic)) { tile($0) }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(selected.displayName.uppercased())
                    .font(Theme.poster(26))
                    .foregroundStyle(Theme.ink)
                Text(selected.tagline)
                    .font(Theme.label(11.5, weight: .medium))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .padding(.vertical, 6)
        // The section's caps styling is for rows; the tagline reads as a
        // sentence.
        .textCase(nil)
    }

    private func tile(_ theme: ThemeID) -> some View {
        let palette = theme.palette
        let isSelected = theme == selected
        return Button {
            guard !isSelected else { return }
            HapticsDirector.shared.tick()
            onSelect(theme)
        } label: {
            ZStack {
                Hexagon()
                    .fill(palette.sky.color)
                Hexagon()
                    .strokeBorder(Theme.ink.opacity(0.18), lineWidth: 1)
                // The skin's object and its "now" colour.
                Circle()
                    .fill(palette.isBold ? palette.globeOcean.color : palette.aurora1.color)
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(palette.isBold ? palette.amber.color : palette.aurora2.color)
                    .frame(width: 9, height: 9)
                    .offset(x: 9, y: -9)
            }
            .frame(width: 58, height: 64)
            .padding(5)
            .overlay(
                Hexagon()
                    .strokeBorder(isSelected ? Theme.ink : Color.clear, lineWidth: 2.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.displayName)
        .accessibilityHint(theme.tagline)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

extension Hexagon: InsettableShape {
    func inset(by amount: CGFloat) -> some InsettableShape {
        InsetHexagon(amount: amount)
    }
}

private struct InsetHexagon: InsettableShape {
    var amount: CGFloat

    func path(in rect: CGRect) -> Path {
        Hexagon().path(in: rect.insetBy(dx: amount, dy: amount))
    }

    func inset(by more: CGFloat) -> InsetHexagon {
        InsetHexagon(amount: amount + more)
    }
}
