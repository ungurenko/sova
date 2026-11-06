import Foundation
import Testing
@testable import SovaCore

/// Stands in for sudo and pmset and remembers what the journal looked like at each call.
private final class FakeSystem {
    let journal = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString).appendingPathComponent("session")
    var sleepDisabled = false
    var failingValue: String?        // "1" or "0": that pmset command exits with 1
    var ignoresTheSwitch = false     // exits 0 but changes nothing
    var calls: [String] = []
    var journalExistedAtSetting: [String: Bool] = [:]

    var journalExists: Bool { FileManager.default.fileExists(atPath: journal.path) }

    func run(_ tool: String, _ args: [String]) throws -> (status: Int32, output: String) {
        if tool == "/usr/bin/pmset" {
            return (0, "System-wide power settings:\n SleepDisabled\t\t\(sleepDisabled ? 1 : 0)\n")
        }
        let value = args.last!
        calls.append(value)
        journalExistedAtSetting[value] = journalExists
        if failingValue == value { return (1, "sudo: a password is required") }
        if !ignoresTheSwitch { sleepDisabled = value == "1" }
        return (0, "")
    }

    func hold() -> PmsetHold { PmsetHold(journal: journal, run: run) }
}

@Suite struct SleepHoldTests {
    let end = Date(timeIntervalSince1970: 2_000_000)

    @Test func journalIsWrittenBeforeSleepIsSwitchedOffAndRemovedAfterItComesBack() throws {
        let system = FakeSystem()
        let hold = system.hold()
        try hold.engage(until: end)
        #expect(system.journalExistedAtSetting["1"] == true)
        #expect(try String(contentsOf: system.journal, encoding: .utf8) == "2000000\n")
        #expect(system.sleepDisabled)
        try hold.release()
        #expect(!system.sleepDisabled)
        #expect(!system.journalExists)
    }

    @Test func failedSwitchOnLeavesNoJournalAndReportsMissingPermission() {
        let system = FakeSystem()
        system.failingValue = "1"
        #expect(throws: HoldError.self) { try system.hold().engage(until: end) }
        #expect(!system.journalExists)
        #expect(!system.sleepDisabled)
    }

    @Test func failedSwitchOnWhileSleepIsStillOffMarksTheJournalExpiredForTheGuard() throws {
        let system = FakeSystem()
        system.sleepDisabled = true   // an earlier session could not give sleep back
        system.failingValue = "1"
        #expect(throws: HoldError.self) { try system.hold().engage(until: end) }
        #expect(try String(contentsOf: system.journal, encoding: .utf8) == "0\n")
    }

    @Test func switchThatMacOSIgnoredIsNotReportedAsEngaged() {
        let system = FakeSystem()
        system.ignoresTheSwitch = true
        #expect(throws: HoldError.self) { try system.hold().engage(until: end) }
        #expect(system.calls == ["1", "0"])
    }

    @Test func failedReleaseKeepsTheJournalAndMarksItExpiredForTheGuard() throws {
        let system = FakeSystem()
        let hold = system.hold()
        try hold.engage(until: end)
        system.failingValue = "0"
        #expect(throws: HoldError.self) { try hold.release() }
        #expect(system.sleepDisabled)
        #expect(try String(contentsOf: system.journal, encoding: .utf8) == "0\n")
    }

    @Test func leftoverJournalFromADeadRunGetsSleepBack() throws {
        let system = FakeSystem()
        try system.hold().engage(until: end)
        // A new run starts: sleep is still off and the journal is still there.
        system.hold().recoverLeftover()
        #expect(!system.sleepDisabled)
        #expect(!system.journalExists)
    }

    @Test func unlimitedSessionIsWrittenToTheJournalAsAFarFutureEnd() throws {
        let system = FakeSystem()
        try system.hold().engage(until: nil)
        #expect(try String(contentsOf: system.journal, encoding: .utf8) == "253402300799\n")
        #expect(system.sleepDisabled)
    }

}
