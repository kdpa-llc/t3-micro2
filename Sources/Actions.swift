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

    private var screenIsLocked: Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        return (session?["CGSSessionScreenIsLocked"] as? NSNumber)?.boolValue ?? false
    }

    /// Brings T3 Code to the front, then runs the block. A key press goes to whichever app is in
    /// front, so the block runs only once that app is T3 Code, and not at all if it never is.
    private func withT3Frontmost(_ block: @escaping () -> Void) {
        guard let app = t3App else { log("T3 Code is not running, so the key press was not sent"); return }
        if t3IsInFront { block(); return }
        // Behind the lock screen a key press would land in the password field.
        guard !screenIsLocked else { log("the screen is locked, so the key press was not sent"); return }
        bringForward(app)
        waitForT3(app, since: Date(), reopened: false, block)
    }

    /// Asks for the front twice over: macOS can ignore the plain request from a background app,
    /// and the accessibility one still works then.
    private func bringForward(_ app: NSRunningApplication) {
        app.activate(options: [.activateAllWindows])
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.5)
        AXUIElementSetAttributeValue(element, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    }

    /// Opening the app again is what a click on its Dock icon does. It also brings back a hidden window.
    private func reopen(_ app: NSRunningApplication) {
        guard let url = app.bundleURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: nil)
    }

    private func waitForT3(_ app: NSRunningApplication, since start: Date, reopened: Bool, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            let waited = Date().timeIntervalSince(start)
            if t3IsInFront {
                // Give its window a moment to take the keyboard, then look once more.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                    if t3IsInFront { block() } else { log("T3 Code lost the front before the key press, so nothing was sent") }
                }
            } else if waited > 0.5, !reopened {
                reopen(app)
                waitForT3(app, since: start, reopened: true, block)
            } else if waited < 2.0 {
                waitForT3(app, since: start, reopened: reopened, block)
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

