import AppKit
import Foundation

/// Checks of the parts that need neither a pad nor T3 Code. Run with `--self-test`.
enum SelfTest {
    /// A Creator Micro 2 keymap as the Input app wrote it: one typing layer, the ChatGPT layer, one empty layer.
    static let keymapBefore = #"{"version":1,"activeProfileId":0,"profiles":[{"id":0,"name":"Default","layers":[{"id":0,"name":"Layer 1","color":16711680,"layout":{"keymap":[["KC_A","KC_B"],["KC_C","KC_D","KC_E","KC_F"],["KC_G","KC_H","KC_I","KC_J"],["KC_K","KC_L","KC_M"]],"encoders":[["KC_VOLU","KC_VOLD","KC_MPLY"]],"joystick":{"type":"RADIAL","sectors":[{"k":"KI_X","a1":0.1875,"a2":0.3125},{"k":"KC_NONE","a1":0.3125,"a2":0.1875}]}},"lights":{"backlight":{"effect":"snake","brightness":1,"speed":0.5,"magic":1,"color":16777215},"underglow":{"effect":"rainbow","brightness":1,"speed":0.55,"magic":1,"color":16777215}}},{"id":3,"name":"ChatGPT","color":16711680,"layout":{"keymap":[["KV_OAI_AG00","KV_OAI_AG01"],["KV_OAI_AG02","KV_OAI_AG03","KV_OAI_AG04","KV_OAI_AG05"],["KV_OAI_ACT06","KV_OAI_ACT07","KV_OAI_ACT08","KV_OAI_ACT09"],["KV_OAI_ACT10","KV_OAI_ACT11","KV_OAI_ACT12"]],"encoders":[["KV_OAI_ENC_CC","KV_OAI_ENC_CW","KV_OAI_ENC_CLK"]],"joystick":{"type":"VENDOR","sectors":[]}}},{"id":1,"name":"Layer","color":16711680,"layout":{"keymap":[["KC_NONE","KC_NONE"],["KC_NONE","KC_NONE","KC_NONE","KC_NONE"],["KC_NONE","KC_NONE","KC_NONE","KC_NONE"],["KC_NONE","KC_NONE","KC_NONE"]],"encoders":[["KC_NONE","KC_NONE","KC_NONE"]],"joystick":{"type":"RADIAL","sectors":[{"k":"KI_X","a1":0.1875,"a2":0.3125},{"k":"KC_NONE","a1":0.3125,"a2":0.1875}]}},"lights":{"backlight":{"effect":"snake","brightness":1,"speed":0.5,"magic":1,"color":16777215},"underglow":{"effect":"rainbow","brightness":1,"speed":0.55,"magic":1,"color":16777215}}}],"macrosUsed":[],"multiActionsUsed":[]}],"multiActions":[],"macros":[],"macrosGroups":[],"multiActionsGroups":[],"linkedApps":[]}"#
    /// The same file after setup turned the empty layer into the T3 layer. A pad ran with exactly these bytes.
    static let keymapAfter = #"{"version":1,"activeProfileId":0,"profiles":[{"id":0,"name":"Default","layers":[{"id":0,"name":"Layer 1","color":16711680,"layout":{"keymap":[["KC_A","KC_B"],["KC_C","KC_D","KC_E","KC_F"],["KC_G","KC_H","KC_I","KC_J"],["KC_K","KC_L","KC_M"]],"encoders":[["KC_VOLU","KC_VOLD","KC_MPLY"]],"joystick":{"type":"RADIAL","sectors":[{"k":"KI_X","a1":0.1875,"a2":0.3125},{"k":"KC_NONE","a1":0.3125,"a2":0.1875}]}},"lights":{"backlight":{"effect":"snake","brightness":1,"speed":0.5,"magic":1,"color":16777215},"underglow":{"effect":"rainbow","brightness":1,"speed":0.55,"magic":1,"color":16777215}}},{"id":3,"name":"ChatGPT","color":16711680,"layout":{"keymap":[["KV_OAI_AG00","KV_OAI_AG01"],["KV_OAI_AG02","KV_OAI_AG03","KV_OAI_AG04","KV_OAI_AG05"],["KV_OAI_ACT06","KV_OAI_ACT07","KV_OAI_ACT08","KV_OAI_ACT09"],["KV_OAI_ACT10","KV_OAI_ACT11","KV_OAI_ACT12"]],"encoders":[["KV_OAI_ENC_CC","KV_OAI_ENC_CW","KV_OAI_ENC_CLK"]],"joystick":{"type":"VENDOR","sectors":[]}}},{"id":1,"name":"T3 Code","color":16711680,"layout":{"keymap":[["KV_OAI_AG00","KV_OAI_AG01"],["KV_OAI_AG02","KV_OAI_AG03","KV_OAI_AG04","KV_OAI_AG05"],["KV_OAI_ACT06","KV_OAI_ACT07","KV_OAI_ACT08","KV_OAI_ACT09"],["KV_OAI_ACT10","KV_OAI_ACT11","KV_OAI_ACT12"]],"encoders":[["KV_OAI_ENC_CC","KV_OAI_ENC_CW","KV_OAI_ENC_CLK"]],"joystick":{"type":"VENDOR","sectors":[]}}}],"macrosUsed":[],"multiActionsUsed":[]}],"multiActions":[],"macros":[],"macrosGroups":[],"multiActionsGroups":[],"linkedApps":[]}"#

