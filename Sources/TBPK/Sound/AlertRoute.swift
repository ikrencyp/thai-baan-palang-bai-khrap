import CoreAudio
import Foundation

// The alert is for someone who is not looking at the Mac, so it plays on the Mac's own speaker, never in the
// headphones or the speaker the Mac last connected to. The system's chosen output is not changed: the sound is
// sent to the built-in device directly, and only that device's volume is lifted (and put back afterwards).
enum AlertRoute {
    static let speakerSource: UInt32 = 0x6973_706B   // 'ispk'
    static let headphoneSource: UInt32 = 0x6864_706E // 'hdpn'

    struct Candidate: Equatable {
        let id: AudioDeviceID
        let uid: String
        let isBuiltIn: Bool
        let outputChannels: Int
        // The output's data sources: 'ispk' for the speakers, 'hdpn' for the headphone jack. Empty when it has none.
        var sources: [UInt32] = []
    }

    struct Speaker: Equatable {
        let device: AudioDeviceID
        let uid: String
    }

    // What to do about the built-in output's data source.
    enum SourcePlan: Equatable {
        case alreadySpeaker
        case switchToSpeaker(from: UInt32)
        // Wired headphones are in the jack and the Mac will not switch: the alert would still reach the ears.
        case headphonesLocked
    }

    // Newer Macs list the speakers and the headphone jack as two separate built-in outputs, so "built-in" is not enough:
    // the speaker is the one that can play on the speakers. A built-in output with no data sources at all (a desktop Mac)
    // still counts; one that only has the headphone jack never does.
    static func pickSpeaker(from candidates: [Candidate]) -> Candidate? {
        let outputs = candidates.filter { $0.isBuiltIn && $0.outputChannels > 0 }
        return outputs.first { $0.sources.contains(speakerSource) } ?? outputs.first { $0.sources.isEmpty }
    }

    static func sourcePlan(current: UInt32?, available: [UInt32], settable: Bool) -> SourcePlan {
        guard let current, current == headphoneSource, available.contains(speakerSource) else { return .alreadySpeaker }
        return settable ? .switchToSpeaker(from: current) : .headphonesLocked
    }

    static func speaker() -> Speaker? {
        let candidates = AudioOutput.allDevices().compactMap { id -> Candidate? in
            AudioOutput.uid(of: id).map {
                Candidate(id: id, uid: $0, isBuiltIn: AudioOutput.isBuiltIn(id), outputChannels: AudioOutput.outputChannelCount(of: id),
                          sources: AudioOutput.dataSources(of: id))
            }
        }
        return pickSpeaker(from: candidates).map { Speaker(device: $0.id, uid: $0.uid) }
    }

    static func plan(for speaker: Speaker) -> SourcePlan {
        sourcePlan(current: AudioOutput.dataSource(of: speaker.device), available: AudioOutput.dataSources(of: speaker.device),
                   settable: AudioOutput.isDataSourceSettable(speaker.device))
    }
}
