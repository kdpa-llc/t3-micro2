import Foundation

/// Works out how to give the pad a "T3 Code" layer: a copy of the ChatGPT
/// layer, whose keys report to the computer instead of typing.
///
/// The pad lights a key by itself only when the key has an AG name. The ChatGPT layer
/// gives those to its six thread keys and calls the other seven ACT, so they stay dark.
/// The T3 layer names all 13 keys AG, and the bridge can then color each one.
enum Keymap {
    static let fileName = "keymap.json"
    static let layerName = "T3 Code"
    static let vendorPrefix = "KV_OAI_"
    static let darkPrefix = "KV_OAI_ACT"
    static let litPrefix = "KV_OAI_AG"

    enum Plan: Equatable {
        /// The layer is already on the pad, at this number.
        case present(number: Int)
        /// Layer `number`, now called `replacing`, becomes the T3 layer. `file` is the new keymap.
        case change(number: Int, replacing: String, file: Data)
    }

    enum Problem: Error, Equatable, CustomStringConvertible {
        case unreadable(String)
        case noVendorLayer
        case noFreeLayer([String])
        case noSuchLayer(Int, count: Int)
        case isVendorLayer(Int)

        var description: String {
            switch self {
            case let .unreadable(why):
                return "the pad's keymap file could not be read: \(why)"
            case .noVendorLayer:
                return "the pad has no ChatGPT layer to copy. This needs a Creator Micro 2 with the ChatGPT layer."
            case let .noFreeLayer(names):
                return "every layer has keys on it (\(names.joined(separator: ", "))). "
                    + "Run setup with --layer N to turn layer N into the T3 layer. The file from before is kept as a backup."
            case let .noSuchLayer(number, count):
                return "there is no layer \(number). The pad has \(count)."
            case let .isVendorLayer(number):
                return "layer \(number) is the ChatGPT layer, which Codex uses. Pick another one."
            }
        }
    }

    struct Layer {
        let number: Int
        let name: String
        let vendor: Bool
        let empty: Bool
        /// Every key of the layer can take a color: none has an ACT name.
        let lit: Bool
    }

    /// The name the bridge uses for a key the pad reports. The T3 layer calls its action keys
    /// AG06 to AG12 so they light up; they are still ACT06 to ACT12 to the bridge.
    static func keyName(_ reported: String) -> String {
        guard reported.hasPrefix("AG"), let number = Int(reported.dropFirst(2)), number >= 6 else { return reported }
        return String(format: "ACT%02d", number)
    }

    /// The layer with its action keys renamed so the pad lights them.
    private static func lit(_ layer: JSONValue) -> JSONValue {
        guard let layout = layer["layout"], let rows = layout["keymap"]?.items else { return layer }
        let renamed: [JSONValue] = rows.map { row in
            guard let keys = row.items else { return row }
            return .array(keys.map { key in
                guard case let .string(raw) = key, raw.hasPrefix(darkPrefix) else { return key }
                return .string(litPrefix + raw.dropFirst(darkPrefix.count))
            })
        }
        return layer.setting("layout", to: layout.setting("keymap", to: .array(renamed)))
    }

    /// Path to the active profile's layer list, then the layers themselves.
    private static func locate(_ root: JSONValue) throws -> (profile: Int, layers: [JSONValue]) {
        guard let profiles = root["profiles"]?.items, !profiles.isEmpty else {
            throw Problem.unreadable("it has no profiles")
        }
        let active = root["activeProfileId"]?.int
        let index = profiles.firstIndex { $0["id"]?.int == active } ?? 0
        guard let layers = profiles[index]["layers"]?.items, !layers.isEmpty else {
            throw Problem.unreadable("the active profile has no layers")
        }
        return (index, layers)
    }

    private static func keys(of layer: JSONValue) -> [String] {
        let layout = layer["layout"]
        let rows = (layout?["keymap"]?.items ?? []) + (layout?["encoders"]?.items ?? [])
        return rows.flatMap { $0.items ?? [] }.compactMap { $0.text }
    }

    private static func describe(_ layer: JSONValue, _ number: Int) -> Layer {
        let all = keys(of: layer)
        return Layer(number: number, name: layer["name"]?.text ?? "Layer \(number)",
                     vendor: all.contains { $0.hasPrefix(vendorPrefix) },
                     empty: !all.isEmpty && all.allSatisfy { $0 == "KC_NONE" },
                     lit: !all.contains { $0.hasPrefix(darkPrefix) })
    }

    static func layers(in file: Data) throws -> [Layer] {
        let root: JSONValue
        do { root = try JSONValue.parse(file) } catch { throw Problem.unreadable("\(error)") }
        return try locate(root).layers.enumerated().map { describe($1, $0 + 1) }
    }

    /// `replace` is a layer number, counted from 1 as the pad and the Input app count them.
    static func plan(file: Data, replace: Int? = nil) throws -> Plan {
        let root: JSONValue
        do { root = try JSONValue.parse(file) } catch { throw Problem.unreadable("\(error)") }
        let (profileIndex, layers) = try locate(root)
        let info = layers.enumerated().map { describe($1, $0 + 1) }

        let named = info.first { $0.name == layerName }
        if let named, named.vendor, named.lit, replace == nil || replace == named.number {
            return .present(number: named.number)
        }
        // A T3 layer from before all keys lit up is its own source when the ChatGPT layer is gone.
        let chatGPT = info.first { $0.vendor && $0.name != layerName }
        guard let source = chatGPT ?? named.flatMap({ $0.vendor ? $0 : nil }) else { throw Problem.noVendorLayer }

        let target: Layer
        if let replace {
            guard let chosen = info.first(where: { $0.number == replace }) else {
                throw Problem.noSuchLayer(replace, count: info.count)
            }
            guard chosen.number != chatGPT?.number else { throw Problem.isVendorLayer(replace) }
            target = chosen
        } else if let named {
            target = named
        } else if let free = info.first(where: { $0.empty }) {
            target = free
        } else {
            throw Problem.noFreeLayer(info.map { "\($0.number) \($0.name)" })
        }

        // The copy keeps the place, id and color of the layer it replaces.
        let old = layers[target.number - 1]
        var copy = lit(layers[source.number - 1]).setting("name", to: .text(layerName))
        if let id = old["id"] { copy = copy.setting("id", to: id) }
        if let color = old["color"] { copy = copy.setting("color", to: color) }

        var newLayers = layers
        newLayers[target.number - 1] = copy
        guard var profiles = root["profiles"]?.items else { throw Problem.unreadable("it has no profiles") }
        profiles[profileIndex] = profiles[profileIndex].setting("layers", to: .array(newLayers))
        let newRoot = root.setting("profiles", to: .array(profiles))
        return .change(number: target.number, replacing: target.name, file: Data(newRoot.compact.utf8))
    }
}