    private static var failures = 0
    private static var checks = 0

    private static func check(_ name: String, _ ok: @autoclosure () -> Bool) {
        checks += 1
        if !ok() {
            failures += 1
            print("FAIL \(name)")
        }
    }

    private static func problem(_ body: () throws -> Keymap.Plan) -> Keymap.Problem? {
        do { _ = try body(); return nil } catch { return error as? Keymap.Problem }
    }

    static func run() -> Bool {
        json()
        keymap()
        shortcuts()
        threads()
        check("version looks like 1.2.3", bridgeVersion.split(separator: ".").count == 3)
        print(failures == 0 ? "self-test: \(checks) checks passed" : "self-test: \(failures) of \(checks) checks failed")
        return failures == 0
    }

    // MARK: JSON

    private static func json() {
        let before = Data(keymapBefore.utf8)
        let parsed = try? JSONValue.parse(before)
        check("keymap parses", parsed != nil)
        check("compact output is byte for byte the input", parsed?.compact == keymapBefore)
        check("numbers keep their text", parsed?.compact.contains("\"speed\":0.55,") == true)
        let pretty = parsed.map { $0.pretty() } ?? ""
        check("pretty output parses to the same value", (try? JSONValue.parse(Data(pretty.utf8))) == parsed)
        check("pretty output indents by two spaces", pretty.hasPrefix("{\n  \"version\": 1,\n  \"activeProfileId\": 0,"))
        check("empty list and object", (try? JSONValue.parse(Data(" { \"a\" : [ ] , \"b\" : { } } ".utf8)))?.compact == "{\"a\":[],\"b\":{}}")
        check("escapes survive", (try? JSONValue.parse(Data(#"["a\"b\\c\/dé"]"#.utf8)))?.compact == #"["a\"b\\c\/dé"]"#)
        check("escapes decode", (try? JSONValue.parse(Data(#"["a\"b\/c"]"#.utf8)))?.items?.first?.text == "a\"b/c")
        check("new text is escaped", JSONValue.text("a\"b\\c\n").compact == #""a\"b\\c\n""#)
        for bad in ["", "{", "[1,]", "{\"a\"}", "[1] x", "nope", "\"open"] {
            check("rejects \(bad)", (try? JSONValue.parse(Data(bad.utf8))) == nil)
        }
    }

    // MARK: The T3 layer

    private static func keymap() {
        let before = Data(keymapBefore.utf8), after = Data(keymapAfter.utf8)
        check("the empty layer becomes the T3 layer, byte for byte",
              (try? Keymap.plan(file: before)) == .change(number: 3, replacing: "Layer", file: after))
        check("a pad that has the layer is left alone", (try? Keymap.plan(file: after)) == .present(number: 3))
        check("the same layer asked for by number is left alone", (try? Keymap.plan(file: after, replace: 3)) == .present(number: 3))

        if case let .change(number, replacing, file)? = try? Keymap.plan(file: before, replace: 1) {
            check("--layer 1 replaces layer 1", number == 1 && replacing == "Layer 1")
            let layers = (try? Keymap.layers(in: file)) ?? []
            check("layer 1 is then the T3 layer", layers.first?.name == Keymap.layerName && layers.first?.vendor == true)
            check("the other layers stay", layers.count == 3 && layers[1].name == "ChatGPT" && layers[2].empty)
            check("it keeps the id of the layer it replaced", String(decoding: file, as: UTF8.self).contains(#"{"id":0,"name":"T3 Code","color":16711680,"layout":{"keymap":[["KV_OAI_AG00""#))
        } else {
            check("--layer 1 gives a plan", false)
        }

        check("the ChatGPT layer is never replaced", problem { try Keymap.plan(file: before, replace: 2) } == .isVendorLayer(2))
        check("a missing layer number is refused", problem { try Keymap.plan(file: before, replace: 9) } == .noSuchLayer(9, count: 3))
        let full = Data(keymapBefore.replacingOccurrences(of: "\"KC_NONE\",\"KC_NONE\"]", with: "\"KC_A\",\"KC_NONE\"]").utf8)
        check("no empty layer means no change", problem { try Keymap.plan(file: full) } == .noFreeLayer(["1 Layer 1", "2 ChatGPT", "3 Layer"]))
        let plain = Data(keymapBefore.replacingOccurrences(of: "KV_OAI_", with: "KC_").utf8)
        check("no ChatGPT layer means no change", problem { try Keymap.plan(file: plain) } == .noVendorLayer)
        check("a broken file is reported", problem { try Keymap.plan(file: Data("{".utf8)) } != nil)
        check("a file without profiles is reported", problem { try Keymap.plan(file: Data("{}".utf8)) } == .unreadable("it has no profiles"))

        let layers = (try? Keymap.layers(in: before)) ?? []
        check("layers are described", layers.map { "\($0.number)\($0.vendor ? "v" : "")\($0.empty ? "e" : "")" } == ["1", "2v", "3e"])
    }

    // MARK: Shortcuts

    private static func shortcuts() {
        let cmd = CGEventFlags.maskCommand, shift = CGEventFlags.maskShift, option = CGEventFlags.maskAlternate
        check("mod+shift+s", Shortcuts.parse("mod+shift+s") == Shortcut(code: 1, flags: [cmd, shift]))
        check("mod+alt+x", Shortcuts.parse("mod+alt+x") == Shortcut(code: 7, flags: [cmd, option]))
        check("mod+shift+]", Shortcuts.parse("mod+shift+]") == Shortcut(code: 30, flags: [cmd, shift]))
        check("Ctrl+Enter", Shortcuts.parse("Ctrl+Enter") == Shortcut(code: 36, flags: [.maskControl]))
        check("a bare key", Shortcuts.parse("f6") == Shortcut(code: 97, flags: []))
        check("unknown key", Shortcuts.parse("mod+hyper") == nil)
        check("unknown modifier", Shortcuts.parse("fn+s") == nil)
        check("every default can be pressed", Shortcuts.defaults.values.allSatisfy { Shortcuts.parse($0) != nil })

        let file = """
        [
          {
            "key": "mod+shift+s",
            "command": "thread.settle",
            "when": "!terminalFocus"
          },
          {
            "key": "mod+k",
            "command": "thread.settle"
          },
          {
            "key": "mod+hyper",
            "command": "thread.pin"
          }
        ]

        """
        let data = Data(file.utf8)
        let found = Shortcuts.bindings(in: data)
        check("the last binding of a command wins", found["thread.settle"] == "mod+k")
        check("a key that cannot be pressed is skipped", found["thread.pin"] == nil)

        if case let .add(added)? = try? Shortcuts.addingStop(to: data) {
            let text = String(decoding: added, as: UTF8.self)
            check("stop is added at the end", text.hasSuffix("  {\n    \"key\": \"mod+alt+x\",\n    \"command\": \"thread.stop\",\n    \"when\": \"!terminalFocus\"\n  }\n]\n"))
            check("the rest of the file is untouched", text.hasPrefix(String(file.dropLast(3))))
            check("adding twice changes nothing", (try? Shortcuts.addingStop(to: added)) == .present("mod+alt+x"))
            check("removing gives the first file back", (try? Shortcuts.removingStop(from: added)) == data)
        } else {
            check("stop can be added", false)
        }
        check("nothing to remove", (try? Shortcuts.removingStop(from: data)) == .some(nil))
        let taken = Data(#"[{"key":"mod+alt+x","command":"terminal.close"}]"#.utf8)
        check("a taken key is left alone", (try? Shortcuts.addingStop(to: taken)) == .taken(by: "terminal.close"))
        let own = Data(#"[{"key":"mod+.","command":"thread.stop"}]"#.utf8)
        check("an existing stop shortcut is kept", (try? Shortcuts.addingStop(to: own)) == .present("mod+."))
        check("a changed stop shortcut is not removed", (try? Shortcuts.removingStop(from: own)) == .some(nil))
    }

    // MARK: Thread state and order

    private static func thread(_ id: String, _ state: ThreadState, pinKey: String? = nil, main: Double = 0, sent: Double = 0,
                               pending: Double? = nil, completed: Double? = nil, human: Bool = true) -> ThreadInfo {
        func at(_ t: Double) -> Date { Date(timeIntervalSince1970: 1_000_000 + t) }
        return ThreadInfo(environmentId: "env", id: id, title: id, state: state, pinned: pinKey != nil, pinKey: pinKey,
                          created: at(0), mainTime: at(main), sentTime: at(sent), pendingSince: pending.map(at),
                          completedAt: completed.map(at), human: human)
    }

    private static func threads() {
        check("a pending request means waiting", T3Source.state(of: ["pendingRuntimeRequest": ["id": "r"], "status": "running"]) == .awaiting)
        check("a request that does not block is not waiting", T3Source.state(of: ["pendingRuntimeRequest": ["blocking": false], "status": "running"]) == .working)
        check("an active run means working", T3Source.state(of: ["activeRunId": "run", "status": "idle"]) == .working)
        check("queued means working", T3Source.state(of: ["status": "queued"]) == .working)
        check("failed means error", T3Source.state(of: ["status": "failed"]) == .error)
        check("finished and never opened means unread", T3Source.state(of: ["latestRunCompletedAt": "2026-11-12T10:00:00.000Z"]) == .unread)
        check("finished after the last visit means unread",
              T3Source.state(of: ["latestRunCompletedAt": "2026-11-12T10:00:00.000Z", "lastVisitedAt": "2026-11-12T09:00:00.000Z"]) == .unread)
        check("visited after it finished means idle",
              T3Source.state(of: ["latestRunCompletedAt": "2026-11-12T10:00:00.000Z", "lastVisitedAt": "2026-11-12T11:00:00.000Z"]) == .idle)
        check("nothing known means idle", T3Source.state(of: [:]) == .idle)

        let all = [
            thread("idle-new", .idle, main: 50),
            thread("idle-pinned", .idle, pinKey: "a0"),
            thread("scheduled", .working, sent: 90, human: false),
            thread("mine-old", .working, sent: 10),
            thread("mine-new", .working, sent: 20),
            thread("done-old", .unread, completed: 5),
            thread("done-new", .unread, completed: 6),
            thread("failed", .error, main: 3),
            thread("asked-second", .awaiting, pending: 8),
            thread("asked-first", .awaiting, pending: 2),
            thread("idle-old", .idle, main: 40),
        ]
        check("priority order", T3Client.priorityOrder(all).map { $0.id } == [
            "asked-first", "asked-second", "failed", "done-new", "done-old", "mine-new", "mine-old", "scheduled",
            "idle-pinned", "idle-new", "idle-old",
        ])
        check("the queue for NEXT", T3Client.attention(all).map { $0.id } == ["asked-first", "asked-second", "failed", "done-new", "done-old"])

        let side = [
            thread("main-old", .idle, main: 10),
            thread("pin-b", .idle, pinKey: "b"),
            thread("working-old", .working, sent: 1),
            thread("main-new", .unread, main: 20),
            thread("pin-a", .working, pinKey: "a"),
            thread("working-new", .working, sent: 2),
        ]
        check("sidebar order", T3Client.sidebarOrder(side).map { $0.id } == ["pin-a", "pin-b", "main-new", "main-old", "working-new", "working-old"])

        check("the desktop folder is called desktop", T3Source.name(ofFolder: ".t3") == "desktop")
        check("other folders are named after their suffix", T3Source.name(ofFolder: ".t3-work") == "work")
        check("paths are kept with ~", abbreviate(homeDir.appendingPathComponent(".t3-x")) == "~/.t3-x" && abbreviate(URL(fileURLWithPath: "/opt/t3")) == "/opt/t3")
        check("~ expands and comes back", abbreviate(expand("~/.t3")) == "~/.t3")
        check("tokens only go to this Mac", T3Source.isThisMac("127.0.0.1") && T3Source.isThisMac("localhost") && !T3Source.isThisMac("10.0.0.5") && !T3Source.isThisMac("example.com"))

        let slots = T3Client.slots(from: Array(all.prefix(2)), order: "priority")
        check("six slots, empty ones last", slots.count == 6 && slots[0]?.threadId == "idle-pinned" && slots[2] == nil)
        check("at most six slots", T3Client.slots(from: all, order: "sidebar").compactMap { $0 }.count == 6)
    }
}
