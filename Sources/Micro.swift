import AppKit
import ApplicationServices
import CryptoKit
import Foundation
import IOKit
import IOKit.hid

// MARK: - Device (Work Louder JSON-RPC over HID)

/// Packets are 64 bytes: report id 6, channel (2 = RPC), payload length, payload.
/// Messages are JSON objects, newline terminated on the way in.
final class Micro {
    static let vendorId = 0x303A
    static let productId = 0x8298
    static let usagePage = 0xFF00

    private(set) var device: IOHIDDevice?
    private(set) var exclusive = false
    var isOpen: Bool { device != nil }

    var onNotify: ((String, Any?) -> Void)?
    var onClosed: (() -> Void)?

    private let reportSize = 64
    private let inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 256)
    private var rx: [UInt8: [UInt8]] = [:]
    private var nextId = Int.random(in: 1...900)
    private var queue: [(method: String, params: Any?, timeout: TimeInterval, done: ([String: Any]?) -> Void)] = []
    private var inFlight: (id: Int, done: ([String: Any]?) -> Void, timer: Timer)?

    private func findService() -> io_service_t? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(kIOHIDDeviceKey), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var found: io_service_t?
        while case let service = IOIteratorNext(iterator), service != 0 {
            func prop(_ key: String) -> Int? {
                IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int
            }
            if found == nil, prop(kIOHIDVendorIDKey) == Micro.vendorId, prop(kIOHIDProductIDKey) == Micro.productId,
               prop(kIOHIDPrimaryUsagePageKey) == Micro.usagePage {
                found = service
            } else {
                IOObjectRelease(service)
            }
        }
        return found
    }

    /// True when the pad is plugged in, whether or not it can be opened.
    var isPresent: Bool {
        guard let service = findService() else { return false }
        IOObjectRelease(service)
        return true
    }

    /// Opens the vendor interface. Exclusive access stops other apps (Codex, Input) from reading it.
    @discardableResult
    func open(exclusive wantExclusive: Bool) -> Bool {
        close(notify: false)
        guard let service = findService() else { return false }
        defer { IOObjectRelease(service) }
        guard let dev = IOHIDDeviceCreate(kCFAllocatorDefault, service) else { return false }
        let options = wantExclusive ? IOOptionBits(kIOHIDOptionsTypeSeizeDevice) : IOOptionBits(kIOHIDOptionsTypeNone)
        let result = IOHIDDeviceOpen(dev, options)
        guard result == kIOReturnSuccess else {
            log("device open failed (exclusive=\(wantExclusive)): 0x\(String(UInt32(bitPattern: result), radix: 16))")
            return false
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(dev, inputBuffer, 256, { context, _, _, _, _, report, length in
            guard let context else { return }
            Unmanaged<Micro>.fromOpaque(context).takeUnretainedValue().handleReport(report, length)
        }, context)
        IOHIDDeviceRegisterRemovalCallback(dev, { context, _, _ in
            guard let context else { return }
            let me = Unmanaged<Micro>.fromOpaque(context).takeUnretainedValue()
            log("device removed")
            me.close(notify: true)
        }, context)
        IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        device = dev
        exclusive = wantExclusive
        rx.removeAll()
        return true
    }

    func close(notify: Bool) {
        if let dev = device {
            IOHIDDeviceUnscheduleFromRunLoop(dev, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(dev, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        device = nil
        exclusive = false
        if let flight = inFlight {
            flight.timer.invalidate()
            inFlight = nil
            flight.done(nil)
        }
        let dropped = queue
        queue.removeAll()
        for item in dropped { item.done(nil) }
        if notify { onClosed?() }
    }

    func call(_ method: String, _ params: Any? = nil, timeout: TimeInterval = 2.0, done: @escaping ([String: Any]?) -> Void = { _ in }) {
        guard isOpen else { done(nil); return }
        queue.append((method, params, timeout, done))
        pump()
    }

    private func pump() {
        guard inFlight == nil, !queue.isEmpty else { return }
        let item = queue.removeFirst()
        guard let dev = device else { item.done(nil); return }
        nextId = nextId >= 998 ? 1 : nextId + 1
        let id = nextId
        let message: [String: Any] = ["method": item.method, "params": item.params ?? NSNull(), "id": id]
        guard let data = try? JSONSerialization.data(withJSONObject: message) else { item.done(nil); pump(); return }
        debug("rpc > \(String(data: data, encoding: .utf8) ?? "")")
        let bytes = [UInt8](data)
        var offset = 0
        var failed = false
        while offset < bytes.count {
            let n = min(61, bytes.count - offset)
            var packet = [UInt8](repeating: 0, count: reportSize)
            packet[0] = 6
            packet[1] = 2
            packet[2] = UInt8(n)
            packet.replaceSubrange(3..<(3 + n), with: bytes[offset..<(offset + n)])
            let started = Date()
            let result = IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, 6, packet, reportSize)
            let elapsed = Date().timeIntervalSince(started)
            if elapsed > 0.2 { log("slow device write: \(String(format: "%.2f", elapsed))s, offset \(offset) of \(bytes.count)") }
            if result != kIOReturnSuccess {
                log("device write failed: 0x\(String(UInt32(bitPattern: result), radix: 16))")
                failed = true
                break
            }
            offset += n
        }
        if failed {
            item.done(nil)
            close(notify: true)
            return
        }
        let timer = Timer.scheduledTimer(withTimeInterval: item.timeout, repeats: false) { [weak self] _ in
            guard let self, let flight = self.inFlight, flight.id == id else { return }
            self.inFlight = nil
            debug("rpc timeout \(item.method)")
            flight.done(nil)
            self.pump()
        }
        inFlight = (id, item.done, timer)
    }

    private func handleReport(_ report: UnsafeMutablePointer<UInt8>, _ length: CFIndex) {
        guard length >= 3 else { return }
        let channel = report[1]
        let n = min(Int(report[2]), length - 3)
        guard n > 0 else { return }
        // Work on bytes: the device ends lines with CR LF, which Swift treats as one character.
        var buffer = rx[channel] ?? []
        buffer.append(contentsOf: UnsafeBufferPointer(start: report + 3, count: n))
        while let end = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
            let line = String(decoding: buffer[..<end], as: UTF8.self).trimmingCharacters(in: .whitespaces)
            buffer.removeSubrange(...end)
            if channel == 2, !line.isEmpty { handleLine(line) }
        }
        if buffer.count > 65_536 { buffer.removeAll() }
        rx[channel] = buffer
    }

    private func handleLine(_ line: String) {
        guard let start = line.firstIndex(of: "{"),
              let data = String(line[start...]).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        debug("rpc < \(line.prefix(300))")
        let id = (obj["id"] as? Int) ?? (obj["i"] as? Int)
        if let id, let flight = inFlight, flight.id == id {
            flight.timer.invalidate()
            inFlight = nil
            flight.done(obj)
            // The firmware wants a short gap between requests.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.pump() }
            return
        }
        if id == nil, let method = (obj["method"] as? String) ?? (obj["m"] as? String) {
            onNotify?(method, obj["params"] ?? obj["p"])
        }
    }
}


// MARK: - Files on the device

extension Micro {
    /// The firmware takes at most 4096 base64 characters per call, which is 3072 bytes.
    static let chunkBytes = 3072

    struct FileInfo {
        let size: Int
        let checksum: String
    }

    /// Name, size and SHA-1 checksum of each file on the pad.
    func listFiles(done: @escaping ([String: FileInfo]?) -> Void) {
        call("fs.list", ["checksum": true], timeout: 5) { response in
            guard let entries = response?["result"] as? [[String: Any]] else { done(nil); return }
            var files: [String: FileInfo] = [:]
            for entry in entries {
                guard let name = entry["name"] as? String else { continue }
                files[name] = FileInfo(size: entry["size"] as? Int ?? -1, checksum: entry["checksum"] as? String ?? "")
            }
            done(files)
        }
    }

    func readFile(_ name: String, done: @escaping (Data?) -> Void) {
        var collected = Data()
        func next() {
            call("fs.readbin", ["file": name, "offset": collected.count, "len": Micro.chunkBytes], timeout: 5) { response in
                guard let result = response?["result"] as? [String: Any], let total = result["total_size"] as? Int,
                      let text = result["data"] as? String, let chunk = Data(base64Encoded: text) else { done(nil); return }
                collected.append(chunk)
                if collected.count >= total { done(collected.prefix(total)); return }
                // An empty chunk before the end would loop forever.
                if chunk.isEmpty { done(nil); return }
                next()
            }
        }
        next()
    }

    /// Writes the whole file the way the Input app does, then checks the pad's checksum of it.
    func writeFile(_ name: String, _ data: Data, done: @escaping (Bool) -> Void) {
        let count = max(1, Int((Double(data.count) / Double(Micro.chunkBytes)).rounded(.up)))
        var accepted = true
        for index in 0..<count {
            let start = index * Micro.chunkBytes
            let chunk = data.subdata(in: start..<min(data.count, start + Micro.chunkBytes))
            let params: [String: Any] = ["file": name, "data": chunk.base64EncodedString(), "append": true,
                                         "completed": index == count - 1, "offset": start]
            call("fs.writebin", params, timeout: 8) { response in
                if response?["result"] == nil { accepted = false }
            }
        }
        listFiles { files in
            guard accepted, let info = files?[name] else { done(false); return }
            done(info.size == data.count && info.checksum.lowercased() == sha1(data))
        }
    }
}

func sha1(_ data: Data) -> String {
    Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
