import Testing
@testable import SovaCore

@Suite struct LidPolicyTests {
    @Test func displayIsDimmedOnlyWhenEveryConditionHolds() {
        #expect(LidPolicy.shouldDimDisplay(
            sessionActive: true, turnOffDisplayOnLidClose: true, lidClosed: true, hasExternalDisplay: false
        ))
        #expect(!LidPolicy.shouldDimDisplay(
            sessionActive: false, turnOffDisplayOnLidClose: true, lidClosed: true, hasExternalDisplay: false
        ))
        #expect(!LidPolicy.shouldDimDisplay(
            sessionActive: true, turnOffDisplayOnLidClose: false, lidClosed: true, hasExternalDisplay: false
        ))
        #expect(!LidPolicy.shouldDimDisplay(
            sessionActive: true, turnOffDisplayOnLidClose: true, lidClosed: false, hasExternalDisplay: false
        ))
        #expect(!LidPolicy.shouldDimDisplay(
            sessionActive: true, turnOffDisplayOnLidClose: true, lidClosed: true, hasExternalDisplay: true
        ))
    }
}
