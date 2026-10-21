import Foundation

// The one command that runs as root to install the sudoers rule. Root writes the rule itself: nothing the user's own
// processes can write to is ever copied into /etc, so no program running as the user can swap in a broader rule while
// the password dialog is open.
enum ElevatedInstallCommand {
    // sudo skips any file in sudoers.d whose name contains a dot, so a dot in the account name (first.last) becomes an
    // underscore in the file name; the rule line inside keeps the real name.
    static func passwordlessRulePath(for user: String) -> String {
        "/etc/sudoers.d/tbpk-\(user.replacingOccurrences(of: ".", with: "_"))"
    }

    // A login name that is safe to put in a sudoers line and a file name. A leading dash would read as an option,
    // and ALL is the sudoers keyword for every user.
    static func isSafeUserName(_ user: String) -> Bool {
        !user.isEmpty && !user.hasPrefix("-") && user != "ALL" && user.unicodeScalars.allSatisfy {
            ($0.value < 128) && (CharacterSet.alphanumerics.contains($0) || "._-".unicodeScalars.contains($0))
        }
    }

    // Macs write the line as @includedir /etc/sudoers.d, @includedir /private/etc/sudoers.d (/etc is a link to
    // /private/etc) or the older #includedir spelling; all of them make sudo read the folder.
    static let includeLinePattern = "^[@#]includedir[[:space:]]+(/private)?/etc/sudoers\\.d/?[[:space:]]*$"

    static func ruleLine(for user: String) -> String {
        "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -b lowpowermode 1, /usr/bin/pmset -b lowpowermode 0\n"
    }

    // nil when the login name cannot be used safely. The draft has a dot in its name, so sudo ignores it until it
    // has passed `visudo -c -f` and is moved into place.
    static func assemble(user: String, change: String?) -> String? {
        guard isSafeUserName(user) else { return nil }
        let rule = passwordlessRulePath(for: user)
        let draft = shellQuoted(rule + ".new")
        let line = shellQuoted(String(ruleLine(for: user).dropLast()))
        let reads = "grep -Eq '\(includeLinePattern)' /etc/sudoers"
            + " || { echo 'sudo on this Mac does not read /etc/sudoers.d' >&2; exit 4; }"
        let install = "{ umask 077 && printf '%s\\n' \(line) > \(draft)"
            + " && /bin/chmod 0440 \(draft) && /usr/sbin/chown root:wheel \(draft)"
            + " && /usr/sbin/visudo -c -f \(draft) && /bin/mv -f \(draft) \(shellQuoted(rule)); }"
            + " || { /bin/rm -f \(draft); exit 5; }"
        var parts = [reads, install]
        if let change { parts.append(change) }
        parts.append("/usr/sbin/visudo -c")
        return parts.joined(separator: " && ")
    }

    static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    static func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
