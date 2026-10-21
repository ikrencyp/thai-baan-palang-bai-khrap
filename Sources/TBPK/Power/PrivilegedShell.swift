import Foundation

enum PrivilegedShell {
    private static let pmsetPath = "/usr/bin/pmset"
    private static let sleepDisabledKey = "sleepdisabled"

    static func isSleepDisabled() -> Bool {
        sleepDisabledValue(in: execute(pmsetPath, arguments: ["-g"]).standardOutput)
    }

    static func sleepDisabledValue(in output: String) -> Bool {
        for line in output.split(separator: "\n") {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let key = fields.firstIndex(where: { $0.lowercased() == sleepDisabledKey }),
                  fields.indices.contains(key + 1) else { continue }
            return String(fields[key + 1]) == "1"
        }
        return false
    }

    @discardableResult
    static func setSleepDisabled(_ value: Bool, prompt: String, firstTimeGrantUser: String? = nil) throws -> Bool {
        let arguments = ["-a", "disablesleep", value ? "1" : "0"]
        if executeWithoutPassword(arguments) { return true }
        if value, let user = firstTimeGrantUser {
            try grantSilentModeAndSet(arguments: arguments, user: user, prompt: prompt)
            return true
        }
        try executeWithAuthenticationPrompt(arguments: arguments, prompt: prompt)
        return false
    }

    static func restoreSleepWithoutPassword() -> Bool {
        executeWithoutPassword(["-a", "disablesleep", "0"])
    }

    static func lowPowerOnBattery() -> Bool? {
        lowPowerValue(in: execute(pmsetPath, arguments: ["-g", "custom"]).standardOutput)
    }

    static func lowPowerValue(in output: String) -> Bool? {
        var inBattery = false
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(":") { inBattery = trimmed == "Battery Power:"; continue }
            let fields = trimmed.split(whereSeparator: \.isWhitespace)
            if inBattery, fields.count == 2, fields[0] == "lowpowermode" { return fields[1] == "1" }
        }
        return nil
    }

    @discardableResult
    static func setLowPowerOnBattery(_ value: Bool) -> Bool {
        executeWithoutPassword(["-b", "lowpowermode", value ? "1" : "0"])
    }

    static func canSavePowerWithoutPassword() -> Bool {
        let result = execute("/usr/bin/sudo", arguments: ["-n", "-l"])
        return result.exitCode == 0 && result.standardOutput.contains("lowpowermode")
    }

    static func canToggleWithoutPassword() -> Bool {
        let result = execute("/usr/bin/sudo", arguments: ["-n", "-l"])
        guard result.exitCode == 0 else { return false }
        return result.standardOutput.contains("NOPASSWD")
            && result.standardOutput.contains("disablesleep")
    }

    static func installPasswordlessRule(for user: String, prompt: String) throws {
        try runElevated(command: try installCommand(for: user, change: nil), prompt: prompt)
        try confirmRuleTookEffect()
    }

    static func grantSilentModeAndSet(arguments: [String], user: String, prompt: String) throws {
        let change = ([pmsetPath] + arguments).map(ElevatedInstallCommand.shellQuoted).joined(separator: " ")
        try runElevated(command: try installCommand(for: user, change: change), prompt: prompt)
        try confirmRuleTookEffect()
    }

    private static func installCommand(for user: String, change: String?) throws -> String {
        guard let command = ElevatedInstallCommand.assemble(user: user, change: change) else {
            throw SleepControlError.privilegeFailure("the account name \"\(user)\" cannot be used in a sudoers rule")
        }
        return command
    }

    private static func confirmRuleTookEffect() throws {
        guard canToggleWithoutPassword() else {
            throw SleepControlError.privilegeFailure("the rule was installed but sudo is not applying it here")
        }
    }

    private static func executeWithoutPassword(_ arguments: [String]) -> Bool {
        execute("/usr/bin/sudo", arguments: ["-n", pmsetPath] + arguments).exitCode == 0
    }

    private static func executeWithAuthenticationPrompt(arguments: [String], prompt: String) throws {
        let command = ([pmsetPath] + arguments).map(ElevatedInstallCommand.shellQuoted).joined(separator: " ")
        try runElevated(command: command, prompt: prompt)
    }

    private static func runElevated(command: String, prompt: String) throws {
        let script = "do shell script \(ElevatedInstallCommand.appleScriptString(command))"
            + " with administrator privileges"
            + " with prompt \(ElevatedInstallCommand.appleScriptString(prompt))"
        let result = execute("/usr/bin/osascript", arguments: ["-e", script])
        guard result.exitCode != 0 else { return }
        if result.standardError.contains("-128") { throw SleepControlError.userCancelled }
        throw SleepControlError.privilegeFailure(result.standardError.trimmed)
    }

    private static func execute(_ path: String, arguments: [String]) -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        do {
            try process.run()
        } catch {
            return ShellResult(exitCode: -1, standardOutput: "", standardError: error.localizedDescription)
        }
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return ShellResult(
            exitCode: process.terminationStatus,
            standardOutput: String(data: outputData, encoding: .utf8) ?? "",
            standardError: String(data: errorData, encoding: .utf8) ?? ""
        )
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
