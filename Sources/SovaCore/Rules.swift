import Foundation

public enum StopReason: Equatable, Sendable {
    case finished
    case manual
    case lowBattery(percent: Int)
    case overheated
    case quit

    /// Shown in the menu and in the notification.
    public var text: String {
        switch self {
        case .finished: "время сессии вышло"
        case .manual: "остановлена вручную"
        case .lowBattery(let percent): "заряд упал до \(percent)%, ниже \(Rules.batteryFloor)%"
        case .overheated: "Мак перегрелся"
        case .quit: "программа закрыта"
        }
    }
}

public struct Battery: Equatable, Sendable {
    public var percent: Int
    public var onBattery: Bool

    public init(percent: Int, onBattery: Bool) {
        self.percent = percent
        self.onBattery = onBattery
    }
}

public enum Verdict: Equatable, Sendable {
    /// Keep going; look again at `recheckAt` even if nothing else happens.
    case keep(recheckAt: Date)
    case stop(StopReason)
}

/// When a session has to end. Pure: no clock, no system calls.
public struct Rules: Sendable {
    public static let batteryFloor = 15
    /// How long "serious" heat is tolerated; "critical" is never tolerated.
    public static let seriousHeatGrace: TimeInterval = 300
    public static let durations: [(label: String, seconds: TimeInterval)] = [
        ("30 минут", 1800), ("1 час", 3600), ("2 часа", 7200), ("4 часа", 14400), ("8 часов", 28800),
    ]

    public let endsAt: Date
    /// Since when the Mac has been "serious" or "critical" without a break.
    public private(set) var hotSince: Date?

    public init(endsAt: Date) {
        self.endsAt = endsAt
    }

    public mutating func thermalChanged(_ state: ProcessInfo.ThermalState, at now: Date) {
        switch state {
        case .serious, .critical:
            if hotSince == nil { hotSince = now }
        default:
            hotSince = nil
        }
    }

    public func verdict(at now: Date, battery: Battery?, thermal: ProcessInfo.ThermalState) -> Verdict {
        if now >= endsAt { return .stop(.finished) }
        if thermal == .critical { return .stop(.overheated) }
        if let hotSince, now.timeIntervalSince(hotSince) >= Self.seriousHeatGrace { return .stop(.overheated) }
        if let battery, battery.onBattery, battery.percent < Self.batteryFloor {
            return .stop(.lowBattery(percent: battery.percent))
        }
        var next = endsAt
        if let hotSince { next = min(next, hotSince.addingTimeInterval(Self.seriousHeatGrace)) }
        return .keep(recheckAt: next)
    }
}

/// "2:41:05"
public func countdownText(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds.rounded(.up)))
    return String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
}
