import AppKit
import ApplicationServices
import Foundation
import IOKit
import IOKit.hid

// MARK: - Paths

let fm = FileManager.default
let homeDir = fm.homeDirectoryForCurrentUser
let supportDir = homeDir.appendingPathComponent("Library/Application Support/T3MicroBridge")
let backupsDir = supportDir.appendingPathComponent("backups")
let logDir = homeDir.appendingPathComponent("Library/Logs/T3MicroBridge")
let configURL = supportDir.appendingPathComponent("config.json")
let stateURL = supportDir.appendingPathComponent("state.json")
/// What the running bridge last saw. `t3-micro2 status` reads it.
let statusURL = supportDir.appendingPathComponent("status.json")
let logURL = logDir.appendingPathComponent("bridge.log")
/// The `t3` command of the desktop app, used when a data folder has none of its own.
let t3CLI = homeDir.appendingPathComponent(".t3/bin/t3").path

func expand(_ path: String) -> URL { URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).standardizedFileURL }

/// The path with the home folder written as ~, the way settings keep it.
func abbreviate(_ url: URL) -> String {
    let path = url.standardizedFileURL.path, home = homeDir.standardizedFileURL.path
    return path == home ? "~" : path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
}

/// A name for a backup file, such as keymap-20261112-140800.json.
func backupURL(_ prefix: String) -> URL {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyyMMdd-HHmmss"
    return backupsDir.appendingPathComponent("\(prefix)-\(f.string(from: Date())).json")
}

// MARK: - Logging

let logFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

var verbose = false
/// One-shot commands print their own plain lines and keep the log out of them.
var logToTerminal = true

func log(_ message: String) {
    let line = "\(logFormatter.string(from: Date())) \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    if logToTerminal { FileHandle.standardOutput.write(data) }
    guard fm.fileExists(atPath: logDir.path) else { return }
    if let size = (try? fm.attributesOfItem(atPath: logURL.path))?[.size] as? Int, size > 2_000_000 {
        let old = logDir.appendingPathComponent("bridge.old.log")
        try? fm.removeItem(at: old)
        try? fm.moveItem(at: logURL, to: old)
    }
    if let handle = try? FileHandle(forWritingTo: logURL) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? data.write(to: logURL)
    }
}

func debug(_ message: String) { if verbose { log("debug " + message) } }

// MARK: - Config

struct Config {
    /// Layer number as the device reports it and the Input app shows it: 1, 2, 3...
    var t3LayerIndex = 3
    var idlePollSeconds = 1.5
    var activePollSeconds = 0.5
    var t3PollSeconds = 2.5
    var brightness = 1.0
    var keysBacklight = false
    var t3BundleId = "com.t3tools.t3code"
    var actionKeys = true
    /// T3 data folders to read threads from. The desktop app's own comes first.
    var t3Homes = ["~/.t3"]
    /// "priority": what needs you comes first. "sidebar": same order as the T3 Code list.
    var slotOrder = "priority"
    /// How long a key must stay down to count as a hold, in advanced mode.
    var holdSeconds = 0.45

    static func load() -> Config {
        var c = Config()
        guard let data = try? Data(contentsOf: configURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return c }
        if let v = obj["t3LayerIndex"] as? Int { c.t3LayerIndex = v }
        if let v = obj["idlePollSeconds"] as? Double { c.idlePollSeconds = max(0.3, v) }
        if let v = obj["activePollSeconds"] as? Double { c.activePollSeconds = max(0.2, v) }
        if let v = obj["t3PollSeconds"] as? Double { c.t3PollSeconds = max(0.5, v) }
        if let v = obj["brightness"] as? Double { c.brightness = min(1, max(0, v)) }
        if let v = obj["keysBacklight"] as? Bool { c.keysBacklight = v }
        if let v = obj["t3BundleId"] as? String { c.t3BundleId = v }
        if let v = obj["actionKeys"] as? Bool { c.actionKeys = v }
        if let v = obj["t3Homes"] as? [String], !v.isEmpty { c.t3Homes = v }
        if let v = obj["slotOrder"] as? String, ["priority", "sidebar"].contains(v) { c.slotOrder = v }
        if let v = obj["holdSeconds"] as? Double { c.holdSeconds = min(2, max(0.2, v)) }
        return c
    }

    /// Writes the file back with every setting present, so new settings show up in it.
    func save() {
        let obj: [String: Any] = [
            "t3LayerIndex": t3LayerIndex, "idlePollSeconds": idlePollSeconds,
            "activePollSeconds": activePollSeconds, "t3PollSeconds": t3PollSeconds,
            "brightness": brightness, "keysBacklight": keysBacklight,
            "t3BundleId": t3BundleId, "actionKeys": actionKeys,
            "t3Homes": t3Homes, "slotOrder": slotOrder, "holdSeconds": holdSeconds,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: configURL)
        }
    }
}

