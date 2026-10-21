import AppKit
import XCTest
@testable import TBPK

// Does what the app does for these clicks, against the real stored values.
final class SoundPickTarget: StubMenuTarget {
    var picked: [String] = []

    override func alertSoundClicked(_ item: NSMenuItem) {
        guard let name = item.representedObject as? String else { return }
        picked.append(name)
        AlertSound(name: name).store()
    }

    override func beepCountClicked(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? Int, let count = AlertBeepCount(rawValue: raw) else { return }
        AlertBeepCount.store(count, for: AlertSound.stored)
    }

    override func sharedBeepCountClicked() {
        let sound = AlertSound.stored
        let current = AlertBeepCount.stored(for: sound)
        AlertBeepCount.setShared(!AlertBeepCount.isShared())
        AlertBeepCount.store(current, for: sound)
    }
}
