import AppKit
import ApplicationServices
import Foundation
import IOKit
import IOKit.hid

// MARK: - Actions on the T3 Code window

final class Actions {
    let bundleId: String
    private var warnedAccessibility = false
    private var heldKeys: [String: (code: CGKeyCode, flags: CGEventFlags)] = [:]

    init(bundleId: String) { self.bundleId = bundleId }

    var t3App: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
    }

    func open(_ link: String) {
        guard let url = URL(string: link) else { return }
        NSWorkspace.shared.open(url)
    }

    var canSendKeys: Bool {
        if AXIsProcessTrusted() { return true }
        if !warnedAccessibility {
            warnedAccessibility = true
            log("action keys need Accessibility permission for T3 Micro Bridge (System Settings, Privacy & Security, Accessibility)")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        return false
    }

    /// True when T3 Code is the app that gets the keyboard.
    private var t3IsInFront: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleId
    }

    /// Brings T3 Code to the front, then runs the block. Key presses go to whichever app is in
    /// front, so the block runs only once that app is T3 Code, and not at all if it never is.
    private func withT3Frontmost(_ block: @escaping () -> Void) {
        guard let app = t3App else { log("T3 Code is not running"); return }
        if t3IsInFront { block(); return }
        app.activate(options: [.activateAllWindows])
        waitForT3(until: Date().addingTimeInterval(1.5), block)
    }

    private func waitForT3(until deadline: Date, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            if t3IsInFront {
                // Give its window a moment to take the keyboard, then look once more.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                    if t3IsInFront { block() } else { log("T3 Code lost the front before the key press, so nothing was sent") }
                }
            } else if Date() < deadline {
                waitForT3(until: deadline, block)
            } else {
                log("T3 Code did not come to the front, so the key press was not sent")
            }
        }
    }

    private func post(_ code: CGKeyCode, _ flags: CGEventFlags, down: Bool) {
        guard let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: code, keyDown: down) else { return }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    func tap(_ code: CGKeyCode, _ flags: CGEventFlags = []) {
        guard canSendKeys else { return }
        withT3Frontmost { [self] in
            post(code, flags, down: true)
            post(code, flags, down: false)
        }
    }

    func hold(_ name: String, _ code: CGKeyCode, _ flags: CGEventFlags, down: Bool) {
        guard canSendKeys else { return }
        if down {
            heldKeys[name] = (code, flags)
            withT3Frontmost { [self] in
                // Released before T3 came to the front: send a full tap instead.
                post(code, flags, down: true)
                if heldKeys[name] == nil { post(code, flags, down: false) }
            }
        } else if let held = heldKeys.removeValue(forKey: name) {
            post(held.code, held.flags, down: false)
        }
    }

    private var warmedPid: pid_t = 0

    /// Electron builds its accessibility tree only after a client asks for it. Ask once per launch.
    func warmUp() {
        guard AXIsProcessTrusted(), let app = t3App, app.processIdentifier != warmedPid else { return }
        warmedPid = app.processIdentifier
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(root, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    /// Presses a button in the T3 Code window by its label, through the accessibility tree.
    /// Searches bottom-up, so the newest prompt (lowest in the window) wins.
    func pressButton(labels: [String]) {
        guard canSendKeys, let app = t3App else { return }
        warmUp()
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 1.0)
        let wanted = Set(labels.map { $0.lowercased() })
        func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
            var value: AnyObject?
            return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
        }
        var stack: [AXUIElement] = [root]
        var visited = 0
        let deadline = Date().addingTimeInterval(2.5)
        var match: AXUIElement?
        while let element = stack.popLast(), visited < 8000, Date() < deadline {
            visited += 1
            if (attribute(element, kAXRoleAttribute) as? String) == kAXButtonRole {
                let names = [kAXTitleAttribute, kAXDescriptionAttribute].compactMap { attribute(element, $0) as? String }
                if names.contains(where: { wanted.contains($0.lowercased()) }) { match = element; break }
            }
            // Children are pushed in order, so the last child is looked at first.
            if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] { stack.append(contentsOf: children) }
        }
        if let match {
            let result = AXUIElementPerformAction(match, kAXPressAction as CFString)
            log("pressed \(labels.first ?? "") in T3 Code: \(result == .success ? "ok" : "failed \(result.rawValue)")")
        } else {
            log("no \(labels.first ?? "") button found in T3 Code (looked at \(visited) elements)")
        }
    }
}

