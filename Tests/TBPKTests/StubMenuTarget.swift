import AppKit
@testable import TBPK

class StubMenuTarget: NSObject, StatusMenuTarget {
    func enableClicked() {}
    func disableClicked() {}
    func durationClicked(_ item: NSMenuItem) {}
    func favoriteEndClicked(_ item: NSMenuItem) {}
    func clearFavoritesClicked() {}
    func countdownClicked(_ item: NSMenuItem) {}
    func animationClicked(_ item: NSMenuItem) {}
    func energyProfileClicked(_ item: NSMenuItem) {}
    func batteryWarningClicked(_ item: NSMenuItem) {}
    func warningPowerClicked(_ item: NSMenuItem) {}
    func powerLimitClicked(_ item: NSMenuItem) {}
    func darkenClicked() {}
    func keepScreenClicked() {}
    func lookPresentClicked() {}
    func batterySaverClicked() {}
    func testAlertClicked() {}
    func alertSoundClicked(_ item: NSMenuItem) {}
    func chooseSoundClicked() {}
    func removeCustomSoundClicked(_ item: NSMenuItem) {}
    func sharedBeepCountClicked() {}
    func beepCountClicked(_ item: NSMenuItem) {}
    func alertVolumeChanged(_ sender: NSSlider) {}
    func helpClicked() {}
    func loginClicked() {}
    func aboutClicked() {}
    func whatsNewClicked() {}
    func updateClicked() {}
    func updateOptionClicked(_ item: NSMenuItem) {}
    func quitClicked() {}
}
