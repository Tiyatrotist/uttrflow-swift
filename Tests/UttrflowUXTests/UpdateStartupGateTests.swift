// Tests for when an automatic update check may start.
import Testing

@testable import UttrflowUX

/// Worth this much testing because the failure is silent: an early check competes with the model load.
@Suite("Updating: when a check may start")
struct UpdateStartupGateTests {
    @Test("not before anything has happened")
    func nothingKnownMeansNo() {
        var gate = UpdateStartupGate()
        let mayStart = gate.mayStartAutomatically()
        #expect(!mayStart)
    }

    @Test("not once configured alone, with the model still loading")
    func configuredAloneIsNotEnough() {
        var gate = UpdateStartupGate()
        gate.configure()
        let mayStart = gate.mayStartAutomatically()
        #expect(!mayStart)
    }

    @Test("not once settled alone, before the updater is configured")
    func settledAloneIsNotEnough() {
        var gate = UpdateStartupGate()
        gate.settle()
        let mayStart = gate.mayStartAutomatically()
        #expect(!mayStart)
    }

    @Test("once both configured and settled, in either order")
    func bothInEitherOrderStarts() {
        var configureFirst = UpdateStartupGate()
        configureFirst.configure()
        configureFirst.settle()
        let configureFirstMayStart = configureFirst.mayStartAutomatically()
        #expect(configureFirstMayStart)

        var settleFirst = UpdateStartupGate()
        settleFirst.settle()
        settleFirst.configure()
        let settleFirstMayStart = settleFirst.mayStartAutomatically()
        #expect(settleFirstMayStart)
    }

    @Test("only the first call after both conditions hold starts it")
    func onlyStartsOnce() {
        var gate = UpdateStartupGate()
        gate.configure()
        gate.settle()
        let first = gate.mayStartAutomatically()
        let second = gate.mayStartAutomatically()
        #expect(first)
        #expect(!second)
    }

    @Test("a manual check starts it before the model has settled")
    func manualCheckBypassesSettling() {
        var gate = UpdateStartupGate()
        gate.configure()
        let mayStart = gate.mayStartManually()
        #expect(mayStart)
    }

    @Test("a manual check configures the gate even if begin() never ran")
    func manualCheckConfiguresOnItsOwn() {
        var gate = UpdateStartupGate()
        let mayStart = gate.mayStartManually()
        #expect(mayStart)
        #expect(gate.isConfigured)
    }

    @Test("a manual check after an automatic start does not start it again")
    func manualCheckAfterAutomaticStartDoesNothing() {
        var gate = UpdateStartupGate()
        gate.configure()
        gate.settle()
        let automatic = gate.mayStartAutomatically()
        let manual = gate.mayStartManually()
        #expect(automatic)
        #expect(!manual)
    }

    @Test("an automatic start after a manual one does not start it again")
    func automaticStartAfterManualDoesNothing() {
        var gate = UpdateStartupGate()
        gate.configure()
        let manual = gate.mayStartManually()
        gate.settle()
        let automatic = gate.mayStartAutomatically()
        #expect(manual)
        #expect(!automatic)
    }
}
