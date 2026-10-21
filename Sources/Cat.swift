import AppKit
import QuartzCore

/// Maps coordinates traced from the 740×740 reference drawing (y pointing down)
/// into layer space (y pointing up), scaled to the cat's on-screen size.
struct CatGeometry {
    static let minX: CGFloat = 140, maxX: CGFloat = 640, minY: CGFloat = 40, maxY: CGFloat = 740
    let s: CGFloat

    var size: CGSize { CGSize(width: (Self.maxX - Self.minX) * s, height: (Self.maxY - Self.minY) * s) }
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (x - Self.minX) * s, y: (Self.maxY - y) * s) }
    func len(_ v: CGFloat) -> CGFloat { v * s }
}

/// The cat, built from separate vector parts so her eyes, ears and whiskers can move.
@MainActor
final class Cat {
    /// Anchored at bottom-centre. Rises, hops and leaves.
    let root = CALayer()
    /// Anchored at bottom-centre. Sways gently while idle.
    private let figure = CALayer()
    private let g: CatGeometry

    private let body = CAShapeLayer()
    private let leftEar = CAShapeLayer()
    private let rightEar = CAShapeLayer()
    private let leftWhiskers = CAShapeLayer()
    private let rightWhiskers = CAShapeLayer()
    private var eyes: [Eye] = []
    private var alive = false

    private struct Eye {
        let layer: CAShapeLayer
        let pupil: CAShapeLayer
        let center: CGPoint   // in figure coordinates
        let rest: CGPoint     // pupil position when looking straight ahead
        let reach: CGSize     // how far the pupil can travel from the centre
    }

    var size: CGSize { g.size }

    init(height: CGFloat) {
        g = CatGeometry(s: height / (CatGeometry.maxY - CatGeometry.minY))
        let bounds = CGRect(origin: .zero, size: g.size)

        root.bounds = bounds
        root.anchorPoint = CGPoint(x: 0.5, y: 0)
        figure.bounds = bounds
        figure.anchorPoint = CGPoint(x: 0.5, y: 0)
        figure.position = CGPoint(x: bounds.midX, y: 0)
        root.addSublayer(figure)

        buildEars()
        buildBody()
        buildWhiskers()
        eyes = [
            makeEye(cx: 293, cy: 345, rx: 40, ry: 46, bias: 10),
            makeEye(cx: 462, cy: 345, rx: 38, ry: 46, bias: -6),
        ]
        buildNose()
    }

    // MARK: - Drawing

    private func buildBody() {
        let b = CGMutablePath()
        b.move(to: g.p(215, 740))
        b.addCurve(to: g.p(295, 500), control1: g.p(228, 620), control2: g.p(285, 560))
        b.addCurve(to: g.p(232, 400), control1: g.p(262, 468), control2: g.p(232, 440))
        b.addCurve(to: g.p(250, 262), control1: g.p(230, 345), control2: g.p(236, 295))
        b.addCurve(to: g.p(538, 272), control1: g.p(310, 205), control2: g.p(470, 205))
        b.addCurve(to: g.p(548, 400), control1: g.p(552, 320), control2: g.p(552, 370))
        b.addCurve(to: g.p(470, 500), control1: g.p(544, 452), control2: g.p(500, 480))
        b.addCurve(to: g.p(510, 740), control1: g.p(468, 580), control2: g.p(498, 650))
        b.closeSubpath()
        addPart(body, path: b, pivot: g.p(380, 740))
    }

    private func buildEars() {
        let l = CGMutablePath()
        l.move(to: g.p(236, 300))
        l.addCurve(to: g.p(272, 58), control1: g.p(236, 190), control2: g.p(250, 100))
        l.addCurve(to: g.p(365, 245), control1: g.p(300, 110), control2: g.p(345, 190))
        l.addLine(to: g.p(300, 300))
        l.closeSubpath()
        addPart(leftEar, path: l, pivot: g.p(295, 270))

        let r = CGMutablePath()
        r.move(to: g.p(410, 245))
        r.addCurve(to: g.p(492, 62), control1: g.p(430, 180), control2: g.p(465, 105))
        r.addCurve(to: g.p(548, 305), control1: g.p(520, 120), control2: g.p(542, 220))
        r.addLine(to: g.p(470, 300))
        r.closeSubpath()
        addPart(rightEar, path: r, pivot: g.p(480, 270))
    }

