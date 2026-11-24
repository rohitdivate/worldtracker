import Observation
import SceneKit
import SwiftUI
import WorldTrackerKit

/// The bold skins' Home hero: a real-time 3D globe sitting on an extruded
/// day-of-stay number. One matte object, lit from the top left, with the
/// skin's "now" colour as a rim light. Drag to spin it; double-tap to bring
/// the current country back to the front.

// MARK: - Texture

/// Paints the world as a flat equirectangular map for the globe: unvisited
/// land barely lifts off the ocean, visited countries are inlaid in the
/// skin's ground colour, and the country you are in is the "now" colour.
enum GlobeTexture {
    struct Colors: Sendable {
        let ocean: UIColor
        let land: UIColor
        let visited: UIColor
        let current: UIColor
    }

    static let size = CGSize(width: 2048, height: 1024)

    static func render(
        shapes: WorldMapShapes, visited: Set<String>, current: String?, colors: Colors
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.setFillColor(colors.ocean.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            func point(_ p: GeoPoint) -> CGPoint {
                CGPoint(
                    x: (p.longitude + 180) / 360 * size.width,
                    y: (90 - p.latitude) / 180 * size.height
                )
            }

            // Unvisited first, so a visited country's edge is never
            // overpainted by a neighbour.
            let codes = shapes.countryCodes.sorted {
                (visited.contains($0) ? 1 : 0, $0) < (visited.contains($1) ? 1 : 0, $1)
            }
            for code in codes {
                let path = CGMutablePath()
                for ring in shapes.rings(forCountry: code) where ring.count > 2 {
                    path.move(to: point(ring[0]))
                    for p in ring.dropFirst() { path.addLine(to: point(p)) }
                    path.closeSubpath()
                }
                let fill: UIColor
                if code == current {
                    fill = colors.current
                } else if visited.contains(code) {
                    fill = colors.visited
                } else {
                    fill = colors.land
                }
                cg.addPath(path)
                cg.setFillColor(fill.cgColor)
                cg.fillPath(using: .evenOdd)
                // A hairline in the ocean colour keeps neighbours apart.
                cg.addPath(path)
                cg.setStrokeColor(colors.ocean.cgColor)
                cg.setLineWidth(1.2)
                cg.strokePath()
            }
        }
    }
}

/// Owns the globe texture: rebuilt off the main thread when the ledger, the
/// current country or the skin changes.
@MainActor
@Observable
final class HeroGlobeModel {
    private(set) var image: UIImage?
    private(set) var focus: GeoPoint?

    @ObservationIgnored private var shapes: WorldMapShapes?
    @ObservationIgnored private var key = ""

    func refresh(visited: Set<String>, current: String?) async {
        let palette = Theme.palette
        let newKey = "\(palette.id.rawValue)|\(current ?? "-")|\(visited.sorted().joined())"
        guard newKey != key else { return }
        key = newKey

        if shapes == nil {
            shapes = try? await Task.detached(priority: .userInitiated) { try WorldMapShapes() }.value
        }
        guard let shapes else { return }

        let ocean = UIColor(palette.globeOcean.color)
        let ground = UIColor(palette.sky.color)
        let colors = GlobeTexture.Colors(
            ocean: ocean,
            land: ocean.mixed(with: ground, by: 0.17),
            visited: palette.isLight ? ground : UIColor(palette.ink.color),
            current: UIColor(palette.amber.color).brightened()
        )
        focus = current.flatMap { shapes.centroid(forCountry: $0) }
        image = await Task.detached(priority: .userInitiated) {
            GlobeTexture.render(shapes: shapes, visited: visited, current: current, colors: colors)
        }.value
    }
}

extension UIColor {
    func mixed(with other: UIColor, by amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * amount,
            green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount,
            alpha: 1
        )
    }

    /// The "now" colour is darkened to pass as text. On the globe it is a
    /// fill under a light, so it gets its saturation back.
    func brightened() -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: min(1, s * 1.05), brightness: min(1, max(b, 0.92)), alpha: 1)
    }
}

// MARK: - Scene

struct HeroSceneView: UIViewRepresentable {
    let texture: UIImage?
    let focus: GeoPoint?
    /// The extruded number under the globe. Nil hides it.
    let numeral: String?
    let objectColor: UIColor
    let rimColor: UIColor
    let reduceMotion: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.allowsCameraControl = false
        view.isAccessibilityElement = false
        view.scene = context.coordinator.buildScene()

