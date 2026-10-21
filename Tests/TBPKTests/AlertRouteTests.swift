import XCTest
@testable import TBPK

final class AlertRouteTests: XCTestCase {
    private func device(_ id: UInt32, _ uid: String, builtIn: Bool, channels: Int = 2, sources: [UInt32] = []) -> AlertRoute.Candidate {
        AlertRoute.Candidate(id: id, uid: uid, isBuiltIn: builtIn, outputChannels: channels, sources: sources)
    }

    func testTheSpeakerIsTheBuiltInOutputWhateverTheSystemOutputIs() {
        let devices = [
            device(40, "AirPods:output", builtIn: false),
            device(50, "Teams", builtIn: false),
            device(112, "BuiltInSpeakerDevice", builtIn: true),
        ]
        XCTAssertEqual(AlertRoute.pickSpeaker(from: devices)?.uid, "BuiltInSpeakerDevice")
    }

    // Measured on a MacBook Pro: BuiltInHeadphoneOutputDevice (hdpn) is listed before BuiltInSpeakerDevice (ispk).
    func testTheHeadphoneJackListedBeforeTheSpeakersIsNotTheSpeaker() {
        let devices = [
            device(90, "BuiltInHeadphoneOutputDevice", builtIn: true, sources: [AlertRoute.headphoneSource]),
            device(112, "BuiltInSpeakerDevice", builtIn: true, sources: [AlertRoute.speakerSource]),
        ]
        XCTAssertEqual(AlertRoute.pickSpeaker(from: devices)?.uid, "BuiltInSpeakerDevice")
        XCTAssertEqual(AlertRoute.pickSpeaker(from: devices.reversed())?.uid, "BuiltInSpeakerDevice", "whatever the order")
    }

    func testAnOutputThatOnlyHasTheHeadphoneJackIsNeverPicked() {
        let jack = device(90, "BuiltInHeadphoneOutputDevice", builtIn: true, sources: [AlertRoute.headphoneSource])
        XCTAssertNil(AlertRoute.pickSpeaker(from: [jack]), "better no lift than the headphones")
    }

    func testOneOutputThatSwitchesBetweenSpeakersAndJackIsTheSpeaker() {
        let one = device(60, "BuiltInSpeakerDevice", builtIn: true, sources: [AlertRoute.headphoneSource, AlertRoute.speakerSource])
        XCTAssertEqual(AlertRoute.pickSpeaker(from: [one])?.uid, "BuiltInSpeakerDevice")
    }

    func testABuiltInOutputWithoutDataSourcesCountsButASpeakerSourceWinsOverIt() {
        let plain = device(61, "BuiltInSpeakerDevice", builtIn: true)
        let withSource = device(62, "Other", builtIn: true, sources: [AlertRoute.speakerSource])
        XCTAssertEqual(AlertRoute.pickSpeaker(from: [plain])?.uid, "BuiltInSpeakerDevice")
        XCTAssertEqual(AlertRoute.pickSpeaker(from: [plain, withSource])?.uid, "Other")
    }

    func testTheBuiltInMicrophoneIsNotASpeaker() {
        let devices = [device(111, "BuiltInMicrophoneDevice", builtIn: true, channels: 0), device(112, "BuiltInSpeakerDevice", builtIn: true)]
        XCTAssertEqual(AlertRoute.pickSpeaker(from: devices)?.uid, "BuiltInSpeakerDevice")
    }

    func testWithoutABuiltInOutputThereIsNoSpeakerAndNothingGetsRaised() {
        XCTAssertNil(AlertRoute.pickSpeaker(from: [device(40, "AirPods:output", builtIn: false)]))
        XCTAssertNil(AlertRoute.pickSpeaker(from: []))
    }

    func testTheDataSourceCodesAreTheFourLetterNames() {
        XCTAssertEqual(AlertRoute.speakerSource, UInt32(bigEndian: 0x6973706B).byteSwapped)
        XCTAssertEqual(String(bytes: [0x69, 0x73, 0x70, 0x6B], encoding: .ascii), "ispk")
        XCTAssertEqual(String(bytes: [0x68, 0x64, 0x70, 0x6E], encoding: .ascii), "hdpn")
        XCTAssertEqual(AlertRoute.headphoneSource, 0x6864_706E)
    }

    func testAMacOnItsSpeakersNeedsNoSwitch() {
        let both = [AlertRoute.headphoneSource, AlertRoute.speakerSource]
        XCTAssertEqual(AlertRoute.sourcePlan(current: AlertRoute.speakerSource, available: both, settable: true), .alreadySpeaker)
        XCTAssertEqual(AlertRoute.sourcePlan(current: AlertRoute.speakerSource, available: [AlertRoute.speakerSource], settable: false), .alreadySpeaker)
        XCTAssertEqual(AlertRoute.sourcePlan(current: nil, available: [], settable: false), .alreadySpeaker)
    }

    func testWiredHeadphonesInTheJackAreSwitchedToTheSpeakerForTheAlertAndRemembered() {
        let both = [AlertRoute.headphoneSource, AlertRoute.speakerSource]
        XCTAssertEqual(AlertRoute.sourcePlan(current: AlertRoute.headphoneSource, available: both, settable: true),
                       .switchToSpeaker(from: AlertRoute.headphoneSource))
    }

    func testWiredHeadphonesThatCannotBeSwitchedOffAreNeverLifted() {
        let both = [AlertRoute.headphoneSource, AlertRoute.speakerSource]
        XCTAssertEqual(AlertRoute.sourcePlan(current: AlertRoute.headphoneSource, available: both, settable: false), .headphonesLocked)
    }

    func testAnOutputThatOffersNoSpeakerSourceIsLeftAlone() {
        XCTAssertEqual(AlertRoute.sourcePlan(current: AlertRoute.headphoneSource, available: [AlertRoute.headphoneSource], settable: true),
                       .alreadySpeaker)
    }

    func testTheRealMacHasABuiltInSpeakerThatIsNotNecessarilyTheSystemOutput() throws {
        guard let speaker = AlertRoute.speaker() else { throw XCTSkip("this Mac has no built-in output") }
        XCTAssertTrue(AudioOutput.isBuiltIn(speaker.device))
        XCTAssertGreaterThan(AudioOutput.outputChannelCount(of: speaker.device), 0)
        XCTAssertFalse(speaker.uid.isEmpty)
    }

    func testASoundIsSentToTheOutputItIsToldAndNotTheSystemDefault() throws {
        let sound = try XCTUnwrap(AlertSound(name: "Glass").play(volume: 0, on: "BuiltInSpeakerDevice"))
        defer { sound.stop() }
        XCTAssertEqual(sound.playbackDeviceIdentifier, "BuiltInSpeakerDevice")
        let followed = try XCTUnwrap(AlertSound(name: "Glass").play(volume: 0))
        defer { followed.stop() }
        XCTAssertNil(followed.playbackDeviceIdentifier)
    }
}
