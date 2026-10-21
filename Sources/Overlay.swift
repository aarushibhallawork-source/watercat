import AppKit
import QuartzCore

// MARK: - Windows

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    convenience init(screen: NSScreen) {
        self.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
    }
}

/// The dark see-through layer. It swallows every click and key press, so your apps
/// stay out of reach until she's dismissed.
class DimView: NSView {
    /// A soft pink glow behind the cat, so she stands out on any wallpaper.
    var glow: (center: CGPoint, radius: CGFloat)?

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func keyDown(with event: NSEvent) {}

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.62))
        ctx.fill(bounds)

        guard let glow, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        let pink = { (a: CGFloat) in CGColor(srgbRed: 1, green: 0.74, blue: 0.85, alpha: a) }
        let colors = [pink(0.6), pink(0.5), pink(0.2), pink(0)] as CFArray
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 0.78, 1]) else { return }
        ctx.drawRadialGradient(gradient, startCenter: glow.center, startRadius: 0,
                               endCenter: glow.center, endRadius: glow.radius, options: [])
    }
}

/// The dim layer on the main screen, with the cat and her speech bubble.
final class ReminderView: DimView {
    var onDismiss: (() -> Void)?
    private let cat: Cat
    private let bubble: Bubble
    private var dismissing = false
    private var eyeTimer: Timer?

    init(frame: NSRect, backingScale: CGFloat) {
        cat = Cat(height: min(frame.height * 0.26, 270))
        let (title, subtitle) = Messages.next()
        bubble = Bubble(title: title, subtitle: subtitle, scale: backingScale)
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Bottom-right corner, with the bubble to her left.
        cat.root.position = CGPoint(x: frame.width - 40 - cat.size.width / 2, y: -cat.size.height * 0.1)
        bubble.root.position = cat.hostPoint(135, 318)
        CATransaction.commit()

        glow = (cat.hostPoint(390, 420), cat.size.height * 0.85)
        layer?.addSublayer(cat.root)
        layer?.addSublayer(bubble.root)
    }

    required init?(coder: NSCoder) { fatalError() }

    func start() {
        cat.rise(to: cat.root.position)
        cat.startIdle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in self?.bubble.pop() }
        eyeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.followMouse() }
        }
    }

    private func followMouse() {
        guard let window, !dismissing else { return }
        let p = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        cat.lookAt(p)
    }

    override func mouseDown(with event: NSEvent) {
        guard !dismissing else { return }
        if cat.contains(convert(event.locationInWindow, from: nil)) {
            dismiss()
        } else {
            cat.hop()
            bubble.nudge()
        }
    }

    func dismiss() {
        guard !dismissing else { return }
        dismissing = true
        eyeTimer?.invalidate()
        NSCursor.arrow.set()
        bubble.fade()
        cat.leave { [weak self] in self?.onDismiss?() }
    }

    // Pointing-hand cursor over the cat, so it's obvious she's clickable.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        let over = !dismissing && cat.contains(convert(event.locationInWindow, from: nil))
        (over ? NSCursor.pointingHand : NSCursor.arrow).set()
    }
}

// MARK: - Speech bubble

@MainActor
final class Bubble {
    let root = CALayer()

    init(title: String, subtitle: String, scale: CGFloat) {
        let titleText = NSAttributedString(string: title, attributes: [
            .font: Self.rounded(18, .bold), .foregroundColor: NSColor(white: 0.1, alpha: 1)])
        let subText = NSAttributedString(string: subtitle, attributes: [
            .font: Self.rounded(12.5, .medium), .foregroundColor: NSColor(white: 0.45, alpha: 1)])
        let ts = titleText.size(), ss = subText.size()
        let padX: CGFloat = 18, padY: CGFloat = 13, gap: CGFloat = 3, tail: CGFloat = 14
        let w = ceil(max(ts.width, ss.width)) + padX * 2
        let h = ceil(ts.height + gap + ss.height) + padY * 2
        let tipY = h * 0.42

        root.bounds = CGRect(x: 0, y: 0, width: w + tail, height: h)
        root.anchorPoint = CGPoint(x: 1, y: tipY / h)
        root.opacity = 0

        let shape = CAShapeLayer()
        shape.frame = root.bounds
        let path = CGMutablePath()
        // Tail on the right, pointing at her.
        path.addRoundedRect(in: CGRect(x: 0, y: 0, width: w, height: h), cornerWidth: 18, cornerHeight: 18)
        path.move(to: CGPoint(x: w - 10, y: tipY - 8))
        path.addQuadCurve(to: CGPoint(x: w + tail, y: tipY), control: CGPoint(x: w + tail * 0.4, y: tipY - 5))
        path.addQuadCurve(to: CGPoint(x: w - 10, y: tipY + 12), control: CGPoint(x: w + tail * 0.5, y: tipY + 4))
        path.closeSubpath()
        shape.path = path
        shape.fillColor = NSColor.white.cgColor
        shape.shadowColor = NSColor.black.cgColor
        shape.shadowOpacity = 0.3
        shape.shadowRadius = 14
        shape.shadowOffset = CGSize(width: 0, height: -4)
        root.addSublayer(shape)

        func text(_ s: NSAttributedString, y: CGFloat) {
            let t = CATextLayer()
            t.string = s
            t.contentsScale = scale
            t.frame = CGRect(x: padX, y: y, width: ceil(s.size().width) + 2, height: ceil(s.size().height))
            root.addSublayer(t)
        }
        text(subText, y: padY)
        text(titleText, y: padY + ceil(ss.height) + gap)
    }

    func pop() {
        root.opacity = 1
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.duration = 0.15
        let grow = CASpringAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.4
        grow.toValue = 1
        grow.damping = 10
        grow.stiffness = 180
        grow.duration = grow.settlingDuration
        root.add(fade, forKey: "fade")
        root.add(grow, forKey: "grow")
    }

    /// A quick wiggle to point you back at her.
    func nudge() {
        let a = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        a.values = [0, 0.05, -0.04, 0.02, 0]
        a.duration = 0.4
        root.add(a, forKey: "nudge")
    }

    func fade() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        root.opacity = 0
        CATransaction.commit()
    }

    private static func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let d = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: d, size: size) ?? base
    }
}

// MARK: - Controller

@MainActor
final class ReminderController {
    var onFinished: (() -> Void)?
    private var windows: [OverlayWindow] = []

    var isShowing: Bool { !windows.isEmpty }

    func show() {
        guard !isShowing, let main = NSScreen.screens.first else { return }
        var reminderView: ReminderView?

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            let frame = NSRect(origin: .zero, size: screen.frame.size)
            if screen == main {
                let view = ReminderView(frame: frame, backingScale: screen.backingScaleFactor)
                view.onDismiss = { [weak self] in self?.hide() }
                window.contentView = view
                reminderView = view
            } else {
                window.contentView = DimView(frame: frame)
            }
            window.alphaValue = 0
            window.orderFrontRegardless()
            windows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.45
            windows.forEach { $0.animator().alphaValue = 1 }
        }
        reminderView?.start()
    }

    /// Dismisses her with the same animation as clicking on her.
    func dismiss() {
        (windows.first?.contentView as? ReminderView)?.dismiss()
    }

    private func hide() {
        let closing = windows
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                closing.forEach { $0.orderOut(nil) }
                self?.windows.removeAll()
                self?.onFinished?()
            }
        })
    }
}