    private func buildWhiskers() {
        func lines(_ segments: [(CGFloat, CGFloat, CGFloat, CGFloat)]) -> CGPath {
            let p = CGMutablePath()
            for (x1, y1, x2, y2) in segments {
                p.move(to: g.p(x1, y1))
                p.addLine(to: g.p(x2, y2))
            }
            return p
        }
        let left = lines([(238, 410, 152, 410), (240, 428, 158, 452), (246, 447, 176, 493)])
        let right = lines([(548, 405, 610, 400), (550, 424, 614, 445), (546, 443, 600, 486)])
        for (layer, path, pivot) in [(leftWhiskers, left, g.p(240, 428)), (rightWhiskers, right, g.p(548, 424))] {
            addPart(layer, path: path, pivot: pivot)
            layer.fillColor = nil
            layer.strokeColor = NSColor.black.cgColor
            layer.lineWidth = max(1.5, g.len(3.6))
            layer.lineCap = .round
        }
    }

    private func makeEye(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, bias: CGFloat) -> Eye {
        let center = g.p(cx, cy)
        let eye = CAShapeLayer()
        eye.bounds = CGRect(x: 0, y: 0, width: g.len(rx * 2), height: g.len(ry * 2))
        eye.position = center
        let oval = CGPath(ellipseIn: eye.bounds, transform: nil)
        eye.path = oval
        eye.fillColor = NSColor.white.cgColor
        let mask = CAShapeLayer()
        mask.frame = eye.bounds
        mask.path = oval
        eye.mask = mask

        let pupil = CAShapeLayer()
        pupil.bounds = CGRect(x: 0, y: 0, width: g.len(18), height: g.len(38))
        pupil.path = CGPath(ellipseIn: pupil.bounds, transform: nil)
        pupil.fillColor = NSColor.black.cgColor
        let rest = CGPoint(x: eye.bounds.midX + g.len(bias), y: eye.bounds.midY)
        pupil.position = rest
        eye.addSublayer(pupil)
        figure.addSublayer(eye)

        return Eye(layer: eye, pupil: pupil, center: center, rest: rest,
                   reach: CGSize(width: g.len(rx - 16), height: g.len(ry - 26)))
    }

    private func buildNose() {
        let nose = CAShapeLayer()
        let c = g.p(397, 390)
        nose.path = CGPath(ellipseIn: CGRect(x: c.x - g.len(9), y: c.y - g.len(4.5),
                                             width: g.len(18), height: g.len(9)), transform: nil)
        nose.fillColor = NSColor.white.cgColor
        nose.frame = figure.bounds
        figure.addSublayer(nose)
    }

    /// Adds a part whose path is in figure coordinates, rotating around `pivot`.
    private func addPart(_ layer: CAShapeLayer, path: CGPath, pivot: CGPoint) {
        layer.bounds = figure.bounds
        layer.anchorPoint = CGPoint(x: pivot.x / g.size.width, y: pivot.y / g.size.height)
        layer.position = pivot
        layer.path = path
        layer.fillColor = NSColor.black.cgColor
        figure.addSublayer(layer)
    }

    // MARK: - Geometry helpers

