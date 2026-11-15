import AppKit
import Foundation

/// Checks of the parts that need neither a pad nor T3 Code. Run with `--self-test`.
enum SelfTest {
    /// A Creator Micro 2 keymap as the Input app wrote it: one typing layer, the ChatGPT layer, one empty layer.
    static let keymapBefore = #"{"version":1,"activeProfileId":0,"profiles":[{"id":0,"name":"Default","layers":[{"id":0,"name":"Layer 1","color":16711680,"layout":{"keymap":[["KC_A","KC_B"],["KC_C","KC_D","KC_E","KC_F"],["KC_G","KC_H","KC_I","KC_J"],["KC_K","KC_L","KC_M"]],"encoders":[["KC_VOLU","KC_VOLD","KC_MPLY"]],"joystick":{"type":"RADIAL","sectors":[{"k":"KI_X","a1":0.1875,"a2":0.3125},{"k":"KC_NONE","a1":0.3125,"a2":0.1875}]}},"lights":{"backlight":{"effect":"snake","brightness":1,"speed":0.5,"magic":1,"color":16777215},"underglow":{"effect":"rainbow","brightness":1,"speed":0.55,"magic":1,"color":16777215}}},{"id":3,"name":"ChatGPT","color":16711680,"layout":{"keymap":[["KV_OAI_AG00","KV_OAI_AG01"],["KV_OAI_AG02","KV_OAI_AG03","KV_OAI_AG04","KV_OAI_AG05"],["KV_OAI_ACT06","KV_OAI_ACT07","KV_OAI_ACT08","KV_OAI_ACT09"],["KV_OAI_ACT10","KV_OAI_ACT11","KV_OAI_ACT12"]],"encoders":[["KV_OAI_ENC_CC","KV_OAI_ENC_CW","KV_OAI_ENC_CLK"]],"joystick":{"type":"VENDOR","sectors":[]}}},{"id":1,"name":"Layer","color":16711680,"layout":{"keymap":[["KC_NONE","KC_NONE"],["KC_NONE","KC_NONE","KC_NONE","KC_NONE"],["KC_NONE","KC_NONE","KC_NONE","KC_NONE"],["KC_NONE","KC_NONE","KC_NONE"]],"encoders":[["KC_NONE","KC_NONE","KC_NONE"]],"joystick":{"type":"RADIAL","sectors":[{"k":"KI_X","a1":0.1875,"a2":0.3125},{"k":"KC_NONE","a1":0.3125,"a2":0.1875}]}},"lights":{"backlight":{"effect":"snake","brightness":1,"speed":0.5,"magic":1,"color":16777215},"underglow":{"effect":"rainbow","brightness":1,"speed":0.55,"magic":1,"color":16777215}}}],"macrosUsed":[],"multiActionsUsed":[]}],"multiActions":[],"macros":[],"macrosGroups":[],"multiActionsGroups":[],"linkedApps":[]}"#
    /// The same file after setup turned the empty layer into the T3 layer. All 13 keys have AG names,
    /// which is what makes the pad light them. A pad ran with a T3 layer of exactly this text.
    static let keymapAfter = #"{"version":1,"activeProfileId":0,"profiles":[{"id":0,"name":"Default","layers":[{"id":0,"name":"Layer 1","color":16711680,"layout":{"keymap":[["KC_A","KC_B"],["KC_C","KC_D","KC_E","KC_F"],["KC_G","KC_H","KC_I","KC_J"],["KC_K","KC_L","KC_M"]],"encoders":[["KC_VOLU","KC_VOLD","KC_MPLY"]],"joystick":{"type":"RADIAL","sectors":[{"k":"KI_X","a1":0.1875,"a2":0.3125},{"k":"KC_NONE","a1":0.3125,"a2":0.1875}]}},"lights":{"backlight":{"effect":"snake","brightness":1,"speed":0.5,"magic":1,"color":16777215},"underglow":{"effect":"rainbow","brightness":1,"speed":0.55,"magic":1,"color":16777215}}},{"id":3,"name":"ChatGPT","color":16711680,"layout":{"keymap":[["KV_OAI_AG00","KV_OAI_AG01"],["KV_OAI_AG02","KV_OAI_AG03","KV_OAI_AG04","KV_OAI_AG05"],["KV_OAI_ACT06","KV_OAI_ACT07","KV_OAI_ACT08","KV_OAI_ACT09"],["KV_OAI_ACT10","KV_OAI_ACT11","KV_OAI_ACT12"]],"encoders":[["KV_OAI_ENC_CC","KV_OAI_ENC_CW","KV_OAI_ENC_CLK"]],"joystick":{"type":"VENDOR","sectors":[]}}},{"id":1,"name":"T3 Code","color":16711680,"layout":{"keymap":[["KV_OAI_AG00","KV_OAI_AG01"],["KV_OAI_AG02","KV_OAI_AG03","KV_OAI_AG04","KV_OAI_AG05"],["KV_OAI_AG06","KV_OAI_AG07","KV_OAI_AG08","KV_OAI_AG09"],["KV_OAI_AG10","KV_OAI_AG11","KV_OAI_AG12"]],"encoders":[["KV_OAI_ENC_CC","KV_OAI_ENC_CW","KV_OAI_ENC_CLK"]],"joystick":{"type":"VENDOR","sectors":[]}}}],"macrosUsed":[],"multiActionsUsed":[]}],"multiActions":[],"macros":[],"macrosGroups":[],"multiActionsGroups":[],"linkedApps":[]}"#
    /// What versions up to 0.1.1 wrote: a plain copy of the ChatGPT layer, whose seven ACT keys stay dark.
    static let keymapEarlier = #"{"version":1,"activeProfileId":0,"profiles":[{"id":0,"name":"Default","layers":[{"id":0,"name":"Layer 1","color":16711680,"layout":{"keymap":[["KC_A","KC_B"],["KC_C","KC_D","KC_E","KC_F"],["KC_G","KC_H","KC_I","KC_J"],["KC_K","KC_L","KC_M"]],"encoders":[["KC_VOLU","KC_VOLD","KC_MPLY"]],"joystick":{"type":"RADIAL","sectors":[{"k":"KI_X","a1":0.1875,"a2":0.3125},{"k":"KC_NONE","a1":0.3125,"a2":0.1875}]}},"lights":{"backlight":{"effect":"snake","brightness":1,"speed":0.5,"magic":1,"color":16777215},"underglow":{"effect":"rainbow","brightness":1,"speed":0.55,"magic":1,"color":16777215}}},{"id":3,"name":"ChatGPT","color":16711680,"layout":{"keymap":[["KV_OAI_AG00","KV_OAI_AG01"],["KV_OAI_AG02","KV_OAI_AG03","KV_OAI_AG04","KV_OAI_AG05"],["KV_OAI_ACT06","KV_OAI_ACT07","KV_OAI_ACT08","KV_OAI_ACT09"],["KV_OAI_ACT10","KV_OAI_ACT11","KV_OAI_ACT12"]],"encoders":[["KV_OAI_ENC_CC","KV_OAI_ENC_CW","KV_OAI_ENC_CLK"]],"joystick":{"type":"VENDOR","sectors":[]}}},{"id":1,"name":"T3 Code","color":16711680,"layout":{"keymap":[["KV_OAI_AG00","KV_OAI_AG01"],["KV_OAI_AG02","KV_OAI_AG03","KV_OAI_AG04","KV_OAI_AG05"],["KV_OAI_ACT06","KV_OAI_ACT07","KV_OAI_ACT08","KV_OAI_ACT09"],["KV_OAI_ACT10","KV_OAI_ACT11","KV_OAI_ACT12"]],"encoders":[["KV_OAI_ENC_CC","KV_OAI_ENC_CW","KV_OAI_ENC_CLK"]],"joystick":{"type":"VENDOR","sectors":[]}}}],"macrosUsed":[],"multiActionsUsed":[]}],"multiActions":[],"macros":[],"macrosGroups":[],"multiActionsGroups":[],"linkedApps":[]}"#

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
        colors()
        echoes()
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

