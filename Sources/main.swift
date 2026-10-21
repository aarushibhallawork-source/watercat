import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let reminder = ReminderController()
    private var nextReminder = Date()
    /// During the noon and 4pm rush she comes back sooner, at this randomly picked time.
    private var nextRushReminder = Date()
    private var paused = false
    private var ticker: Timer?
    private var activity: NSObjectProtocol?

    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "", action: #selector(togglePause), keyEquivalent: "p")
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep App Nap from delaying the reminders.
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep, reason: "Water reminders")

        setupMenu()
        reminder.onFinished = { [weak self] in self?.resetCountdown() }
        resetCountdown()

        // Check the wall clock rather than relying on one long timer, which drifts across sleep.
        ticker = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)

        if CommandLine.arguments.contains("--now") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.remindNow() }
        }
        // For testing: dismiss on her own after N seconds.
        if let secs = ProcessInfo.processInfo.environment["WATERCAT_AUTODISMISS"].flatMap(Double.init) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1 + secs) { self.reminder.dismiss() }
        }
    }

    private func tick() {
        guard !paused, !reminder.isShowing else { return }
        let now = Date()
        let rushDue = Schedule.rush(at: now) != nil && now >= nextRushReminder
        if now >= nextReminder || rushDue { reminder.show() }
    }

    private func resetCountdown() {
        nextReminder = Date().addingTimeInterval(Schedule.normalGap)
        nextRushReminder = Date().addingTimeInterval(.random(in: Schedule.rushGap))
    }

    @objc private func didWake() {
        // You were probably away. Start a fresh 30 minutes instead of pouncing on wake.
        if !reminder.isShowing { resetCountdown() }
    }

    // MARK: - Menu bar

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.menuIcon()
        statusItem.button?.toolTip = "Water Cat"

        let menu = NSMenu()
        menu.delegate = self
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Remind Me Now", action: #selector(remindNow), keyEquivalent: "r").target = self
        pauseItem.target = self
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(withTitle: "Quit Water Cat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if paused {
            statusLine.title = "Reminders paused"
        } else if reminder.isShowing {
            statusLine.title = "Waiting for you to sip…"
        } else if Schedule.rush(at: Date()) != nil {
            statusLine.title = "Rush hour. She could pop up any minute 👀"
        } else {
            let mins = Int(ceil(nextReminder.timeIntervalSinceNow / 60))
            statusLine.title = mins <= 1 ? "Next sip in under a minute" : "Next sip in \(mins) min"
        }
        pauseItem.title = paused ? "Resume Reminders" : "Pause Reminders"
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func remindNow() {
        reminder.show()
    }

    @objc private func togglePause() {
        paused.toggle()
        if !paused { resetCountdown() }
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change the login setting"
            alert.informativeText = "Try moving Water Cat into your Applications folder first.\n\n\(error.localizedDescription)"
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    /// A tiny cat-head silhouette for the menu bar.
    private static func menuIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 2.5, y: 1.5, width: 13, height: 11)).fill()
            for (base, tip, inner) in [((3.0, 8.0), (4.5, 17.0), (9.0, 11.0)), ((15.0, 8.0), (13.5, 17.0), (9.0, 11.0))] {
                let ear = NSBezierPath()
                ear.move(to: NSPoint(x: base.0, y: base.1))
                ear.line(to: NSPoint(x: tip.0, y: tip.1))
                ear.line(to: NSPoint(x: inner.0, y: inner.1))
                ear.close()
                ear.fill()
            }
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: NSRect(x: 5, y: 5, width: 3, height: 3.6)).fill()
            NSBezierPath(ovalIn: NSRect(x: 10, y: 5, width: 3, height: 3.6)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
