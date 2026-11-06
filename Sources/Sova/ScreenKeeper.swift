import CoreGraphics
import Foundation
import IOKit.pwr_mgt
import SovaCore

/// Keeps the Mac unlocked and the screen dark during a session.
///
/// A display that goes to sleep locks the Mac at once (the system asks for the password
/// "immediately" and an app cannot change that), and a locked desktop cuts agents off.
/// So during a session the system's display sleep is held off with a power assertion, and the
/// screen is darkened here instead: built-in brightness goes to 0 when the lid is closed
/// or after the idle time from System Settings, and comes back on activity.
/// No polling outside a session.
@MainActor
final class ScreenKeeper {
    private let isSessionActive: @MainActor () -> Bool
    private let settingEnabled: @MainActor () -> Bool
    /// Test hook (`--idle-dim-seconds`); `nil` uses the system display sleep time.
    var idleThresholdOverride: TimeInterval?

    private var assertion: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
    private var timer: Timer?
    private var idleThreshold: TimeInterval?
    private var lidDim = false
    private var activityFloor = Date()
    private var dimmed = false
    private var savedBrightness: Float = 0

    private let brightnessFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Sova/brightness")

    init(isSessionActive: @escaping @MainActor () -> Bool, settingEnabled: @escaping @MainActor () -> Bool) {
        self.isSessionActive = isSessionActive
        self.settingEnabled = settingEnabled
    }

    /// At launch: a brightness file means a previous run died with the screen dimmed.
    func recoverLeftover() {
        guard let text = try? String(contentsOf: brightnessFile, encoding: .utf8) else { return }
        if let value = Float(text.trimmingCharacters(in: .whitespacesAndNewlines)), let id = Self.builtinDisplay() {
            Brightness.set(id, value)
        }
        try? FileManager.default.removeItem(at: brightnessFile)
    }

    /// The lid opened or something else proves a person is here: idle time starts over.
    func noteActivity() {
        activityFloor = Date()
    }

    /// Called whenever the session, the lid or the display setup may have changed.
    func update(lidDim: Bool) {
        self.lidDim = lidDim
        refresh()
    }

    func shutdown() {
        timer?.invalidate()
        timer = nil
        releaseAssertion()
        setDimmed(false)
    }

    private func refresh() {
        guard isSessionActive() else {
            shutdown()
            return
        }
        if assertion == IOPMAssertionID(kIOPMNullAssertionID) {
            holdAssertion()
            activityFloor = Date()
            idleThreshold = idleThresholdOverride ?? IdlePolicy.threshold(fromPmset: systemPowerSettings())
        }
        if timer == nil {
            let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            t.tolerance = 0.5
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
        let idle = min(Self.secondsSinceLastInput(), Date().timeIntervalSince(activityFloor))
        let idleDim = settingEnabled() && IdlePolicy.shouldDim(sessionActive: true, idleSeconds: idle, threshold: idleThreshold)
        setDimmed(lidDim || idleDim)
    }

    private func holdAssertion() {
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Sova: session keeps the Mac unlocked" as CFString,
            &assertion
        )
        if result != kIOReturnSuccess {
            assertion = IOPMAssertionID(kIOPMNullAssertionID)
            NSLog("Sova: cannot hold the display awake (0x%x); the screen may lock", result)
        }
    }

    private func releaseAssertion() {
        guard assertion != IOPMAssertionID(kIOPMNullAssertionID) else { return }
        IOPMAssertionRelease(assertion)
        assertion = IOPMAssertionID(kIOPMNullAssertionID)
    }

    private func setDimmed(_ wanted: Bool) {
        guard wanted != dimmed, let id = Self.builtinDisplay() else { return }
        if wanted {
            guard let current = Brightness.get(id) else { return }
            // Already black (the user's own choice): nothing to take and nothing to give back.
            guard current > 0.01 else { return }
            savedBrightness = current
            try? FileManager.default.createDirectory(at: brightnessFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? "\(current)\n".write(to: brightnessFile, atomically: true, encoding: .utf8)
            Brightness.set(id, 0)
            dimmed = true
        } else {
            Brightness.set(id, savedBrightness)
            try? FileManager.default.removeItem(at: brightnessFile)
            dimmed = false
        }
    }

    private func systemPowerSettings() -> String {
        (try? PmsetHold.runProcess("/usr/bin/pmset", ["-g"]).output) ?? ""
    }

    private static func secondsSinceLastInput() -> TimeInterval {
        // ~0 is "any input event" for CGEventSource.
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    private static func builtinDisplay() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }
}

/// Built-in display brightness through the private DisplayServices framework (the same call
/// the brightness keys use). If it is missing, dimming quietly does nothing and the screen stays lit.
@MainActor
private enum Brightness {
    typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static var warned = false

    static func get(_ id: CGDirectDisplayID) -> Float? {
        guard let handle, let symbol = dlsym(handle, "DisplayServicesGetBrightness") else {
            if !warned {
                warned = true
                NSLog("Sova: DisplayServicesGetBrightness is unavailable; the screen will not be dimmed")
            }
            return nil
        }
        var value: Float = 0
        guard unsafeBitCast(symbol, to: GetFn.self)(id, &value) == 0 else { return nil }
        return value
    }

    static func set(_ id: CGDirectDisplayID, _ value: Float) {
        guard let handle, let symbol = dlsym(handle, "DisplayServicesSetBrightness") else { return }
        if unsafeBitCast(symbol, to: SetFn.self)(id, value) != 0 {
            NSLog("Sova: cannot set the built-in brightness")
        }
    }
}
