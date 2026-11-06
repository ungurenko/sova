import CoreGraphics
import Foundation
import IOKit
import IOKit.pwr_mgt
import SovaCore

/// Watches the lid and tells ScreenKeeper whether the built-in display must be dark because
/// the lid is closed during a session. `disablesleep` keeps the Mac awake but leaves the display
/// on; the display is dimmed to black, not put to sleep, because a sleeping display locks the Mac.
/// No root, no polling.
@MainActor
final class LidMonitor {
    /// kIOPMMessageClamshellStateChange from IOPM.h. The C macro is not imported into Swift,
    /// so the value is built the same way: err_system(0x38) | err_sub(13) | 0x100.
    private static let clamshellStateChange: natural_t =
        (UInt32(0x38) << 26) | (UInt32(13) << 14) | 0x100

    private let isSessionActive: @MainActor () -> Bool
    private let settingEnabled: @MainActor () -> Bool
    private let screenKeeper: ScreenKeeper
    private var rootDomain: io_service_t = IO_OBJECT_NULL
    private var notificationPort: IONotificationPortRef?
    private var notifier: io_object_t = IO_OBJECT_NULL

    init(
        isSessionActive: @escaping @MainActor () -> Bool,
        settingEnabled: @escaping @MainActor () -> Bool,
        screenKeeper: ScreenKeeper
    ) {
        self.isSessionActive = isSessionActive
        self.settingEnabled = settingEnabled
        self.screenKeeper = screenKeeper
    }

    /// Subscribes to the clamshell notification. A failure is logged; Sova keeps working
    /// without lid dimming, as it did before.
    func start() {
        guard rootDomain == IO_OBJECT_NULL else { return }
        rootDomain = Self.findRootDomain()
        guard rootDomain != IO_OBJECT_NULL else {
            NSLog("Sova: IOPMrootDomain is unavailable; the display will stay on with the lid closed")
            return
        }
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            IOObjectRelease(rootDomain)
            rootDomain = IO_OBJECT_NULL
            NSLog("Sova: cannot create an IOKit notification port")
            return
        }
        notificationPort = port
        guard let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() else {
            IONotificationPortDestroy(port)
            notificationPort = nil
            IOObjectRelease(rootDomain)
            rootDomain = IO_OBJECT_NULL
            NSLog("Sova: cannot get the IOKit run loop source")
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let result = IOServiceAddInterestNotification(
            port,
            rootDomain,
            kIOGeneralInterest,
            { refcon, _, messageType, messageArgument in
                guard let refcon else { return }
                let monitor = Unmanaged<LidMonitor>.fromOpaque(refcon).takeUnretainedValue()
                MainActor.assumeIsolated {
                    monitor.handle(messageType: messageType, messageArgument: messageArgument)
                }
            },
            refcon,
            &notifier
        )
        guard result == KERN_SUCCESS else {
            IONotificationPortDestroy(port)
            notificationPort = nil
            IOObjectRelease(rootDomain)
            rootDomain = IO_OBJECT_NULL
            NSLog("Sova: cannot subscribe to clamshell notifications (0x%x)", result)
            return
        }
    }

    /// Checks the current state: used at session start, on wake-up and when the setting changes.
    func evaluate() {
        applyLidState(lidClosed: isLidClosed() == true)
    }

    private func handle(messageType: natural_t, messageArgument: UnsafeMutableRawPointer?) {
        guard messageType == Self.clamshellStateChange else { return }
        guard let messageArgument else {
            evaluate()  // no bitfield: read AppleClamshellState instead
            return
        }
        let bits = UInt(bitPattern: messageArgument)
        let closed = (bits & UInt(kClamshellStateBit)) != 0
        if !closed { screenKeeper.noteActivity() }  // opening the lid is not an input event
        applyLidState(lidClosed: closed)
    }

    private func applyLidState(lidClosed: Bool) {
        screenKeeper.update(lidDim: LidPolicy.shouldDimDisplay(
            sessionActive: isSessionActive(),
            turnOffDisplayOnLidClose: settingEnabled(),
            lidClosed: lidClosed,
            hasExternalDisplay: Self.hasExternalDisplay()
        ))
    }

    private func isLidClosed() -> Bool? {
        guard rootDomain != IO_OBJECT_NULL,
              let value = IORegistryEntryCreateCFProperty(
                  rootDomain, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0
              )?.takeRetainedValue(),
              CFGetTypeID(value) == CFBooleanGetTypeID()
        else { return nil }
        return CFBooleanGetValue((value as! CFBoolean))
    }

    private static func findRootDomain() -> io_service_t {
        let matched = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        if matched != IO_OBJECT_NULL { return matched }
        return IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/IOResources/IOPowerConnection/IOPMrootDomain")
    }

    private static func hasExternalDisplay() -> Bool {
        guard let displays = activeDisplays() else {
            NSLog("Sova: cannot read the display list; assuming no external display")
            return false
        }
        return displays.contains { CGDisplayIsBuiltin($0) == 0 }
    }

    private static func activeDisplays() -> [CGDirectDisplayID]? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success else { return nil }
        guard count > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return nil }
        return Array(displays.prefix(Int(count)))
    }
}