    /// A point on the reference drawing, in the coordinates of `root`'s superlayer
    /// (ignores in-flight animations).
    func hostPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        let local = g.p(x, y)
        return CGPoint(x: root.position.x - g.size.width / 2 + local.x, y: root.position.y + local.y)
    }

    func contains(_ point: CGPoint) -> Bool {
        let q = figure.convert(point, from: root.superlayer)
        return [body, leftEar, rightEar].contains { $0.path?.contains(q) == true }
    }

    // MARK: - Animation

    func rise(to final: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.position = final
        CATransaction.commit()

        let spring = CASpringAnimation(keyPath: "position.y")
        spring.fromValue = hiddenY
        spring.toValue = final.y
        spring.damping = 11
        spring.stiffness = 130
        spring.mass = 1
        spring.duration = spring.settlingDuration
        root.add(spring, forKey: "rise")
    }

    private var hiddenY: CGFloat { -g.size.height - 20 }

    func startIdle() {
        alive = true
        let sway = CABasicAnimation(keyPath: "transform.rotation.z")
        sway.fromValue = -0.02
        sway.toValue = 0.02
        sway.duration = 2.4
        sway.autoreverses = true
        sway.repeatCount = .infinity
        sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        figure.add(sway, forKey: "sway")

        loop(2.0...4.5) { $0.blink() }
        loop(2.5...5.5) { $0.twitchEar() }
        loop(3.5...7.0) { $0.twitchWhiskers() }
    }

    /// Repeats `action` at random intervals while the cat is on screen.
    private func loop(_ range: ClosedRange<Double>, _ action: @escaping (Cat) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: range)) { [weak self] in
            guard let self, self.alive else { return }
            action(self)
            self.loop(range, action)
        }
    }

    func blink() {
        let double = Int.random(in: 0..<4) == 0
        let a = CAKeyframeAnimation(keyPath: "transform.scale.y")
        a.values = double ? [1, 0.08, 1, 0.08, 1] : [1, 0.08, 1]
        a.keyTimes = double ? [0, 0.2, 0.45, 0.7, 1] : [0, 0.45, 1]
        a.duration = double ? 0.42 : 0.2
        eyes.forEach { $0.layer.add(a, forKey: "blink") }
    }

    func twitchEar() {
        let isLeft = Bool.random()
        let d: Double = isLeft ? 1 : -1   // positive rotation tips the left ear outward
        let a = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        a.values = [0, 0.16 * d, -0.05 * d, 0.07 * d, 0]
        a.keyTimes = [0, 0.2, 0.45, 0.7, 1]
        a.duration = 0.45
        (isLeft ? leftEar : rightEar).add(a, forKey: "twitch")
    }

    func twitchWhiskers() {
        for (layer, d) in [(leftWhiskers, -1.0), (rightWhiskers, 1.0)] {
            let a = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            a.values = [0, 0.07 * d, -0.04 * d, 0.03 * d, 0]
            a.keyTimes = [0, 0.2, 0.45, 0.7, 1]
            a.duration = 0.4
            layer.add(a, forKey: "twitch")
        }
    }

    /// A little hop. Used when you click somewhere other than her.
    func hop() {
        let a = CAKeyframeAnimation(keyPath: "position.y")
        a.values = [0, g.len(45), 0, g.len(12), 0]
        a.keyTimes = [0, 0.35, 0.65, 0.82, 1]
        a.duration = 0.45
        a.isAdditive = true
        a.timingFunctions = [.init(name: .easeOut), .init(name: .easeIn), .init(name: .easeOut), .init(name: .easeIn)]
        root.add(a, forKey: "hop")
        twitchEar()
    }

    /// Pupils follow the mouse. `point` is in `root`'s superlayer coordinates.
    func lookAt(_ point: CGPoint) {
        let q = figure.convert(point, from: root.superlayer)
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        for e in eyes {
            let dx = q.x - e.center.x, dy = q.y - e.center.y
            let dist = max(hypot(dx, dy), 0.001)
            let mag = min(dist / g.len(260), 1)
            let bias = e.rest.x - e.layer.bounds.midX
            e.pupil.position = CGPoint(
                x: e.layer.bounds.midX + bias * (1 - mag) + dx / dist * mag * e.reach.width,
                y: e.layer.bounds.midY + dy / dist * mag * e.reach.height)
        }
        CATransaction.commit()
    }

    /// Happy squint, a hop, then she ducks back down below the screen.
    func leave(completion: @escaping () -> Void) {
        alive = false
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        eyes.forEach {
            $0.layer.transform = CATransform3DMakeScale(1, 0.14, 1)
            $0.pupil.position = $0.rest
        }
        CATransaction.commit()
        hop()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            let down = CABasicAnimation(keyPath: "position.y")
            down.fromValue = root.position.y
            down.toValue = hiddenY
            down.duration = 0.4
            down.timingFunction = CAMediaTimingFunction(name: .easeIn)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            root.position.y = hiddenY
            CATransaction.commit()
            root.add(down, forKey: "leave")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: completion)
        }
    }
}