        let earlier = Data(keymapEarlier.utf8)
        check("a T3 layer from an earlier version gets the names that light up",
              (try? Keymap.plan(file: earlier)) == .change(number: 3, replacing: Keymap.layerName, file: after))
        check("so does one asked for by number", (try? Keymap.plan(file: earlier, replace: 3)) == .change(number: 3, replacing: Keymap.layerName, file: after))
        let alone = Data(keymapEarlier.replacingOccurrences(of: "\"name\":\"ChatGPT\"", with: "\"name\":\"T3 Code\"").utf8)
        if case let .change(number, _, file)? = try? Keymap.plan(file: alone) {
            check("without a ChatGPT layer it renames its own keys", number == 2 && !String(decoding: file, as: UTF8.self).contains("KV_OAI_ACT06\",\"KV_OAI_ACT07\",\"KV_OAI_ACT08\",\"KV_OAI_ACT09\"]],\"encoders\":[[\"KV_OAI_ENC_CC\",\"KV_OAI_ENC_CW\",\"KV_OAI_ENC_CLK\"]],\"joystick\":{\"type\":\"VENDOR\",\"sectors\":[]}}},{\"id\":1"))
        } else {
            check("without a ChatGPT layer it still gives a plan", false)
        }
        check("the ChatGPT layer keeps its ACT names", String(decoding: after, as: UTF8.self).contains("\"name\":\"ChatGPT\",\"color\":16711680,\"layout\":{\"keymap\":[[\"KV_OAI_AG00\",\"KV_OAI_AG01\"],[\"KV_OAI_AG02\",\"KV_OAI_AG03\",\"KV_OAI_AG04\",\"KV_OAI_AG05\"],[\"KV_OAI_ACT06\""))
        check("the knob keeps its names", String(decoding: after, as: UTF8.self).components(separatedBy: "KV_OAI_ENC_CLK").count == 3)
        check("action keys keep their names to the bridge",
              ["AG06", "AG12", "ACT06", "AG00", "AG05", "ENC_CLK"].map(Keymap.keyName) == ["ACT06", "ACT12", "ACT06", "AG00", "AG05", "ENC_CLK"])
        let usual = ActionKey.allCases
        check("row 3 is new, settle, approve, stop and row 4 is next, mic, send",
              usual.map { $0.rawValue } == ["new", "settle", "approve", "stop", "next", "mic", "send"])
        check("each action key has its action", ["ACT06", "ACT07", "ACT08", "ACT09", "ACT10", "ACT11", "ACT12"].map { ActionKey.on($0, in: usual) }
              == [.new, .settle, .approve, .stop, .next, .mic, .send])
        check("the pad reports them under their lit names", ActionKey.on(Keymap.keyName("AG11"), in: usual) == .mic)
        check("thread keys and the knob have no action", ["AG00", "AG05", "ACT05", "ACT13", "ENC_CLK", "ACT"].allSatisfy { ActionKey.on($0, in: usual) == nil })
        let before011 = ["next", "approve", "stop", "new", "mic", "settle", "send"]
        check("the order can be set", ActionKey.order(from: before011).map { ActionKey.on("ACT06", in: $0) } == .some(.next))
        check("an order must name all seven, once each",
              [["next"], before011 + ["send"], Array(before011.dropLast()) + ["mic"], Array(before011.dropLast()) + ["enter"], []].allSatisfy { ActionKey.order(from: $0) == nil })

