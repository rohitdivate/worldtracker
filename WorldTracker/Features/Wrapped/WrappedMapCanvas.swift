import SwiftUI
import WorldTrackerKit

/// Canvas world map for Wrapped — deliberately NOT MapKit: every stroke is
/// animatable and it renders faithfully inside ImageRenderer for share cards.
/// Equirectangular projection of the bundled 110m outlines.
struct WrappedMapCanvas: View {
    let shapes: WorldMapShapes?
    let daysPerCountry: [String: Int]
    let homeCountry: String?
    let homeCentroid: GeoPoint?
    let arcTargets: [(code: String, center: GeoPoint)]
    /// Order countries ignite in (first-appearance order).
    let lightOrder: [String]
    /// 0…1: how many countries are lit.
    var litProgress: Double = 1
    /// 0…1: how far the arcs have drawn.
    var arcProgress: Double = 1
    /// Crop the projection to this lat/lon box (nil = world).
    var focusBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)?

    var body: some View {
        Canvas { context, size in
            guard let shapes else { return }

            let box = focusBox ?? (minLat: -58, maxLat: 78, minLon: -180, maxLon: 180)
            let lonSpan = max(1, box.maxLon - box.minLon)
            let latSpan = max(1, box.maxLat - box.minLat)

            func project(_ point: GeoPoint) -> CGPoint {
                CGPoint(
                    x: (point.longitude - box.minLon) / lonSpan * size.width,
                    y: (box.maxLat - point.latitude) / latSpan * size.height
                )
            }

            let maxDays = daysPerCountry.values.max() ?? 1
            let litCount = Int((Double(lightOrder.count) * litProgress).rounded(.up))
            let litSet = Set(lightOrder.prefix(litCount))

            // Unvisited landmass: faint outlines only.
            for code in shapes.countryCodes where daysPerCountry[code] == nil {
                var path = Path()
                for ring in shapes.rings(forCountry: code) {
                    guard ring.count > 2 else { continue }
                    path.move(to: project(ring[0]))
                    for point in ring.dropFirst() {
                        path.addLine(to: project(point))
                    }
                    path.closeSubpath()
                }
                context.stroke(path, with: .color(Theme.hairline), lineWidth: 0.5)
            }

            // Visited countries, aurora-filled, in light-up order.
            for code in daysPerCountry.keys {
                guard litSet.contains(code) || litProgress >= 1 else { continue }
                let isHome = code == homeCountry
                let intensity = 0.25 + 0.5 * Double(daysPerCountry[code] ?? 0) / Double(maxDays)
                var path = Path()
                for ring in shapes.rings(forCountry: code) {
                    guard ring.count > 2 else { continue }
                    path.move(to: project(ring[0]))
                    for point in ring.dropFirst() {
                        path.addLine(to: project(point))
                    }
                    path.closeSubpath()
                }
                context.fill(
                    path,
                    with: .color(isHome ? Theme.amber.opacity(0.5) : Theme.aurora1.opacity(intensity))
                )
            }

            // Great-circle arcs with progressive draw.
            if let homeCentroid, arcProgress > 0 {
                for (index, target) in arcTargets.enumerated() {
                    // Stagger: each arc occupies a slice of the progress.
                    let slice = 1.0 / Double(max(1, arcTargets.count))
                    let local = (arcProgress - Double(index) * slice * 0.6) / slice
                    let t = max(0, min(1, local))
                    guard t > 0 else { continue }

                    let full = greatCircleArc(from: homeCentroid, to: target.center, samples: 40)
                    let visible = Array(full.prefix(max(2, Int(Double(full.count) * t))))
                    var path = Path()
                    path.move(to: project(visible[0]))
                    for point in visible.dropFirst() {
                        path.addLine(to: project(point))
                    }
                    context.stroke(
                        path,
                        with: .color(Theme.aurora2.opacity(0.75)),
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                    )
                    // Comet head.
                    if t < 1, let head = visible.last {
                        let headPoint = project(head)
                        context.fill(
                            Path(ellipseIn: CGRect(x: headPoint.x - 2.5, y: headPoint.y - 2.5, width: 5, height: 5)),
                            with: .color(Theme.aurora1)
                        )
                    }
                }

                // Home beacon.
                let home = project(homeCentroid)
                context.fill(
                    Path(ellipseIn: CGRect(x: home.x - 3.5, y: home.y - 3.5, width: 7, height: 7)),
                    with: .color(Theme.amber)
                )
            }
        }
    }
}
