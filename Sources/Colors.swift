import Foundation

/// The seven actions below the thread keys, in the order their keys sit on the pad:
/// row 3 from the left, then row 4. `actionOrder` in the settings can change the order.
///
/// Row 4, nearest the hand, is what you press all day, in the order you press it: go to the
/// thread, talk, send. Row 3 holds the four actions you decide on, as two pairs. NEW and SETTLE
/// start a thread and put one away. APPROVE and STOP let a run go on and end it, with APPROVE
/// on the left, as accept is left of cancel in a dialog.
enum ActionKey: String, CaseIterable {
    case new, settle, approve, stop, next, mic, send

    /// The pad numbers its keys 0 to 12. Thread keys are 0 to 5, so the first action key is 6.
    static let firstId = 6

    /// An order from the settings: all seven names, each once. Nil for anything else.
    static func order(from names: [String]) -> [ActionKey]? {
        let order = names.compactMap { ActionKey(rawValue: $0) }
        return names.count == allCases.count && Set(order).count == allCases.count ? order : nil
    }

    /// The action on a key, by the name the bridge has for the key: ACT06 is the first key of `order`.
    static func on(_ key: String, in order: [ActionKey]) -> ActionKey? {
        guard key.hasPrefix("ACT"), let number = Int(key.dropFirst(3)), order.indices.contains(number - firstId) else { return nil }
        return order[number - firstId]
    }
}

/// What the pad is told about one key's light.
struct KeyLight: Equatable {
    static let solid = 1, breath = 4

    var id: Int
    var color = 0
    var brightness = 0.0
    var effect = 0
    var speed = 0.0

    static func off(_ id: Int) -> KeyLight { KeyLight(id: id) }

    /// A color at a brightness. Black, or no brightness, turns the key off.
    static func lit(_ id: Int, _ color: Int, _ brightness: Double, pulsing: Bool = false) -> KeyLight {
        let (hue, level) = split(color)
        guard level > 0, brightness > 0 else { return off(id) }
        return KeyLight(id: id, color: hue, brightness: brightness * level, effect: pulsing ? breath : solid, speed: pulsing ? 0.4 : 0)
    }

    /// An LED has no grey or brown: a dark color is a strong color at less light. This takes the
    /// two apart, so #606060 becomes white at 38% and looks grey beside a key at full white.
    static func split(_ color: Int) -> (color: Int, level: Double) {
        let channels = [(color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF]
        guard let peak = channels.max(), peak > 0 else { return (0, 0) }
        let full = channels.map { Int((Double($0) * 255 / Double(peak)).rounded()) }
        return (full[0] << 16 | full[1] << 8 | full[2], Double(peak) / 255)
    }

    var payload: [String: Any] { ["id": id, "c": color, "b": brightness, "e": effect, "s": speed, "sk": 0, "sa": 0] }
}

/// Every color the bridge shows. Read from colors.json, which people may edit.
struct Scheme: Equatable {
    var threads: [ThreadState: Int] = [
        .awaiting: 0xFF6D00, .error: 0xFF0033, .unread: 0x00FF4C, .working: 0x304FFE, .idle: 0xFFFFFF,
    ]
    var keys: [ActionKey: Int] = [
        .next: 0xFF6D00, .approve: 0x00FF4C, .stop: 0xFF0033, .new: 0xFFFFFF,
        .mic: 0xFF00C8, .settle: 0x606060, .send: 0x304FFE,
    ]
    var simple = 0xFFFFFF
    var advanced = 0x8A5CFF
    /// How bright an action key is while nothing calls for it, as a share of full brightness.
    var rest = 0.4

    /// The names the file uses for thread states. They are the words of the README.
    static let threadNames: [(name: String, state: ThreadState)] = [
        ("waiting", .awaiting), ("failed", .error), ("finished", .unread), ("working", .working), ("idle", .idle),
    ]

    /// The file written when there is none. It lists the keys in the order they sit on the pad.
    static let defaultFile = """
    {
      "threads": {
        "waiting": "#FF6D00",
        "failed": "#FF0033",
        "finished": "#00FF4C",
        "working": "#304FFE",
        "idle": "#FFFFFF"
      },
      "keys": {
        "new": "#FFFFFF",
        "settle": "#606060",
        "approve": "#00FF4C",
        "stop": "#FF0033",
        "next": "#FF6D00",
        "mic": "#FF00C8",
        "send": "#304FFE"
      },
      "modes": {
        "simple": "#FFFFFF",
        "advanced": "#8A5CFF"
      },
      "restBrightness": 0.4
    }

    """

