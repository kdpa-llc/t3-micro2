import AppKit
import Foundation

/// One key press: a virtual key code and its modifiers.
struct Shortcut: Equatable {
    var code: CGKeyCode
    var flags: CGEventFlags

    static func == (a: Shortcut, b: Shortcut) -> Bool { a.code == b.code && a.flags.rawValue == b.flags.rawValue }
}

/// The T3 Code shortcuts the bridge presses. They are read from T3 Code's own
/// keybindings file, so shortcuts you changed there still work.
final class Shortcuts {
    /// T3 Code's defaults, used when the file has no binding for a command.
    static let defaults: [String: String] = [
        "thread.settle": "mod+shift+s",
        "thread.pin": "mod+shift+p",
        "thread.stop": stopDefault,
        "thread.next": "mod+shift+]",
        "thread.previous": "mod+shift+[",
        "modelPicker.toggle": "mod+shift+m",
        "composer.effort": "mod+shift+e",
        "composer.dictation": "mod+shift+d",
        "sidebar.toggle": "mod+b",
        "navigation.back": "mod+[",
        "navigation.forward": "mod+]",
        "chat.newWithoutProject": "mod+alt+n",
    ]

    /// T3 Code ships no shortcut for stopping a run, so setup adds this one.
    static let stopCommand = "thread.stop"
    static let stopDefault = "mod+alt+x"

    /// Key codes of a US keyboard, by the name T3 Code uses.
    private static let keyCodes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13,
        "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25,
        "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38,
        "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "`": 50,
        "enter": 36, "return": 36, "tab": 48, "space": 49, "backspace": 51, "escape": 53, "esc": 53, "delete": 117,
        "arrowleft": 123, "arrowright": 124, "arrowdown": 125, "arrowup": 126,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100, "f9": 101, "f10": 109,
        "f11": 103, "f12": 111,
    ]

    /// Turns "mod+shift+s" into a key press. Nil for a key this table does not know.
    static func parse(_ text: String) -> Shortcut? {
        var parts = text.lowercased().split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard let key = parts.popLast(), let code = keyCodes[key] else { return nil }
        var flags: CGEventFlags = []
        for part in parts {
            switch part {
            case "mod", "cmd", "meta", "command": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "alt", "option": flags.insert(.maskAlternate)
            case "ctrl", "control": flags.insert(.maskControl)
            default: return nil
            }
        }
        return Shortcut(code: code, flags: flags)
    }

    /// The last binding of each command in a keybindings file that this table can press.
    static func bindings(in file: Data) -> [String: String] {
        guard let entries = (try? JSONValue.parse(file))?.items else { return [:] }
        var found: [String: String] = [:]
        for entry in entries {
            guard let command = entry["command"]?.text, let key = entry["key"]?.text, parse(key) != nil else { continue }
            found[command] = key
        }
        return found
    }

    private let file: URL
    private var loaded: [String: String] = [:]
    private var stamp: Date?

    init(file: URL) {
        self.file = file
        reload()
    }

    private func reload() {
        stamp = (try? fm.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
        loaded = (try? Data(contentsOf: file)).map(Shortcuts.bindings) ?? [:]
    }

    /// The key press for a T3 Code command. Reads the file again when it changed.
    func key(_ command: String) -> Shortcut? {
        let now = (try? fm.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
        if now != stamp { reload() }
        return (loaded[command] ?? Shortcuts.defaults[command]).flatMap(Shortcuts.parse)
    }

    func text(_ command: String) -> String? { loaded[command] ?? Shortcuts.defaults[command] }

    /// True when T3 Code's file has a shortcut for the command.
    func isSet(_ command: String) -> Bool { loaded[command] != nil }

    // MARK: The stop shortcut

    enum StopChange: Equatable {
        /// `thread.stop` already has this shortcut.
        case present(String)
        /// The default key is used by another command, so nothing was added.
        case taken(by: String)
        /// The new file, with the shortcut added at the end.
        case add(Data)
    }

    static func addingStop(to file: Data) throws -> StopChange {
        let root = try JSONValue.parse(file)
        guard let entries = root.items else { throw JSONValue.ParseError(description: "the keybindings file is not a list") }
        if let existing = entries.last(where: { $0["command"]?.text == stopCommand })?["key"]?.text {
            return .present(existing)
        }
        if let other = entries.first(where: { $0["key"]?.text?.lowercased() == stopDefault })?["command"]?.text {
            return .taken(by: other)
        }
        let entry = JSONValue.object([
            .init(key: "key", value: .text(stopDefault)),
            .init(key: "command", value: .text(stopCommand)),
            .init(key: "when", value: .text("!terminalFocus")),
        ])
        return .add(Data((JSONValue.array(entries + [entry]).pretty() + "\n").utf8))
    }

    /// The file without the shortcut setup adds. Nil when it is not there, or was changed since.
    static func removingStop(from file: Data) throws -> Data? {
        guard let entries = try JSONValue.parse(file).items else { return nil }
        let kept = entries.filter { !($0["command"]?.text == stopCommand && $0["key"]?.text == stopDefault) }
        if kept.count == entries.count { return nil }
        return Data((JSONValue.array(kept).pretty() + "\n").utf8)
    }
}
