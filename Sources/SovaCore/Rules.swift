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
    /// `nil` means no timer: only an outside event can end the session.
    case keep(recheckAt: Date?)
    case stop(StopReason)
}

/// One entry of the "Не давать спать" menu.
public struct DurationOption: Equatable, Sendable {
    public let label: String
    /// `nil` means "until stopped".
    public let seconds: TimeInterval?

    public init(label: String, seconds: TimeInterval?) {
        self.label = label
        self.seconds = seconds
    }
}

/// When a session has to end. Pure: no clock, no system calls.
public struct Rules: Sendable {
    public static let batteryFloor = 15
    /// How long "serious" heat is tolerated; "critical" is never tolerated.
    public static let seriousHeatGrace: TimeInterval = 300
    public static let durations: [DurationOption] = [
        .init(label: "30 минут", seconds: 1800),
        .init(label: "1 час", seconds: 3600),
        .init(label: "2 часа", seconds: 7200),
        .init(label: "4 часа", seconds: 14400),
        .init(label: "8 часов", seconds: 28800),
        .init(label: "12 часов", seconds: 43200),
        .init(label: "24 часа", seconds: 86400),
        .init(label: "Пока не остановлю", seconds: nil),
    ]

    /// `nil` means the session runs until it is stopped or a battery/heat rule fires.
    public let endsAt: Date?
    /// Since when the Mac has been "serious" or "critical" without a break.
    public private(set) var hotSince: Date?

    public init(endsAt: Date?) {
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
        if let endsAt, now >= endsAt { return .stop(.finished) }
        if thermal == .critical { return .stop(.overheated) }
        if let hotSince, now.timeIntervalSince(hotSince) >= Self.seriousHeatGrace { return .stop(.overheated) }
        if let battery, battery.onBattery, battery.percent < Self.batteryFloor {
            return .stop(.lowBattery(percent: battery.percent))
        }
        var next = endsAt
        if let hotSince {
            let heatDeadline = hotSince.addingTimeInterval(Self.seriousHeatGrace)
            next = next.map { min($0, heatDeadline) } ?? heatDeadline
        }
        return .keep(recheckAt: next)
    }
}

/// "2:41:05"
public func countdownText(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds.rounded(.up)))
    return String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
}
