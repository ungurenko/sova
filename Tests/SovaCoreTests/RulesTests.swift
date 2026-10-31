import Foundation
import Testing
@testable import SovaCore

@Suite struct RulesTests {
    let start = Date(timeIntervalSince1970: 1_000_000)
    var end: Date { start.addingTimeInterval(3600) }

    @Test func keepsWithinTimeAndAsksToLookAgainAtTheEnd() {
        let rules = Rules(endsAt: end)
        let v = rules.verdict(at: start.addingTimeInterval(60), battery: Battery(percent: 80, onBattery: true), thermal: .nominal)
        #expect(v == .keep(recheckAt: end))
    }

    @Test func finishesWhenTimeIsUp() {
        let rules = Rules(endsAt: end)
        #expect(rules.verdict(at: end, battery: nil, thermal: .nominal) == .stop(.finished))
    }

    @Test func batteryFloorIsStrictlyBelowFifteenAndOnlyOffCharger() {
        let rules = Rules(endsAt: end)
        let t = start.addingTimeInterval(60)
        #expect(rules.verdict(at: t, battery: Battery(percent: 15, onBattery: true), thermal: .nominal) == .keep(recheckAt: end))
        #expect(rules.verdict(at: t, battery: Battery(percent: 14, onBattery: true), thermal: .nominal) == .stop(.lowBattery(percent: 14)))
        #expect(rules.verdict(at: t, battery: Battery(percent: 5, onBattery: false), thermal: .nominal) == .keep(recheckAt: end))
        #expect(rules.verdict(at: t, battery: nil, thermal: .nominal) == .keep(recheckAt: end)) // a desktop Mac has no battery
    }

    @Test func criticalHeatStopsAtOnce() {
        let rules = Rules(endsAt: end)
        #expect(rules.verdict(at: start, battery: nil, thermal: .critical) == .stop(.overheated))
    }

    @Test func seriousHeatIsToleratedForFiveMinutesThenStops() {
        var rules = Rules(endsAt: end)
        rules.thermalChanged(.serious, at: start)
        let deadline = start.addingTimeInterval(300)
        #expect(rules.verdict(at: start.addingTimeInterval(299), battery: nil, thermal: .serious) == .keep(recheckAt: deadline))
        #expect(rules.verdict(at: deadline, battery: nil, thermal: .serious) == .stop(.overheated))
    }

    @Test func heatThatEasesResetsTheFiveMinutes() {
        var rules = Rules(endsAt: end)
        rules.thermalChanged(.serious, at: start)
        rules.thermalChanged(.fair, at: start.addingTimeInterval(240))
        rules.thermalChanged(.serious, at: start.addingTimeInterval(400))
        let v = rules.verdict(at: start.addingTimeInterval(600), battery: nil, thermal: .serious)
        #expect(v == .keep(recheckAt: start.addingTimeInterval(700)))
    }

    @Test func countdownIsHoursMinutesSecondsAndRoundsUp() {
        #expect(countdownText(9665) == "2:41:05")
        #expect(countdownText(0.4) == "0:00:01")
        #expect(countdownText(-5) == "0:00:00")
    }
}
