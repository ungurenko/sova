import Foundation
import Testing
@testable import SovaCore

private final class FakeHold: SleepHold {
    var engaged = false
    var engageError: HoldError?
    var releaseError: HoldError?

    func engage(until: Date) throws {
        if let engageError { throw engageError }
        engaged = true
    }
    func release() throws {
        if let releaseError { throw releaseError }
        engaged = false
    }
    func recoverLeftover() {}
}

@MainActor
private final class Rig {
    let hold = FakeHold()
    var clock = Date(timeIntervalSince1970: 1_000_000)
    var battery: Battery? = Battery(percent: 80, onBattery: true)
    var thermal = ProcessInfo.ThermalState.nominal
    var notices: [String] = []
    lazy var controller = SessionController(
        hold: hold, now: { self.clock }, battery: { self.battery }, thermal: { self.thermal },
        notify: { self.notices.append($0) }
    )
}

@MainActor @Suite struct ControllerTests {
    @Test func batteryFallingBelowTheFloorEndsTheSessionAndTellsTheUser() {
        let rig = Rig()
        rig.controller.start(seconds: 3600)
        #expect(rig.hold.engaged)
        rig.battery = Battery(percent: 14, onBattery: true)
        rig.controller.conditionsChanged()
        #expect(!rig.hold.engaged)
        #expect(rig.controller.state == .idle(last: .stopped(.lowBattery(percent: 14))))
        #expect(rig.notices.count == 1)
    }

    @Test func startingWithAnAlreadyEmptyBatteryEndsAtOnce() {
        let rig = Rig()
        rig.battery = Battery(percent: 9, onBattery: true)
        rig.controller.start(seconds: 3600)
        #expect(!rig.hold.engaged)
        #expect(rig.controller.state == .idle(last: .stopped(.lowBattery(percent: 9))))
    }

    @Test func failedReplacementEndsTheRunningSessionInsteadOfLeavingItHalfAlive() {
        let rig = Rig()
        rig.controller.start(seconds: 3600)
        rig.hold.engageError = HoldError("pmset вернул 1.")
        rig.controller.start(seconds: 7200)
        #expect(rig.controller.state == .idle(last: .failed("pmset вернул 1.")))
        #expect(!rig.hold.engaged)
        // The old timer must be gone: time passing may not announce the end of a session nobody sees.
        rig.clock = rig.clock.addingTimeInterval(3600)
        rig.controller.conditionsChanged()
        #expect(rig.notices.isEmpty)
    }

    @Test func failedStartStaysIdleWithTheReason() {
        let rig = Rig()
        rig.hold.engageError = HoldError("Нет разрешения")
        rig.controller.start(seconds: 3600)
        #expect(rig.controller.state == .idle(last: .failed("Нет разрешения")))
    }

    @Test func manualStopAndQuitGiveSleepBackQuietly() {
        let rig = Rig()
        rig.controller.start(seconds: 3600)
        rig.controller.stop()
        #expect(!rig.hold.engaged)
        rig.controller.start(seconds: 3600)
        rig.controller.shutdown()
        #expect(!rig.hold.engaged)
        #expect(rig.notices.isEmpty)
    }

    @Test func failureToGiveSleepBackIsReportedLoudly() {
        let rig = Rig()
        rig.controller.start(seconds: 3600)
        rig.hold.releaseError = HoldError("pmset вернул 1.")
        rig.controller.stop()
        guard case .idle(last: .failed(let text)) = rig.controller.state else {
            Issue.record("expected a failed outcome")
            return
        }
        #expect(text.contains("Сторож"))
        #expect(rig.notices.count == 1)
    }
}