        let pan = UIPanGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.pan(_:))
        )
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.recenter)
        )
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.apply(self)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let tilt = SCNNode()
        private let spin = SCNNode()
        private let sphere = SCNSphere(radius: 1)
        private let holder = SCNNode()
        private let numeralNode = SCNNode()
        private let rim = SCNLight()
        private let haptic = UISelectionFeedbackGenerator()

        private var shownNumeral: String?
        private var shownFocus: GeoPoint?
        private var shownTexture: UIImage?
        private var shownObject: UIColor?
        private var lastDetent = 0
        private var reduceMotion = false

        func buildScene() -> SCNScene {
            let scene = SCNScene()

            let camera = SCNCamera()
            camera.usesOrthographicProjection = true
            camera.orthographicScale = 2.45
            camera.zNear = 0.1
            camera.zFar = 50
            let cameraNode = SCNNode()
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0, 12)
            scene.rootNode.addChildNode(cameraNode)

            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.intensity = 420
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            // Key light from the top left front: gives the numeral its
            // bevels and the globe its day side.
            let key = SCNLight()
            key.type = .directional
            key.intensity = 1050
            let keyNode = SCNNode()
            keyNode.light = key
            keyNode.eulerAngles = SCNVector3(-0.75, -0.6, 0)
            scene.rootNode.addChildNode(keyNode)

            // Rim in the skin's "now" colour, grazing the globe from behind.
            // It is masked off the number: on those flat faces it read as a
            // muddy brown wash, not an edge glow.
            rim.type = .directional
            rim.categoryBitMask = Self.globeOnly
            rim.intensity = 700
            let rimNode = SCNNode()
            rimNode.light = rim
            rimNode.eulerAngles = SCNVector3(-0.5, -2.35, 0)
            scene.rootNode.addChildNode(rimNode)

            sphere.segmentCount = 96
            let material = sphere.firstMaterial ?? SCNMaterial()
            material.lightingModel = .blinn
            material.specular.contents = UIColor(white: 0.22, alpha: 1)
            material.shininess = 0.08
            sphere.materials = [material]

            spin.geometry = sphere
            spin.categoryBitMask = Self.everything
            numeralNode.categoryBitMask = Self.sharedLights
            tilt.addChildNode(spin)
            holder.addChildNode(tilt)
            holder.position = SCNVector3(0, 1.12, 1.6)
            scene.rootNode.addChildNode(holder)

            numeralNode.position = SCNVector3(0, -1.02, 0)
            numeralNode.eulerAngles = SCNVector3(-0.06, 0.34, 0)
            scene.rootNode.addChildNode(numeralNode)
            return scene
        }

        func apply(_ view: HeroSceneView) {
            reduceMotion = view.reduceMotion
            rim.color = view.rimColor

            if view.texture !== shownTexture {
                shownTexture = view.texture
                sphere.firstMaterial?.diffuse.contents = view.texture ?? view.objectColor
            }
            if view.numeral != shownNumeral || view.objectColor != shownObject {
                shownNumeral = view.numeral
                shownObject = view.objectColor
                rebuildNumeral(view.numeral, color: view.objectColor, rimTint: view.rimColor)
                // No number: the globe takes the middle of the stage.
                holder.position = view.numeral == nil
                    ? SCNVector3(0, 0, 0) : SCNVector3(0, 1.12, 1.6)
                holder.scale = view.numeral == nil
                    ? SCNVector3(1.7, 1.7, 1.7) : SCNVector3(1, 1, 1)
            }
            if view.focus != shownFocus {
                let first = shownFocus == nil
                shownFocus = view.focus
                face(view.focus, animated: !first)
            }
            startIdle()
        }

        /// SceneKit wraps an equirectangular texture with its centre
        /// (longitude 0) facing the camera, so turning the globe by minus
        /// the longitude brings a place to the front, and tilting north
        /// toward the viewer centres its latitude.
        private func face(_ point: GeoPoint?, animated: Bool) {
            guard let point else { return }
            let yaw = Float(-point.longitude * .pi / 180)
            // Sit the country a little above centre so the numeral's top
            // never hides it.
            let pitch = Float(max(-50, min(50, point.latitude - 12)) * .pi / 180)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = animated ? 0.9 : 0
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            spin.eulerAngles.y = yaw
            tilt.eulerAngles.x = pitch
            SCNTransaction.commit()
        }

        private func rebuildNumeral(_ string: String?, color: UIColor, rimTint: UIColor) {
            guard let string, !string.isEmpty else {
                numeralNode.geometry = nil
                return
            }
            let text = SCNText(string: string, extrusionDepth: 34)
            // SceneKit's text ignores the font's width axis, and extruding
            // the compressed glyph outlines directly yields no geometry, so
            // the black face is set at normal width and the node is squeezed
            // horizontally below: tall, narrow, heavy.
            text.font = UIFont.systemFont(ofSize: 100, weight: .black)
            text.flatness = 0.2
            text.chamferRadius = 2.6
            // A straight bevel: hard planes that catch the key light.
            let bevel = UIBezierPath()
            bevel.move(to: CGPoint(x: 0, y: 1))
            bevel.addLine(to: CGPoint(x: 1, y: 0))
            text.chamferProfile = bevel

            let face = SCNMaterial()
            face.lightingModel = .blinn
            face.diffuse.contents = color
            face.specular.contents = UIColor(white: 0.25, alpha: 1)
            face.shininess = 0.1
            // Two-tone on purpose: ink faces, with the extruded sides in the
            // skin's "now" colour. Lit by emission so the colour stays clean
            // instead of going brown in shadow.
            let side = face.copy() as! SCNMaterial
            side.diffuse.contents = rimTint
            side.emission.contents = rimTint
            side.emission.intensity = 0.45
            let chamfer = face.copy() as! SCNMaterial
            chamfer.diffuse.contents = color.mixed(with: .white, by: 0.2)
            // front, back, extruded sides, front chamfer, back chamfer
            text.materials = [face, face, side, chamfer, chamfer]

            numeralNode.geometry = text
            let (lo, hi) = text.boundingBox
            let width = (hi.x - lo.x) * Self.squeeze
            let height = hi.y - lo.y
            guard width > 0, height > 0 else { return }
            numeralNode.pivot = SCNMatrix4MakeTranslation(
                (lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2
            )
            let scale = min(2.5 / height, 3.6 / width)
            numeralNode.scale = SCNVector3(scale * Self.squeeze, scale, scale)
        }

        // Light categories: bit 0 is lit by the key and ambient lights
        // (their default mask covers every bit), bit 1 by the rim as well.
        private static let sharedLights = 1
        private static let globeOnly = 2
        private static let everything = 3

        /// Horizontal squeeze that turns the regular black face into a
        /// poster-condensed one.
        private static let squeeze: Float = 0.7

        /// A slow breath, so the object never looks like a picture.
        private func startIdle() {
            holder.removeAction(forKey: "idle")
            guard !reduceMotion else { return }
            let up = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 2.6)
            up.timingMode = .easeInEaseOut
            let down = up.reversed()
            holder.runAction(.repeatForever(.sequence([up, down])), forKey: "idle")
        }

        // MARK: Gestures

        @objc func pan(_ gesture: UIPanGestureRecognizer) {
            let delta = gesture.translation(in: gesture.view)
            gesture.setTranslation(.zero, in: gesture.view)
            spin.removeAction(forKey: "inertia")
            spin.eulerAngles.y += Float(delta.x) * 0.009
            tilt.eulerAngles.x = max(-1.1, min(1.1, tilt.eulerAngles.x + Float(delta.y) * 0.006))

            let detent = Int((spin.eulerAngles.y / 0.4).rounded(.down))
            if detent != lastDetent {
                lastDetent = detent
                haptic.selectionChanged()
            }

            if gesture.state == .ended {
                let velocity = gesture.velocity(in: gesture.view).x
                let coast = SCNAction.rotateBy(x: 0, y: velocity * 0.0009, z: 0, duration: 1.1)
                coast.timingMode = .easeOut
                spin.runAction(coast, forKey: "inertia")
            }
        }

        @objc func recenter() {
            spin.removeAction(forKey: "inertia")
            face(shownFocus, animated: true)
            haptic.selectionChanged()
        }

        /// Horizontal drags spin the globe; vertical ones stay with the
        /// scroll view the hero sits in.
        func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            guard let pan = gesture as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y)
        }
    }
}

