import AppKit
import Foundation

/// One-shot commands for setup: look at the pad, add the T3 layer, put a backup back,
/// and add the stop shortcut to T3 Code. Each prints plain lines and exits.
enum SetupTool {
    enum Exit: Int32 {
        case ok = 0, failed = 1, noDevice = 3, noFreeLayer = 4, writeFailed = 5, busy = 6
    }

    private static func finish(_ code: Exit, _ message: String? = nil) -> Never {
        if let message { print(message) }
        exit(code.rawValue)
    }

    /// Opens the pad next to whatever else uses it, and gives up after 30 seconds.
    private static func withDevice(_ body: @escaping (Micro) -> Void) -> Never {
        let micro = Micro()
        guard micro.isPresent else {
            finish(.noDevice, "device: not found. Plug in the Creator Micro 2 with its cable.")
        }
        guard micro.open(exclusive: false) else {
            finish(.busy, "device: found, but another program holds it. Stop the bridge first: t3-micro2 stop")
        }
        body(micro)
        withExtendedLifetime(micro) { RunLoop.main.run(until: Date().addingTimeInterval(30)) }
        finish(.failed, "device: stopped answering. Another program may hold it; quit the T3 Micro Bridge and try again.")
    }

    private static func status(_ micro: Micro, then: @escaping ([String: Any]) -> Void) {
        micro.call("device.status", timeout: 3) { response in
            guard let result = response?["result"] as? [String: Any] else {
                finish(.noDevice, "device: found, but it does not answer. Another program may hold it.")
            }
            then(result)
        }
    }

    private static func keymap(_ micro: Micro, then: @escaping (Data) -> Void) {
        micro.readFile(Keymap.fileName) { data in
            guard let data else { finish(.failed, "device: could not read \(Keymap.fileName) from the pad.") }
            then(data)
        }
    }

    private static func backUp(_ data: Data, as prefix: String) -> URL? {
        let url = backupURL(prefix)
        try? fm.createDirectory(at: backupsDir, withIntermediateDirectories: true)
        do { try data.write(to: url) } catch { return nil }
        return url
    }

    private static func printLayers(_ file: Data, active: Int?) {
        guard let layers = try? Keymap.layers(in: file) else { return }
        for layer in layers {
            let notes = [layer.vendor ? "reports keys to the computer" : nil, layer.empty ? "empty" : nil,
                         layer.number == active ? "active" : nil].compactMap { $0 }
            print("layer \(layer.number): \(layer.name)" + (notes.isEmpty ? "" : " (\(notes.joined(separator: ", ")))"))
        }
    }

    // MARK: Commands

    static func info() -> Never {
        withDevice { micro in
            status(micro) { result in
                print("device: connected, firmware \(result["version"] as? String ?? "?"), battery \(result["battery"] as? Int ?? -1)%")
                let active = result["layer_index"] as? Int
                keymap(micro) { file in
                    printLayers(file, active: active)
                    if case let .present(number)? = try? Keymap.plan(file: file) {
                        print("t3 layer: \(number)")
                    } else {
                        print("t3 layer: none")
                    }
                    finish(.ok)
                }
            }
        }
    }

    static func installLayer(replace: Int?, dryRun: Bool) -> Never {
        withDevice { micro in
            status(micro) { _ in
                keymap(micro) { file in
                    let plan: Keymap.Plan
                    do {
                        plan = try Keymap.plan(file: file, replace: replace)
                    } catch let problem as Keymap.Problem {
                        printLayers(file, active: nil)
                        if case .noFreeLayer = problem { finish(.noFreeLayer, "layer: \(problem)") }
                        finish(.failed, "layer: \(problem)")
                    } catch {
                        finish(.failed, "layer: \(error)")
                    }
                    switch plan {
                    case let .present(number):
                        remember(layer: number)
                        finish(.ok, "t3 layer: \(number)\nlayer: already on the pad, nothing to change")
                    case let .change(number, replacing, newFile):
                        if dryRun {
                            finish(.ok, "t3 layer: \(number)\nlayer: would turn layer \(number) (\(replacing)) into \(Keymap.layerName)")
                        }
                        guard let backup = backUp(file, as: "keymap") else {
                            finish(.failed, "layer: could not save a backup in \(backupsDir.path), so nothing was changed")
                        }
                        print("backup: \(backup.path)")
                        micro.writeFile(Keymap.fileName, newFile) { ok in
                            guard ok else {
                                finish(.writeFailed, "layer: the pad did not confirm the new keymap. Put the backup back with: t3-micro2 layer restore")
                            }
                            remember(layer: number)
                            finish(.ok, "t3 layer: \(number)\nlayer: layer \(number) (\(replacing)) is now \(Keymap.layerName)\nchanged: yes")
                        }
                    }
                }
            }
        }
    }

