import AppKit

// Shown once, when the first switch-on needs admin rights: says what the rule is before any password dialog opens.
@MainActor
enum SilentModeDialog {
    static func ask() -> SilentModeChoice {
        let alert = NSAlert()
        alert.messageText = "Skip the password from now on?"
        alert.informativeText = """
        Turning sleep off needs administrator rights. TBPK can ask for your password once and add a small rule to this Mac, so it does not ask again.

        The rule lets your account run exactly four commands as root without a password: pmset disablesleep 1 and 0, and pmset lowpowermode 1 and 0 on battery. Nothing else is granted. It lives in /etc/sudoers.d/tbpk-<your account> and scripts/uninstall-passwordless.sh or uninstall.sh removes it.

        Or keep the password: macOS then asks every time sleep is switched.
        """
        alert.addButton(withTitle: "Allow, no password after this")
        alert.addButton(withTitle: "Ask for my password each time")
        alert.addButton(withTitle: "Cancel")
        switch AlertPresenter.run(alert) {
        case .alertFirstButtonReturn: return .allow
        case .alertSecondButtonReturn: return .askEachTime
        default: return .cancel
        }
    }
}
