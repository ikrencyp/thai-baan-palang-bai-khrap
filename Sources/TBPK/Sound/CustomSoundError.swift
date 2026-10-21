import AppKit
import Foundation

enum CustomSoundError: LocalizedError, Equatable {
    case unsupportedType(String)
    case unreadable
    case tooLong(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedType(let ext): return "Files of type .\(ext) are not supported. Use AIFF, WAV, MP3, M4A, AAC or CAF."
        case .unreadable: return "macOS could not read this file as a sound."
        case .tooLong(let seconds): return "This sound is \(seconds) seconds long. Pick one of \(Int(CustomSoundLibrary.maxSeconds)) seconds or less."
        }
    }
}