    /// Writes a saved keymap back to the pad. With no file, the newest backup.
    static func restoreLayer(from path: String?) -> Never {
        let url: URL
        if let path {
            url = expand(path)
        } else {
            let names = ((try? fm.contentsOfDirectory(atPath: backupsDir.path)) ?? [])
                .filter { $0.hasPrefix("keymap-") && $0.hasSuffix(".json") }.sorted()
            guard let newest = names.last else { finish(.failed, "restore: no keymap backup in \(backupsDir.path)") }
            url = backupsDir.appendingPathComponent(newest)
        }
        guard let saved = try? Data(contentsOf: url) else { finish(.failed, "restore: cannot read \(url.path)") }
        guard (try? Keymap.layers(in: saved)) != nil else { finish(.failed, "restore: \(url.path) is not a keymap file") }
        withDevice { micro in
            status(micro) { _ in
                keymap(micro) { current in
                    if current == saved { finish(.ok, "restore: the pad already has \(url.lastPathComponent)") }
                    guard let backup = backUp(current, as: "keymap") else {
                        finish(.failed, "restore: could not save a backup in \(backupsDir.path), so nothing was changed")
                    }
                    print("backup: \(backup.path)")
                    micro.writeFile(Keymap.fileName, saved) { ok in
                        guard ok else { finish(.writeFailed, "restore: the pad did not confirm the keymap") }
                        finish(.ok, "restore: the pad now has \(url.lastPathComponent)\nchanged: yes")
                    }
                }
            }
        }
    }

    /// Reads the keymap and writes the same bytes back. Proves the write path without changing anything.
    static func rewriteLayer() -> Never {
        withDevice { micro in
            status(micro) { _ in
                keymap(micro) { current in
                    guard let backup = backUp(current, as: "keymap") else { finish(.failed, "rewrite: could not save a backup") }
                    print("backup: \(backup.path)")
                    micro.writeFile(Keymap.fileName, current) { ok in
                        finish(ok ? .ok : .writeFailed, ok ? "rewrite: wrote \(current.count) bytes back, and the pad's checksum matches" : "rewrite: the pad did not confirm the keymap")
                    }
                }
            }
        }
    }

    private static func remember(layer number: Int) {
        var config = Config.load()
        guard config.t3LayerIndex != number || !fm.fileExists(atPath: configURL.path) else { return }
        config.t3LayerIndex = number
        config.save()
    }

    // MARK: The stop shortcut in T3 Code

    private static func keybindingsURL() -> URL {
        expand(Config.load().t3Homes.first ?? "~/.t3").appendingPathComponent("userdata/keybindings.json")
    }

    static func installStopShortcut() -> Never {
        let url = keybindingsURL()
        guard let file = try? Data(contentsOf: url) else {
            finish(.ok, "stop shortcut: T3 Code has no keybindings file yet (\(url.path)). Open T3 Code once, then run setup again.")
        }
        do {
            switch try Shortcuts.addingStop(to: file) {
            case let .present(key):
                finish(.ok, "stop shortcut: \(key)")
            case let .taken(command):
                finish(.ok, "stop shortcut: none. \(Shortcuts.stopDefault) already runs \(command), so bind \(Shortcuts.stopCommand) yourself in T3 Code's keyboard settings.")
            case let .add(newFile):
                guard let backup = backUp(file, as: "t3-keybindings") else { finish(.failed, "stop shortcut: could not save a backup, so nothing was changed") }
                try newFile.write(to: url, options: .atomic)
                finish(.ok, "backup: \(backup.path)\nstop shortcut: \(Shortcuts.stopDefault) (added to T3 Code)")
            }
        } catch {
            finish(.failed, "stop shortcut: could not change \(url.path): \(error)")
        }
    }