    func color(_ state: ThreadState) -> Int { threads[state] ?? 0 }
    func color(_ key: ActionKey) -> Int { keys[key] ?? 0 }

    /// "#FF6D00", "FF6D00" or "0xFF6D00" as a packed color. "off" is black, which turns a light off.
    static func parse(color text: String) -> Int? {
        var hex = text.trimmingCharacters(in: .whitespaces).lowercased()
        if hex == "off" { return 0 }
        if hex.hasPrefix("#") { hex.removeFirst() } else if hex.hasPrefix("0x") { hex.removeFirst(2) }
        guard hex.count == 6, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        return Int(hex, radix: 16)
    }

    /// Reads a colors file. Anything missing keeps its default, and anything unreadable is named in `problems`.
    static func parse(_ data: Data) -> (scheme: Scheme, problems: [String]) {
        var scheme = Scheme()
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (scheme, ["the file is not a JSON object, so every color is the default"])
        }
        var problems: [String] = []
        func color(_ section: String, _ name: String) -> Int? {
            guard let value = (root[section] as? [String: Any])?[name] else { return nil }
            if let text = value as? String, let parsed = parse(color: text) { return parsed }
            problems.append("\(section).\(name) is not a color such as \"#FF6D00\" or \"off\", so it keeps its default")
            return nil
        }
        for (name, state) in threadNames {
            if let value = color("threads", name) { scheme.threads[state] = value }
        }
        for key in ActionKey.allCases {
            if let value = color("keys", key.rawValue) { scheme.keys[key] = value }
        }
        if let value = color("modes", "simple") { scheme.simple = value }
        if let value = color("modes", "advanced") { scheme.advanced = value }
        if let value = root["restBrightness"] {
            // JSONSerialization gives true and false as numbers too, so rule them out by type.
            if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), (0...1).contains(number.doubleValue) {
                scheme.rest = number.doubleValue
            } else {
                problems.append("restBrightness is not a number from 0 to 1, so it keeps its default")
            }
        }
        let known: [String: [String]] = [
            "threads": threadNames.map { $0.name }, "keys": ActionKey.allCases.map { $0.rawValue },
            "modes": ["simple", "advanced"],
        ]
        for (section, value) in root.sorted(by: { $0.key < $1.key }) where section != "restBrightness" {
            guard let names = known[section] else { problems.append("\(section) is not a setting of this file"); continue }
            guard let entries = value as? [String: Any] else { problems.append("\(section) is not an object"); continue }
            for name in entries.keys.sorted() where !names.contains(name) {
                problems.append("\(section).\(name) is not a setting of this file. \(section) has \(names.joined(separator: ", "))")
            }
        }
        return (scheme, problems)
    }

    /// The scheme in colors.json. Writes the file with the defaults when there is none.
    static func load() -> Scheme {
        guard let data = try? Data(contentsOf: colorsURL) else {
            try? Data(defaultFile.utf8).write(to: colorsURL)
            return Scheme()
        }
        let (scheme, problems) = parse(data)
        for problem in problems { log("colors.json: \(problem)") }
        return scheme
    }

    // MARK: What each key shows

    /// The six thread keys. A thread that waits on you pulses.
    func threadLights(_ states: [ThreadState?], brightness: Double) -> [KeyLight] {
        states.enumerated().map { index, state in
            guard let state, state != .off else { return .off(index) }
            return .lit(index, color(state), brightness, pulsing: state == .awaiting)
        }
    }

    /// The seven action keys, in the order they sit on the pad. Each keeps its own color, at rest
    /// brightness. A key turns bright when something calls for it: NEXT while a thread wants you,
    /// APPROVE while one waits on an answer, and MIC while it is held.
    func actionLights(_ order: [ActionKey] = ActionKey.allCases, brightness: Double, enabled: Bool,
                      wantsYou: Bool, waiting: Bool, micDown: Bool) -> [KeyLight] {
        order.enumerated().map { index, key in
            let id = ActionKey.firstId + index
            guard enabled else { return .off(id) }
            let called = (key == .next && wantsYou) || (key == .approve && waiting) || (key == .mic && micDown)
            return .lit(id, color(key), called ? brightness : brightness * rest)
        }
    }
}
