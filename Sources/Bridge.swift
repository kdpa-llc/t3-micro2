import AppKit
import ApplicationServices
import Foundation
import IOKit
import IOKit.hid

// MARK: - Bridge

final class Bridge {
    var config = Config.load()
    let micro = Micro()
    lazy var t3 = T3Client(homes: config.t3Homes)
    lazy var actions = Actions(bundleId: config.t3BundleId)
    lazy var shortcuts = Shortcuts(file: expand(config.t3Homes.first ?? "~/.t3").appendingPathComponent("userdata/keybindings.json"))

    var layer: Int?
    var all: [ThreadInfo] = []
    var slots: [Slot?] = Array(repeating: nil, count: 6)
    var haveT3Data = false
    var statusFailures = 0
    var lastThreadsKey = ""
    var lastConfigKey = ""
    var lastAssert = Date.distantPast
    var lastT3Poll = Date.distantPast
    var t3Fetching = false
    var joystickArmed = true
    var lastTick = Date.distantPast
    let inputBundleId = "it.focusense.input-app"

    /// Advanced mode adds hold actions and the joystick. Kept across restarts.
    var advanced = false
    private var pressTimers: [String: Timer] = [:]
    private var pickerOpenUntil = Date.distantPast
    private var nextCursor = 0
    private var nextQueueKey = ""
    private var lastNextPress = Date.distantPast
    private var flashUntil = Date.distantPast
    private var flashColor = 0
    private var trusted: Bool?
    private var lastTrustCheck = Date.distantPast
    private var lastStatusKey = ""
    private var lastStatusWrite = Date.distantPast

    var onT3Layer: Bool { micro.isOpen && micro.exclusive }

    func loadState() {
        if let data = try? Data(contentsOf: stateURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            advanced = obj["advanced"] as? Bool ?? false
        }
    }

    private func saveState() {
        if let data = try? JSONSerialization.data(withJSONObject: ["advanced": advanced]) { try? data.write(to: stateURL) }
    }

    func start() {
        loadState()
        micro.onNotify = { [weak self] method, params in self?.handleNotify(method, params) }
        micro.onClosed = { [weak self] in
            self?.layer = nil
            self?.lastThreadsKey = ""
            self?.lastConfigKey = ""
        }
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        // macOS shows its Accessibility question once per app. Ask at the first start, not at the first key press.
        if config.actionKeys, !AXIsProcessTrusted() { _ = actions.canSendKeys }
        log("bridge \(bridgeVersion) started: T3 layer \(config.t3LayerIndex), \(advanced ? "advanced" : "simple") mode, \(config.slotOrder) order, sources \(t3.sources.map { $0.name }.joined(separator: " + "))")
    }

    /// Presses the shortcut T3 Code has for a command.
    private func run(_ command: String) {
        guard let shortcut = shortcuts.key(command) else {
            log("no usable shortcut for \(command) in T3 Code")
            return
        }
        actions.tap(shortcut.code, shortcut.flags)
    }

    /// Writes the Accessibility state to the log when it changes, so `t3-micro2 status` can show it.
    private func noteAccessibility(_ now: Date) {
        guard now.timeIntervalSince(lastTrustCheck) >= 5 else { return }
        lastTrustCheck = now
        let state = AXIsProcessTrusted()
        if state != trusted {
            trusted = state
            log("accessibility: \(state ? "granted" : "not granted")")
        }
    }

