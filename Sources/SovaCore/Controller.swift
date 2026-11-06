import Foundation

/// The state of the session. One timer, armed only while a session is active.
@MainActor
public final class SessionController {
    public enum Outcome: Equatable {
        case stopped(StopReason)
        case failed(String)
    }

    public enum State: Equatable {
        case idle(last: Outcome?)
        case active(endsAt: Date?)

        public var isActive: Bool {
            if case .active = self { true } else { false }
        }
    }

    public private(set) var state: State = .idle(last: nil)
    /// Called after every change of `state`.
    public var onChange: () -> Void = {}

    private let hold: SleepHold
    private let now: () -> Date
    private let battery: () -> Battery?
    private let thermal: () -> ProcessInfo.ThermalState
    private let notify: (String) -> Void
    private var rules: Rules?
    private var timer: Timer?

    public init(
        hold: SleepHold,
        now: @escaping () -> Date,
        battery: @escaping () -> Battery?,
        thermal: @escaping () -> ProcessInfo.ThermalState,
        notify: @escaping (String) -> Void
    ) {
        self.hold = hold
        self.now = now
        self.battery = battery
        self.thermal = thermal
        self.notify = notify
    }

    /// Starts a session; one already running is replaced, its countdown starts over.
    /// `nil` seconds means the session runs until it is stopped or a battery/heat rule fires.
    public func start(seconds: TimeInterval?) {
        let wasActive = rules != nil
        let t = now()
        var new = Rules(endsAt: seconds.map { t.addingTimeInterval($0) })
        new.thermalChanged(thermal(), at: t)
        do {
            try hold.engage(until: new.endsAt)
        } catch {
            // The old session, if any, is over too: drop its rules and timer, and try to give sleep back.
            rules = nil
            timer?.invalidate()
            timer = nil
            if wasActive { try? hold.release() }
            finish(.failed(error.localizedDescription))
            return
        }
        rules = new
        state = .active(endsAt: new.endsAt)
        onChange()
        conditionsChanged()
    }

    public func stop() {
        guard rules != nil else { return }
        end(.manual)
    }

    /// The program is closing: give sleep back before it goes.
    public func shutdown() {
        guard rules != nil else { return }
        end(.quit)
    }

    /// Battery, temperature or wake-up news, or the timer: look at the rules again.
    public func conditionsChanged() {
        guard var current = rules else { return }
        let t = now()
        let heat = thermal()
        current.thermalChanged(heat, at: t)
        rules = current
        switch current.verdict(at: t, battery: battery(), thermal: heat) {
        case .stop(let reason): end(reason)
        case .keep(let recheckAt):
            if let recheckAt {
                arm(at: recheckAt)
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
    }

    private func end(_ reason: StopReason) {
        rules = nil
        timer?.invalidate()
        timer = nil
        do {
            try hold.release()
            if reason != .manual, reason != .quit {
                notify("Сессия закончилась: \(reason.text). Сон снова работает как обычно.")
            }
            finish(.stopped(reason))
        } catch {
            let text = "Не удалось вернуть сон: \(error.localizedDescription) Сторож вернёт его в течение минуты."
            notify(text)
            finish(.failed(text))
        }
    }

    private func finish(_ outcome: Outcome) {
        state = .idle(last: outcome)
        onChange()
    }

    private func arm(at date: Date) {
        timer?.invalidate()
        let next = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.conditionsChanged() }
        }
        next.tolerance = 1
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }
}