// MARK: - Hero

/// Where you are, the bold way: label, object, word, caption.
struct HomeHeroBold: View {
    let stay: (countryCode: String, days: Int)?
    let isHome: Bool
    let daysThisYear: Int
    let lifetimeDays: Int
    let activeLimit: DayLimitStatus?
    let model: HeroGlobeModel
    /// Wide layouts give the object more room.
    var sceneHeight: CGFloat = 400

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("YOU'RE IN")
                    .font(Theme.label(11, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(Theme.ink2)
                if stay != nil {
                    HStack {
                        Spacer()
                        Text(isHome ? "HOME" : "AWAY")
                            .font(Theme.label(9.5, weight: .heavy))
                            .tracking(1.4)
                            .foregroundStyle(isHome ? Theme.sky : Theme.amber)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(isHome ? Theme.ink : Color.clear))
                            .overlay(
                                Capsule().strokeBorder(
                                    isHome ? Color.clear : Theme.amber, lineWidth: 1.5
                                )
                            )
                    }
                }
            }
            .padding(.top, 4)

            HeroSceneView(
                texture: model.image,
                focus: model.focus,
                numeral: stay.map { "\($0.days)" },
                objectColor: UIColor(Theme.globeOcean),
                rimColor: UIColor(Theme.amber).brightened(),
                reduceMotion: reduceMotion
            )
            .frame(height: sceneHeight)
            // A soft contact shadow, so the object stands on the page.
            .background(alignment: .bottom) {
                Ellipse()
                    .fill(Theme.ink.opacity(Theme.palette.isLight ? 0.16 : 0.5))
                    .frame(width: 170, height: 16)
                    .blur(radius: 10)
                    .offset(y: -2)
            }
            .padding(.horizontal, -18)