        let layers = (try? Keymap.layers(in: before)) ?? []
        check("only the new T3 layer can light every key",
              ((try? Keymap.layers(in: after)) ?? []).map { $0.lit } == [true, false, true] && ((try? Keymap.layers(in: earlier)) ?? []).map { $0.lit } == [true, false, false])
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

    // MARK: Colors

    private static func colors() {
        check("#FF6D00", Scheme.parse(color: "#FF6D00") == 0xFF6D00)
        check("ff6d00 and 0xFF6D00", Scheme.parse(color: "ff6d00") == 0xFF6D00 && Scheme.parse(color: " 0xFF6D00 ") == 0xFF6D00)
        check("off is black", Scheme.parse(color: "off") == 0 && Scheme.parse(color: "#000000") == 0)
        check("not a color", ["", "#FFF", "orange", "#GG0000", "#FF6D0000"].allSatisfy { Scheme.parse(color: $0) == nil })

        let written = Scheme.parse(Data(Scheme.defaultFile.utf8))
        check("the file written for people holds the defaults", written.scheme == Scheme() && written.problems.isEmpty)
        check("every state and key has a default", Scheme.threadNames.allSatisfy { Scheme().threads[$0.state] != nil }
              && ActionKey.allCases.allSatisfy { Scheme().keys[$0] != nil })

        let edited = Scheme.parse(Data(##"{"keys":{"mic":"#112233","stop":"off","send":7,"enter":"#FFFFFF"},"threads":{"idle":"off"},"modes":{"advanced":"00FF00"},"restBrightness":2,"ring":{}}"##.utf8))
        var want = Scheme()
        want.keys[.mic] = 0x112233; want.keys[.stop] = 0; want.threads[.idle] = 0; want.advanced = 0x00FF00
        check("an edited file changes what it names and nothing else", edited.scheme == want)
        check("each mistake is named", edited.problems.count == 4 && edited.problems.contains { $0.hasPrefix("keys.send ") }
              && edited.problems.contains { $0.hasPrefix("keys.enter ") } && edited.problems.contains { $0.hasPrefix("restBrightness ") }
              && edited.problems.contains { $0.hasPrefix("ring ") })
        check("a broken file means the defaults", Scheme.parse(Data("{".utf8)).scheme == Scheme() && Scheme.parse(Data("[]".utf8)).problems.count == 1)
        check("true is not a brightness", Scheme.parse(Data(#"{"restBrightness":true}"#.utf8)).scheme.rest == Scheme().rest)
        check("0 is a brightness", Scheme.parse(Data(#"{"restBrightness":0}"#.utf8)).scheme.rest == 0)

        let scheme = Scheme()
        let threads = scheme.threadLights([.awaiting, .working, .off, nil, .idle, .error], brightness: 0.5)
        check("thread keys are numbered 0 to 5", threads.map { $0.id } == [0, 1, 2, 3, 4, 5])
        check("a waiting thread pulses in its color", threads[0] == KeyLight(id: 0, color: 0xFF6D00, brightness: 0.5, effect: KeyLight.breath, speed: 0.4))
        check("a failed thread is steady", threads[5] == KeyLight(id: 5, color: 0xFF0033, brightness: 0.5, effect: KeyLight.solid, speed: 0))
        check("a strong color is sent as it is", KeyLight.split(0xFF6D00) == (0xFF6D00, 1) && KeyLight.split(0x00FF4C) == (0x00FF4C, 1))
        check("a dark color is a strong color at less light", KeyLight.split(0x606060) == (0xFFFFFF, 96.0 / 255) && KeyLight.split(0x803700).color == 0xFF6E00)
        check("black is no light", KeyLight.split(0) == (0, 0) && KeyLight.lit(3, 0, 1) == .off(3))
        check("grey is white with less light", KeyLight.lit(7, 0x606060, 0.5) == KeyLight(id: 7, color: 0xFFFFFF, brightness: 0.5 * 96 / 255, effect: KeyLight.solid, speed: 0))
        check("a key without a thread is off", threads[2] == .off(2) && threads[3] == .off(3))
        check("a state set to off is off", want.threadLights([.idle], brightness: 1) == [.off(0)])

        func actions(_ scheme: Scheme = scheme, enabled: Bool = true, wantsYou: Bool = false, waiting: Bool = false, micDown: Bool = false) -> [KeyLight] {
            scheme.actionLights(brightness: 0.5, enabled: enabled, wantsYou: wantsYou, waiting: waiting, micDown: micDown)
        }
        let rest = actions()
        check("action keys are numbered 6 to 12 on the pad", rest.map { $0.id } == [6, 7, 8, 9, 10, 11, 12])
        check("at rest every action key shows its color, softly",
              rest.map { $0.color } == [0xFFFFFF, 0xFFFFFF, 0x00FF4C, 0xFF0033, 0xFF6D00, 0xFF00C8, 0x304FFF]
              && [0, 2, 3, 4, 5].allSatisfy { rest[$0].brightness == 0.5 * 0.4 } && rest.allSatisfy { $0.effect == KeyLight.solid })
        check("SETTLE is grey: white, at well under half the light of NEW", rest[1].brightness < rest[0].brightness * 0.5 && rest[1].brightness > 0)
        check("no two action keys look the same as their neighbor", zip(rest, rest.dropFirst()).allSatisfy { $0.color != $1.color || $0.brightness != $1.brightness })
        func bright(_ lights: [KeyLight]) -> [Int] { lights.filter { $0.brightness == 0.5 }.map { $0.id } }
        check("NEXT turns bright when a thread wants you", bright(actions(wantsYou: true)) == [10])
        check("APPROVE too when one waits on an answer", bright(actions(wantsYou: true, waiting: true)) == [8, 10])
        check("MIC is bright while held", bright(actions(micDown: true)) == [11])
        let moved = scheme.actionLights(ActionKey.order(from: ["next", "approve", "stop", "new", "mic", "settle", "send"]) ?? [],
                                        brightness: 0.5, enabled: true, wantsYou: true, waiting: false, micDown: false)
        check("a changed order moves the lights with the actions", moved.map { $0.id } == [6, 7, 8, 9, 10, 11, 12]
              && moved[0].color == 0xFF6D00 && bright(moved) == [6] && moved[5].brightness == 0.5 * 0.4 * 96 / 255)
        check("actionKeys off turns all seven off", actions(enabled: false) == (6...12).map { KeyLight.off($0) })
        check("a key set to off stays off", actions(want)[3] == .off(9) && actions(want)[5].color == 0x55AAFF)
        var dark = Scheme(); dark.rest = 0
        check("rest brightness 0 leaves only called keys lit", actions(dark, wantsYou: true).filter { $0.effect != 0 }.map { $0.id } == [10])
        check("the pad gets short names", (KeyLight.lit(6, 0xFF0000, 1).payload as NSDictionary) == (["id": 6, "c": 0xFF0000, "b": 1.0, "e": 1, "s": 0.0, "sk": 0, "sa": 0] as NSDictionary))
    }

    // MARK: Key echoes

    /// The times are the ones a real knob click produced: two echoes within 5 ms of the release.
    private static func echoes() {
        func at(_ ms: Double) -> Date { Date(timeIntervalSince1970: 1_000_000 + ms / 1000) }
        var debounce = Debounce()
        let events: [(press: Bool, ms: Double, real: Bool)] = [
            (true, 0, true), (false, 178, true), (true, 180, false), (false, 181, false),
            (true, 182, false), (false, 183, false), (true, 900, true), (false, 1050, true),
        ]
        let kept = events.map { debounce.accept("ENC_CLK", press: $0.press, at: at($0.ms)) }
        check("echoes after a release are dropped, real presses are kept", kept == events.map { $0.real })
        var other = Debounce()
        _ = other.accept("AG00", press: true, at: at(0)); _ = other.accept("AG00", press: false, at: at(100))
        check("one key's release does not swallow another key's press", other.accept("AG01", press: true, at: at(101)))
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
