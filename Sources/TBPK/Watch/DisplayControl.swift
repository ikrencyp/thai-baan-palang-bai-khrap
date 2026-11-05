import Foundation

enum DisplayControl {
    static func sleepNow() {
        run(["displaysleepnow"])
    }

    static func sleepMacNow() {
        run(["sleepnow"])
    }

    private static func run(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments
        try? process.run()
    }
}
