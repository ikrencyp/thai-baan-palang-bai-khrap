import Foundation

enum UpdateInstaller {
    static let appName = "Thai Baan Palang Bai Khrap"

    static var logFile: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(appName)/update.log")
    }

    // install.sh replaces the app in /Applications, so it must start after this process has quit
    // (quitting restores the Mac's sleep setting). A detached shell waits for our pid, runs it, then makes sure the
    // new copy is really open: install.sh opens it too, but a launch right after the swap can silently do nothing.
    // Arguments: 1 pid, 2 install.sh, 3 checkout to delete, 4 log, 5 launcher, 6 process name, 7 app path,
    // 8 retry pause, 9 how many half seconds to wait for the app to quit.
    static let waiter = """
    n=0; while kill -0 "$1" 2>/dev/null && [ $n -lt "$9" ]; do sleep 0.5; n=$((n+1)); done
    if kill -0 "$1" 2>/dev/null; then echo "== $(date) the app did not quit: update not installed" >>"$4"; rm -rf "$3"; exit 0; fi
    echo "== $(date) install" >>"$4"
    /bin/bash "$2" -y >>"$4" 2>&1
    rm -rf "$3"
    n=0
    while [ $n -lt 5 ]; do
      if pgrep -x "$6" >/dev/null; then
        sleep "$8"
        pgrep -x "$6" >/dev/null && exit 0
        echo "== $(date) the app closed again right after it opened" >>"$4"
      fi
      echo "== $(date) launch attempt $((n+1))" >>"$4"
      "$5" "$7" >>"$4" 2>&1
      sleep "$8"; n=$((n+1))
    done
    """

    // install.sh puts the app here too (TBPK_INSTALL_DIR lets a test copy update itself without touching /Applications).
    static var installFolder: String { ProcessInfo.processInfo.environment["TBPK_INSTALL_DIR"] ?? "/Applications" }

    static var downloadFolder: URL { logFile.deletingLastPathComponent().appendingPathComponent("Update", isDirectory: true) }

    static func installAfterQuit(_ checkout: ReleaseCheckout, script: URL) throws {
        try FileManager.default.createDirectory(at: logFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try start(arguments: [
            String(ProcessInfo.processInfo.processIdentifier), script.path, checkout.root.path, logFile.path,
            "/usr/bin/open", appName, "\(installFolder)/\(appName).app", "2", "240",
        ])
    }

    static func start(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", waiter, "tbpk-update"] + arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        waitable = process
    }

    // Kept so a test can wait for the detached shell; the app itself never waits.
    nonisolated(unsafe) static var waitable: Process?
}
