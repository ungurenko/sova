import Testing
@testable import SovaCore

@Suite struct IdlePolicyTests {
    @Test func screenGoesDarkOnlyInSessionAfterTheIdleTime() {
        #expect(IdlePolicy.shouldDim(sessionActive: true, idleSeconds: 1800, threshold: 1800))
        #expect(!IdlePolicy.shouldDim(sessionActive: true, idleSeconds: 1799, threshold: 1800))
        #expect(!IdlePolicy.shouldDim(sessionActive: false, idleSeconds: 5000, threshold: 1800))
        #expect(!IdlePolicy.shouldDim(sessionActive: true, idleSeconds: 5000, threshold: nil))
    }

    @Test func thresholdComesFromTheSystemDisplaySleepTime() {
        let output = "System-wide power settings:\n SleepDisabled\t\t0\nCurrently in use:\n sleep                1\n displaysleep         30\n"
        #expect(IdlePolicy.threshold(fromPmset: output) == 1800)
        #expect(IdlePolicy.threshold(fromPmset: " displaysleep 0\n") == nil)  // never sleeps: never dim
        #expect(IdlePolicy.threshold(fromPmset: "garbage") == IdlePolicy.fallback)
    }
}
