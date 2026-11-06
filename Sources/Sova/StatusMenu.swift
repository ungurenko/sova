import AppKit
import SovaCore

/// The eye in the menu bar and its menu. The menu is built fresh each time it opens;
/// the one-second timer for the countdown runs only while the menu is open.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let controller: SessionController
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var countdownItem: NSMenuItem?
    private var ticker: Timer?

    init(controller: SessionController) {
        self.controller = controller
        super.init()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        refreshIcon()
    }

    private var isActive: Bool { controller.state.isActive }

    func refreshIcon() {
        item.button?.image = isActive ? EyeIcon.open : EyeIcon.closed
        item.button?.setAccessibilityLabel(isActive ? "Sova: Мак не уснёт" : "Sova: сон работает как обычно")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        countdownItem = info("")
        updateCountdown()
        menu.addItem(.separator())
        info("Не давать спать:")
        for option in Rules.durations {
            let entry = action(option.label, #selector(startSession(_:)))
            entry.representedObject = option.seconds.map { NSNumber(value: $0) }
            entry.indentationLevel = 1
        }
        if isActive { action("Остановить", #selector(stopSession)) }
        let lid = action("Затемнять экран во время сессии", #selector(toggleLidDisplay))
        lid.state = Settings.turnDisplayOffOnLidClose ? .on : .off
        menu.addItem(.separator())
        if let battery = PowerSources.battery() {
            info("Заряд \(battery.percent)%, \(battery.onBattery ? "от батареи" : "от розетки")")
        }
        switch controller.state {
        case .idle(last: .stopped(let reason)?): info("Последняя сессия: \(reason.text)")
        case .idle(last: .failed(let text)?): info(text)
        default: break
        }
        menu.addItem(.separator())
        let quit = action("Выйти из Sova", #selector(NSApplication.terminate(_:)))
        quit.target = NSApp
        quit.keyEquivalent = "q"
    }

    func menuWillOpen(_ menu: NSMenu) {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateCountdown() }
        }
        RunLoop.main.add(timer, forMode: .common)  // menus track in their own run loop mode
        ticker = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        ticker?.invalidate()
        ticker = nil
    }

    private func updateCountdown() {
        switch controller.state {
        case .active(let endsAt?):
            countdownItem?.title = "Не спит ещё \(countdownText(endsAt.timeIntervalSinceNow))"
        case .active(nil):
            countdownItem?.title = "Не спит, пока не остановлю"
        case .idle:
            countdownItem?.title = "Сон работает как обычно"
        }
    }

    @discardableResult
    private func info(_ title: String) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        entry.isEnabled = false
        menu.addItem(entry)
        return entry
    }

    @discardableResult
    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        entry.target = self
        menu.addItem(entry)
        return entry
    }

    @objc private func startSession(_ sender: NSMenuItem) {
        controller.start(seconds: (sender.representedObject as? NSNumber)?.doubleValue)
        // The menu is closed by now and a notification may be off, so a failure gets a window.
        if case .idle(last: .failed(let text)?) = controller.state {
            NSApp.activate()
            let alert = NSAlert()
            alert.messageText = "Sova не смогла включить режим"
            alert.informativeText = text
            alert.runModal()
        }
    }

    @objc private func stopSession() {
        controller.stop()
    }

    @objc private func toggleLidDisplay() {
        Settings.turnDisplayOffOnLidClose.toggle()
    }
}