            Text(stay.map { countryName($0.countryCode) } ?? "Finding you…")
                .font(Theme.display(30, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.top, -6)

            if let stay {
                VStack(spacing: 3) {
                    Text(stay.days == 1 ? "ARRIVED TODAY" : "DAY \(stay.days) · HERE SINCE \(arrival(stay.days))")
                    Text("\(daysThisYear) \(daysThisYear == 1 ? "DAY" : "DAYS") THIS YEAR · \(lifetimeDays.grouped) ALL TIME")
                        .foregroundStyle(Theme.ink3)
                }
                .font(Theme.label(11, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Theme.ink2)
                .padding(.top, 8)
            }

            if let limit = activeLimit {
                limitStrip(limit)
                    .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let stay else { return "Finding your location" }
        return "You're in \(countryName(stay.countryCode)), day \(stay.days) of this stay. \(daysThisYear) days this year, \(lifetimeDays) all time."
    }

    /// The limit this stay is counting toward: one ruled row and a bar.
    private func limitStrip(_ status: DayLimitStatus) -> some View {
        NavigationLink(value: AppRouter.HomeRoute.limit(status.id)) {
            VStack(alignment: .leading, spacing: 8) {
                // One line when it fits; stacked in a narrow column.
                ViewThatFits(in: .horizontal) {
                    HStack {
                        limitName(status)
                        Spacer(minLength: 12)
                        limitCount(status)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        limitName(status)
                        limitCount(status)
                    }
                }
                .font(Theme.label(11, weight: .bold))
                .tracking(0.6)
                ProgressBar(fraction: status.fraction, height: 6, tint: status.tint)
            }
            .padding(14)
            .nightCard()
        }
        .buttonStyle(.plain)
    }

    private func limitName(_ status: DayLimitStatus) -> some View {
        Text(status.rule.name.uppercased())
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .fixedSize()
    }

    private func limitCount(_ status: DayLimitStatus) -> some View {
        Text("\(status.used)/\(status.rule.limit) · \(status.headline.uppercased())")
            .foregroundStyle(status.level.color)
            .lineLimit(1)
            .fixedSize()
    }

    private func arrival(_ days: Int) -> String {
        let today = AppContainer.shared.ledgerStore.todayEpoch
        let year = EpochDay(value: today).civil().year
        return DayFormat.shortRange(today - days + 1, today - days + 1, todayYear: year)
    }
}