    // MARK: T3 servers on this Mac

    /// Lists every T3 data folder in the home folder and whether the bridge reads it.
    static func spaces() -> Never {
        let read = Config.load().t3Homes.map { expand($0) }
        var folders = read
        for found in T3Source.foldersOnThisMac() where !folders.contains(found) { folders.append(found) }
        for folder in folders {
            let source = T3Source(home: folder)
            let state = !fm.fileExists(atPath: folder.appendingPathComponent("userdata").path) ? "missing"
                : source.isRunning ? "running" : "not running"
            print("\(read.contains(folder) ? "read" : "found")  \(abbreviate(folder))  (\(source.name), \(state))")
            if verbose { print("      token from: \(abbreviate(URL(fileURLWithPath: source.cli())))") }
        }
        finish(.ok)
    }

    /// Adds one folder, or with "all" every folder found, to the ones the bridge reads.
    static func addSpace(_ path: String) -> Never {
        var config = Config.load()
        var homes = config.t3Homes.map { expand($0) }
        let wanted = path == "all" ? T3Source.foldersOnThisMac() : [expand(path)]
        var added: [String] = []
        for folder in wanted where !homes.contains(folder) {
            guard fm.fileExists(atPath: folder.appendingPathComponent("userdata/environment-id").path) else {
                finish(.failed, "spaces: \(abbreviate(folder)) is not a T3 data folder")
            }
            // The bridge runs the t3 program it finds through this folder, so the folder must be yours alone.
            let attributes = try? fm.attributesOfItem(atPath: folder.path)
            let mode = (attributes?[.posixPermissions] as? NSNumber)?.intValue ?? 0o777
            guard (attributes?[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(), mode & 0o022 == 0 else {
                finish(.failed, "spaces: \(abbreviate(folder)) belongs to someone else, or others can write to it, so it was not added")
            }
            homes.append(folder)
            added.append(abbreviate(folder))
        }
        guard !added.isEmpty else { finish(.ok, "spaces: nothing to add") }
        config.t3Homes = homes.map(abbreviate)
        config.save()
        finish(.ok, "spaces: now also reading \(added.joined(separator: ", "))\nchanged: yes")
    }

    /// Stops reading one folder, and ends the session the bridge had on its server.
    static func removeSpace(_ path: String) -> Never {
        var config = Config.load()
        let folder = expand(path)
        let homes = config.t3Homes.map { expand($0) }
        guard homes.contains(folder) else { finish(.ok, "spaces: \(abbreviate(folder)) was not read") }
        guard homes.count > 1 else { finish(.failed, "spaces: the bridge needs at least one T3 data folder") }
        _ = T3Source(home: folder).revokeOwnSessions()
        config.t3Homes = homes.filter { $0 != folder }.map(abbreviate)
        config.save()
        finish(.ok, "spaces: no longer reading \(abbreviate(folder))\nchanged: yes")
    }

    /// Ends the read-only T3 Code sessions the bridge issued for itself, and deletes its token files.
    static func revokeTokens() -> Never {
        var revoked = 0
        for source in T3Client(homes: Config.load().t3Homes).sources {
            revoked += source.revokeOwnSessions()
        }
        finish(.ok, "tokens: revoked \(revoked) T3 Code session\(revoked == 1 ? "" : "s")")
    }

    static func removeStopShortcut() -> Never {
        let url = keybindingsURL()
        guard let file = try? Data(contentsOf: url), let newFile = try? Shortcuts.removingStop(from: file) else {
            finish(.ok, "stop shortcut: nothing to remove")
        }
        guard backUp(file, as: "t3-keybindings") != nil, (try? newFile.write(to: url, options: .atomic)) != nil else {
            finish(.failed, "stop shortcut: could not change \(url.path)")
        }
        finish(.ok, "stop shortcut: removed from T3 Code")
    }
}
