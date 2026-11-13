// T3 Micro Bridge
// Connects a Work Louder Creator Micro 2 to T3 Code. While the pad is on its
// T3 layer, six keys show the state of six T3 threads and open them, and the
// other keys, the knob and the joystick run T3 Code actions.
//
// With no arguments this runs the bridge. The `t3-micro2` command starts it as a
// launch agent and uses the other arguments for setup and checks.

import AppKit
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
verbose = arguments.contains("--verbose")

func value(after flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1),
          !arguments[index + 1].hasPrefix("--") else { return nil }
    return arguments[index + 1]
}

if arguments.contains("--version") {
    print(bridgeVersion)
    exit(0)
}

if arguments.contains("--self-test") {
    exit(SelfTest.run() ? 0 : 1)
}

if let bundleId = value(after: "--app-pid") {
    // Prints the process id of a running app, for `t3-micro2`. Exit 1 when it is not open.
    guard let found = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else { exit(1) }
    print(found.processIdentifier)
    exit(0)
}

try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
try? fm.createDirectory(at: logDir, withIntermediateDirectories: true)

// One-shot commands for `t3-micro2`. Each prints plain lines and exits.
let oneShots = ["--device", "--layer-install", "--layer-restore", "--layer-rewrite", "--shortcut-install",
                "--shortcut-remove", "--tokens-revoke", "--threads", "--shortcuts", "--spaces", "--spaces-add",
                "--spaces-remove"]
if arguments.contains(where: oneShots.contains) { logToTerminal = verbose }

if arguments.contains("--device") { SetupTool.info() }
if arguments.contains("--layer-install") {
    SetupTool.installLayer(replace: value(after: "--replace").flatMap { Int($0) }, dryRun: arguments.contains("--dry-run"))
}
if arguments.contains("--layer-restore") { SetupTool.restoreLayer(from: value(after: "--layer-restore")) }
if arguments.contains("--layer-rewrite") { SetupTool.rewriteLayer() }
if arguments.contains("--shortcut-install") { SetupTool.installStopShortcut() }
if arguments.contains("--shortcut-remove") { SetupTool.removeStopShortcut() }
if arguments.contains("--tokens-revoke") { SetupTool.revokeTokens() }
if arguments.contains("--spaces") { SetupTool.spaces() }
if let folder = value(after: "--spaces-add") { SetupTool.addSpace(folder) }
if let folder = value(after: "--spaces-remove") { SetupTool.removeSpace(folder) }

let bridge = Bridge()

if arguments.contains("--threads") {
    // Prints what the keys would show, then exits.
    bridge.pollT3 {
        guard bridge.haveT3Data else { print("could not read threads from T3 Code"); exit(1) }
        print("order: \(bridge.config.slotOrder), sources: \(bridge.t3.sources.map { "\($0.name) (\($0.threads.count))" }.joined(separator: ", "))")
        for (i, slot) in bridge.slots.enumerated() {
            print("\(i + 1): \(slot.map { "\($0.state.rawValue)  \($0.title)" } ?? "-")")
        }
        print("waiting on you or unread: \(T3Client.attention(bridge.all).count)")
        exit(0)
    }
    RunLoop.main.run(until: Date().addingTimeInterval(20))
    exit(1)
}

if arguments.contains("--shortcuts") {
    // Prints the key press the bridge would send for each T3 Code command.
    for command in Shortcuts.defaults.keys.sorted() {
        // T3 Code has its own default for every command here except stopping a run.
        let missing = command == Shortcuts.stopCommand && !bridge.shortcuts.isSet(command)
        print("\(command): \(bridge.shortcuts.text(command) ?? "-")\(missing ? " (not set in T3 Code)" : "")")
    }
    exit(0)
}

bridge.config.save()
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
bridge.start()
signal(SIGTERM) { _ in exit(0) }
app.run()
