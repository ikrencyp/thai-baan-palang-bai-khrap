import AppKit

// Every alert, and the test play button, goes out of the Mac's own speaker (see AlertRoute) and leaves the
// system's output, the speaker's volume and its data source as they were.
@MainActor
enum AttentionSound {
    private static let spacing: TimeInterval = 0.35

    private static var isPlaying = false

    static var alertSoundLength: TimeInterval { AlertSound.stored.duration }

    private static var preview: NSSound?
    private static var previewRestore: Task<Void, Never>?

    // A preview replaces the one still playing, so flipping through long clips never stacks them.
    static func playOnce() {
        preview?.stop()
        previewRestore?.cancel()
        let sound = AlertSound.stored
        preview = sound.play(on: prepareSpeaker())
        previewRestore = Task {
            try? await Task.sleep(nanoseconds: AttentionSound.nanoseconds(sound.duration))
            guard !Task.isCancelled, !isPlaying else { return }
            AlertVolumeLift.restorePending()
        }
    }

    static func play() {
        guard !isPlaying else { return }
        isPlaying = true
        let speaker = prepareSpeaker()
        let sound = AlertSound.stored
        let plays = AlertBeepCount.stored(for: sound).rawValue
        Task {
            for beat in 1...plays {
                sound.play(on: speaker)
                if beat < plays {
                    try? await Task.sleep(nanoseconds: AttentionSound.nanoseconds(spacing))
                }
            }
            try? await Task.sleep(nanoseconds: AttentionSound.nanoseconds(sound.duration))
            AlertVolumeLift.restorePending()
            isPlaying = false
        }
    }

    // Lifts the built-in speaker and returns its UID. Without a built-in output nothing is lifted and the sound
    // follows the system's output: the app never raises a device it did not pick.
    private static func prepareSpeaker() -> String? {
        guard let speaker = AlertRoute.speaker() else { return nil }
        AlertVolumeLift.lift(speaker)
        return speaker.uid
    }

    private static func nanoseconds(_ seconds: TimeInterval) -> UInt64 {
        UInt64(max(0, seconds) * 1_000_000_000)
    }
}
