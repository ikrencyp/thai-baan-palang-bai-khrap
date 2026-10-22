import XCTest
@testable import TBPK

final class PowerIntensityTests: XCTestCase {
    func testAnIdleLaptopIsCalmAndAFlatOutOneIsFull() {
        XCTAssertEqual(PowerIntensity.level(watts: 3), 0)
        XCTAssertEqual(PowerIntensity.level(watts: PowerIntensity.idleWatts), 0)
        XCTAssertEqual(PowerIntensity.level(watts: PowerIntensity.flatOutWatts), 1)
        XCTAssertEqual(PowerIntensity.level(watts: 140), 1)
    }

    func testMoreWattsNeverMeansALowerLevel() {
        let levels = stride(from: 0.0, through: 80, by: 2).map { PowerIntensity.level(watts: $0) }
        XCTAssertEqual(levels, levels.sorted())
    }

    func testOneSpikeOnlyMovesHalfWayAndTenthsAreKept() {
        XCTAssertEqual(PowerIntensity.smoothed(previous: 0.2, next: 1), 0.6, accuracy: 1e-9)
        XCTAssertEqual(PowerIntensity.quantised(0.449), 0.4)
        XCTAssertEqual(PowerIntensity.quantised(0.451), 0.5)
        XCTAssertEqual(PowerIntensity.quantised(2), 1)
        XCTAssertEqual(PowerIntensity.quantised(-1), 0)
    }
}

final class SystemPowerTests: XCTestCase {
    func testTheTelemetryLoadIsReadInWatts() {
        let properties: [String: Any] = ["PowerTelemetryData": ["SystemLoad": 38251]]
        XCTAssertEqual(SystemPower.watts(from: properties) ?? 0, 38.251, accuracy: 1e-9)
    }

    func testWithoutTelemetryTheDischargeCurrentTimesVoltageIsUsed() {
        let properties: [String: Any] = ["InstantAmperage": -2000, "Voltage": 12000]
        XCTAssertEqual(SystemPower.watts(from: properties) ?? 0, 24, accuracy: 1e-9)
    }

    func testChargingWithNoTelemetryAndAnEmptyDictionaryGiveNoAnswer() {
        XCTAssertNil(SystemPower.watts(from: ["InstantAmperage": 1500, "Voltage": 12000]))
        XCTAssertNil(SystemPower.watts(from: [:]))
        XCTAssertNil(SystemPower.watts(from: ["PowerTelemetryData": ["SystemLoad": 0]]))
    }
}

@MainActor
final class PowerDrawMeterTests: XCTestCase {
    func testTheFirstReadingIsShownAndLaterOnesAreSmoothed() {
        var watts = 60.0
        let meter = PowerDrawMeter(read: { watts })
        var changes = 0
        meter.onChange = { changes += 1 }
        meter.sampleNow()
        XCTAssertEqual(meter.level, 1)
        watts = 8
        meter.sampleNow()
        XCTAssertEqual(meter.level, 0.5)
        XCTAssertEqual(changes, 2)
    }

    func testAnUnreadableMacKeepsTheDefaultAndNeverNotifies() {
        let meter = PowerDrawMeter(read: { nil })
        var changes = 0
        meter.onChange = { changes += 1 }
        meter.sampleNow()
        XCTAssertEqual(meter.level, PowerIntensity.unknown)
        XCTAssertEqual(changes, 0)
    }

    func testNoTimerRunsWithoutAHeartbeat() {
        var reads = 0
        let meter = PowerDrawMeter(read: { reads += 1; return 30 })
        meter.run(every: nil)
        XCTAssertEqual(reads, 0)
        meter.run(every: 60)
        XCTAssertEqual(reads, 1, "one reading when it starts, then the slow timer")
        meter.run(every: nil)
    }
}

final class HeartbeatIntensityTests: XCTestCase {
    func testTheBeatIsFasterAndHarderTheMoreTheMacWorks() {
        XCTAssertGreaterThan(Heartbeat.gap(base: 3.6, intensity: 0), Heartbeat.gap(base: 3.6, intensity: 1))
        XCTAssertLessThan(Heartbeat.swell(intensity: 0), Heartbeat.swell(intensity: 1))
        XCTAssertEqual(Heartbeat.swell(intensity: 1), 0.34, accuracy: 1e-9, "flat out is close to the old fixed thump")
    }

    func testNoBeatIsFasterThanTheNaturalPeriodAndOutOfRangeIsClamped() {
        XCTAssertEqual(Heartbeat.gap(base: Heartbeat.period, intensity: 1), Heartbeat.period)
        XCTAssertEqual(Heartbeat.gap(base: 3.6, intensity: 9), Heartbeat.gap(base: 3.6, intensity: 1))
        XCTAssertEqual(Heartbeat.swell(intensity: -3), Heartbeat.swell(intensity: 0))
    }

    func testOnlyAPlanWithAHeartbeatReadsThePower() {
        XCTAssertNil(EnergyPlan.saver.meterEvery)
        XCTAssertEqual(EnergyPlan.full.meterEvery, 2)
        XCTAssertEqual(EnergyPlan.standard.meterEvery, 4)
    }
}