    /// Keeps status.json current: rewritten when something changed, and once a minute so its age shows the bridge is alive.
    private func writeStatus(_ now: Date) {
        var status: [String: Any] = [
            "version": bridgeVersion, "pid": Int(ProcessInfo.processInfo.processIdentifier),
            "pad": micro.isOpen ? "connected" : "missing", "t3Layer": config.t3LayerIndex, "holding": onT3Layer,
            "mode": advanced ? "advanced" : "simple", "order": config.slotOrder,
            "sources": t3.sources.map { $0.name }.joined(separator: ", "), "threads": all.count, "wantYou": T3Client.attention(all).count,
            "t3Answers": haveT3Data,
        ]
        if let layer { status["layer"] = layer }
        if let trusted { status["accessibility"] = trusted }
        guard let body = try? JSONSerialization.data(withJSONObject: status, options: [.sortedKeys]) else { return }
        let key = String(decoding: body, as: UTF8.self)
        guard key != lastStatusKey || now.timeIntervalSince(lastStatusWrite) >= 60 else { return }
        lastStatusKey = key
        lastStatusWrite = now
        status["updated"] = logFormatter.string(from: now)
        if let data = try? JSONSerialization.data(withJSONObject: status, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: statusURL, options: .atomic)
        }
    }

    private func tick() {
        let now = Date()
        noteAccessibility(now)
        writeStatus(now)
        let interval = onT3Layer ? config.activePollSeconds : config.idlePollSeconds
        if now.timeIntervalSince(lastTick) >= interval {
            lastTick = now
            pollDevice()
        }
        if onT3Layer, !t3Fetching, now.timeIntervalSince(lastT3Poll) >= config.t3PollSeconds {
            pollT3()
            actions.warmUp()
        }
    }

    private func pollDevice() {
        if !micro.isOpen {
            if micro.open(exclusive: false) { log("device connected") } else { return }
        }
        micro.call("device.status", timeout: 1.5) { [weak self] response in
            guard let self else { return }
            guard let result = response?["result"] as? [String: Any], let index = result["layer_index"] as? Int else {
                self.statusFailures += 1
                if self.statusFailures >= 4, self.micro.isOpen {
                    log("device stopped answering, reconnecting")
                    self.statusFailures = 0
                    self.micro.close(notify: true)
                }
                return
            }
            self.statusFailures = 0
            // Reopening the device must not happen inside its own report callback.
            DispatchQueue.main.async { self.layerChanged(to: index) }
        }
    }

    private func layerChanged(to index: Int) {
        if layer != index {
            log("device layer \(layer.map(String.init) ?? "?") -> \(index)")
            layer = index
        }
        // The Input app needs the device to save changes, so let go while it is in front.
        let inputInFront = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == inputBundleId
        let wantExclusive = index == config.t3LayerIndex && !inputInFront
        guard wantExclusive != micro.exclusive else { return }
        if wantExclusive {
            guard micro.open(exclusive: true) else { return }
            log("T3 layer active: holding the device, Codex and Input are paused")
            lastThreadsKey = ""
            lastConfigKey = ""
            applyLighting()
            pollT3()
        } else {
            // Releasing lets Codex reconnect and repaint its own colors.
            guard micro.open(exclusive: false) else { return }
            log(inputInFront ? "Input app is in front: device released" : "left the T3 layer: device released")
        }
    }

    func pollT3(then: (() -> Void)? = nil) {
        t3Fetching = true
        lastT3Poll = Date()
        t3.fetchAll { [weak self] threads in
            guard let self else { return }
            self.t3Fetching = false
            defer { then?() }
            guard let threads else {
                if self.haveT3Data {
                    log("T3 Code is not answering, turning the thread lights off")
                    self.all = []
                    self.slots = Array(repeating: nil, count: 6)
                    self.haveT3Data = false
                    self.applyLighting()
                }
                return
            }
            self.all = threads
            let next = T3Client.slots(from: threads, order: self.config.slotOrder)
            if next != self.slots || !self.haveT3Data {
                self.slots = next
                self.haveT3Data = true
                let summary = next.enumerated().map { i, s in "\(i + 1)=\(s.map { "\($0.state.rawValue):\($0.title.prefix(22))" } ?? "-")" }
                log("threads: " + summary.joined(separator: " | "))
            }
            self.applyLighting()
        }
    }

    private func applyLighting() {
        guard onT3Layer else { return }
        let b = config.brightness
        let threads: [[String: Any]] = slots.enumerated().map { index, slot in
            guard let slot, slot.state != .off else {
                return ["id": index, "c": 0, "b": 0, "e": 0, "s": 0, "sk": 0, "sa": 0]
            }
            let pulsing = slot.state == .awaiting
            return ["id": index, "c": slot.state.color, "b": b, "e": pulsing ? 4 : 1, "s": pulsing ? 0.4 : 0, "sk": 0, "sa": 0]
        }
        // The ring looks at every thread, not only the six on the keys.
        let states = Set(all.map { $0.state })
        var ambient: [String: Any] = ["e": 0, "b": 0, "s": 0, "m": 0, "c": 0]
        if Date() < flashUntil {
            ambient = ["e": 1, "b": b, "s": 0, "m": 0, "c": flashColor]
        } else if states.contains(.awaiting) {
            ambient = ["e": 4, "b": b, "s": 0.4, "m": 0, "c": ThreadState.awaiting.color]
        } else if states.contains(.working) {
            ambient = ["e": 2, "b": b, "s": 0.4, "m": 0, "c": ThreadState.working.color]
        } else if states.contains(.error) {
            ambient = ["e": 1, "b": b, "s": 0, "m": 0, "c": ThreadState.error.color]
        } else if states.contains(.unread) {
            ambient = ["e": 1, "b": b, "s": 0, "m": 0, "c": ThreadState.unread.color]
        }
        let keys: [String: Any] = config.keysBacklight
            ? ["e": 1, "b": b * 0.4, "s": 0, "m": 0, "c": 0xFFFFFF]
            : ["e": 0, "b": 0, "s": 0, "m": 0, "c": 0]
        let rgb: [String: Any] = ["ambient": ambient, "keys": keys]

        func key(_ value: Any) -> String {
            (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])).map { String(decoding: $0, as: UTF8.self) } ?? ""
        }
        let force = Date().timeIntervalSince(lastAssert) > 15
        if force { lastAssert = Date() }
        let configKey = key(rgb), threadsKey = key(threads)
        if force || configKey != lastConfigKey {
            lastConfigKey = configKey
            micro.call("v.oai.rgbcfg", rgb) { response in
                if response?["result"] == nil { log("lighting config was not accepted") }
            }
        }
        if force || threadsKey != lastThreadsKey {
            lastThreadsKey = threadsKey
            micro.call("v.oai.thstatus", threads) { response in
                if response?["result"] == nil { log("thread colors were not accepted") }
            }
        }
    }

    /// Shows one color on the ring for a moment, as feedback.
    private func flash(_ color: Int, seconds: Double = 1.4) {
        flashColor = color
        flashUntil = Date().addingTimeInterval(seconds)
        applyLighting()
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds + 0.05) { [weak self] in self?.applyLighting() }
    }

    // MARK: Input from the device

    private func handleNotify(_ method: String, _ params: Any?) {
        guard onT3Layer else { return }
        let p = params as? [String: Any] ?? [:]
        switch method {
        case "v.oai.hid":
            guard let key = p["k"] as? String else { return }
            let act = (p["act"] as? Int) ?? -1
            log("key \(key) act=\(act)")
            handleKey(key, act)
        case "v.oai.rad":
            guard let angle = p["a"] as? Double, let distance = p["d"] as? Double else { return }
            handleJoystick(angle, distance)
        default:
            debug("notify \(method)")
        }
    }

    /// act: 1 = press, 0 = release, 2 = one knob step.
    func handleKey(_ key: String, _ act: Int) {
        if key == "ENC_CW" || key == "ENC_CC" {
            if act == 2 { knobTurn(clockwise: key == "ENC_CW") }
            return
        }
        if key == "ACT10" {
            // Dictation: T3 Code treats a long press as hold-to-talk and a short one as start/stop.
            guard config.actionKeys else { return }
            guard let mic = shortcuts.key("composer.dictation") else { return }
            if act == 1 { actions.hold("mic", mic.code, mic.flags, down: true) }
            if act == 0 { actions.hold("mic", mic.code, mic.flags, down: false) }
            return
        }
        // Keys with a hold action wait for the release to tell a tap from a hold.
        let waitsForHold = advanced || key == "ENC_CLK"
        if act == 1 {
            guard waitsForHold else { perform(key, hold: false); return }
            pressTimers[key]?.invalidate()
            let delay = key == "ENC_CLK" ? 1.2 : config.holdSeconds
            pressTimers[key] = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.pressTimers[key] = nil
                self.perform(key, hold: true)
            }
        } else if act == 0, let timer = pressTimers.removeValue(forKey: key) {
            timer.invalidate()
            perform(key, hold: false)
        }
    }

    private func open(_ slot: Slot) {
        actions.open("t3code://threads/\(slot.environmentId)/\(slot.threadId)")
    }

    private func perform(_ key: String, hold: Bool) {
        if key.hasPrefix("AG0"), let index = Int(key.dropFirst(3)), (0..<6).contains(index) {
            guard let slot = slots[index] else {
                actions.t3App?.activate(options: [.activateAllWindows])
                return
            }
            log("\(hold ? "settle" : "open") thread \(index + 1): \(slot.title)")
            open(slot)
            if hold {
                // Settle works on the thread in view, so wait for T3 Code to show it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in self?.run("thread.settle") }
            }
            return
        }
        if key == "ENC_CLK" {
            if hold { toggleMode() } else { knobClick() }
            return
        }
        guard config.actionKeys else { return }
        switch (key, hold) {
        case ("ACT06", false): openNext()
        case ("ACT07", false): actions.pressButton(labels: ["Approve"])
        case ("ACT07", true): actions.pressButton(labels: ["Decline"])
        case ("ACT08", false): run("thread.stop")
        case ("ACT09", false): actions.open("t3code://new")
        case ("ACT09", true): run("chat.newWithoutProject")
        case ("ACT11", false): run("thread.settle")
        case ("ACT11", true): run("thread.pin")
        case ("ACT12", false): actions.tap(36)                               // Return: send
        case ("ACT12", true): actions.tap(36, [.maskCommand])                // Command+Return
        default: break
        }
    }

    /// Opens the next thread that wants you. Pressing again moves down the queue.
    private func openNext() {
        let queue = T3Client.attention(all)
        guard !queue.isEmpty else {
            log("next: nothing is waiting on you")
            flash(ThreadState.unread.color, seconds: 0.8)
            return
        }
        let queueKey = queue.map { $0.id }.joined(separator: ",")
        if queueKey != nextQueueKey || Date().timeIntervalSince(lastNextPress) > 45 {
            nextCursor = 0
            nextQueueKey = queueKey
        }
        let thread = queue[nextCursor % queue.count]
        nextCursor += 1
        lastNextPress = Date()
        log("next: \(thread.state.rawValue) \(thread.title) (\(queue.count) in the queue)")
        open(thread.slot)
    }

    /// First click opens the model picker. While it is open, turn to move and click to choose.
    private func knobClick() {
        if Date() < pickerOpenUntil {
            pickerOpenUntil = .distantPast
            actions.tap(36)
        } else {
            pickerOpenUntil = Date().addingTimeInterval(10)
            run("modelPicker.toggle")
        }
    }

    private func knobTurn(clockwise: Bool) {
        if Date() < pickerOpenUntil {
            pickerOpenUntil = Date().addingTimeInterval(10)
            actions.tap(clockwise ? 125 : 126)                               // arrow down or up
        } else {
            run(clockwise ? "thread.next" : "thread.previous")
        }
    }

    private func toggleMode() {
        advanced.toggle()
        saveState()
        for timer in pressTimers.values { timer.invalidate() }
        pressTimers.removeAll()
        log("mode: \(advanced ? "advanced" : "simple")")
        flash(advanced ? 0x8A5CFF : 0xFFFFFF)
    }

    /// Advanced mode only. Angle: 0 right, 0.25 down, 0.5 left, 0.75 up. One action per push.
    func handleJoystick(_ angle: Double, _ distance: Double) {
        if distance < 0.2 { joystickArmed = true; return }
        guard joystickArmed, distance > 0.7, config.actionKeys, advanced else { return }
        joystickArmed = false
        if angle >= 0.625 && angle < 0.875 { log("joystick up"); run("composer.effort") }
        else if angle >= 0.125 && angle < 0.375 { log("joystick down"); run("sidebar.toggle") }
        else if angle >= 0.375 && angle < 0.625 { log("joystick left"); run("navigation.back") }
        else { log("joystick right"); run("navigation.forward") }
    }
}
