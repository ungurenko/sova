import Foundation
import IOKit.ps
import SovaCore

/// Battery level and charger state. Event driven: nothing runs until macOS reports a change.
enum PowerSources {
    /// nil on a Mac without a battery.
    static func battery() -> Battery? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let percent = d[kIOPSCurrentCapacityKey] as? Int else { continue }
            let onBattery = d[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue
            return Battery(percent: percent, onBattery: onBattery)
        }
        return nil
    }

    /// Calls `handler` on the main thread whenever the level or the charger state changes.
    @MainActor
    static func observe(_ handler: @escaping @MainActor () -> Void) {
        let box = Unmanaged.passRetained(HandlerBox(handler)).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let box = Unmanaged<HandlerBox>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { box.handler() }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, box)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }
}

private final class HandlerBox {
    let handler: @MainActor () -> Void
    init(_ handler: @escaping @MainActor () -> Void) { self.handler = handler }
}
