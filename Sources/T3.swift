import AppKit
import ApplicationServices
import Foundation
import IOKit
import IOKit.hid

// MARK: - T3 Code client

enum ThreadState: String {
    case off, idle, unread, working, awaiting, error

    /// Same colors the Codex app uses for its thread states.
    var color: Int {
        switch self {
        case .off: return 0
        case .idle: return 0xFFFFFF
        case .unread: return 0x00FF4C
        case .working: return 0x304FFE
        case .awaiting: return 0xFF6D00
        case .error: return 0xFF0033
        }
    }
}

struct Slot: Equatable {
    var environmentId: String
    var threadId: String
    var title: String
    var state: ThreadState
}

/// One thread that shows in the T3 Code sidebar: top level, not settled, not snoozed.
struct ThreadInfo {
    let environmentId: String
    let id: String
    let title: String
    let state: ThreadState
    let pinned: Bool
    let pinKey: String?
    let created: Date
    /// Sort time of the sidebar's main list: latest start or finish.
    let mainTime: Date
    /// Sort time of the sidebar's Working shelf: latest message sent.
    let sentTime: Date
    let pendingSince: Date?
    let completedAt: Date?
    /// Started or messaged by a person, as opposed to a scheduled task.
    let human: Bool

    var slot: Slot { Slot(environmentId: environmentId, threadId: id, title: title, state: state) }
}

func parseDate(_ value: Any?) -> Date? {
    guard let s = value as? String else { return nil }
    return logFormatter.date(from: s) ?? ISO8601DateFormatter().date(from: s)
}

/// One T3 server on this Mac, found through its data folder.
final class T3Source {
    let home: URL
    let name: String
    private(set) var environmentId: String?
    var threads: [ThreadInfo] = []
    var failures = 0
    private var token: String?
    private var lastIssue = Date.distantPast
    private let tokenFile: URL

    /// "desktop" for ~/.t3, and the part after ".t3-" for the others.
    static func name(ofFolder folder: String) -> String {
        folder == ".t3" ? "desktop" : folder.hasPrefix(".t3-") ? String(folder.dropFirst(4)) : folder
    }

    /// T3 data folders in the home folder: ~/.t3 and every ~/.t3-something that a server has used.
    static func foldersOnThisMac() -> [URL] {
        let names = ((try? fm.contentsOfDirectory(atPath: homeDir.path)) ?? [])
            .filter { $0 == ".t3" || $0.hasPrefix(".t3-") }
            .filter { fm.fileExists(atPath: homeDir.appendingPathComponent($0).appendingPathComponent("userdata/environment-id").path) }
        return names.sorted { ($0 == ".t3" ? "" : $0) < ($1 == ".t3" ? "" : $1) }.map { homeDir.appendingPathComponent($0) }
    }

    init(home: URL) {
        self.home = home
        let folder = home.lastPathComponent
        name = T3Source.name(ofFolder: folder)
        tokenFile = supportDir.appendingPathComponent(folder == ".t3" ? "token" : "token-\(name)")
        token = (try? String(contentsOf: tokenFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
        environmentId = (try? String(contentsOf: home.appendingPathComponent("userdata/environment-id"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runtime() -> [String: Any]? {
        guard let data = try? Data(contentsOf: home.appendingPathComponent("userdata/server-runtime.json")) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// The server's address, only when it is on this Mac and its process is alive. The token is
    /// sent there, so a stale file or an address elsewhere must not be trusted.
    private func origin() -> String? {
        guard let text = runtime()?["origin"] as? String, let host = URL(string: text)?.host else { return nil }
        guard T3Source.isThisMac(host), isRunning else { return nil }
        return text
    }

    static func isThisMac(_ host: String) -> Bool { ["127.0.0.1", "localhost", "::1", "[::1]"].contains(host.lowercased()) }

    /// The program that runs this server, when it is a `t3` command and still running.
    private func serverCommand() -> String? {
        guard let pid = runtime()?["pid"] as? Int, pid > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(Int32(pid), &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let path = String(cString: buffer)
        return URL(fileURLWithPath: path).lastPathComponent == "t3" ? path : nil
    }

    var isRunning: Bool {
        guard let pid = runtime()?["pid"] as? Int, pid > 0 else { return false }
        return kill(Int32(pid), 0) == 0 || errno == EPERM
    }

    /// The `t3` command to ask this server for a token. Servers on one Mac can run different
    /// versions, so the first choice is the very program that runs this one.
    func cli() -> String {
        var candidates = [serverCommand(), home.appendingPathComponent("bin/t3").path].compactMap { $0 }
        let versions = home.appendingPathComponent("runtime/versions")
        if let version = runtime()?["serverVersion"] as? String {
            candidates.append(versions.appendingPathComponent("\(version)/t3").path)
        }
        if let names = try? fm.contentsOfDirectory(atPath: versions.path) {
            for version in names.sorted(by: { $0.compare($1, options: .numeric) == .orderedDescending }) {
                candidates.append(versions.appendingPathComponent("\(version)/t3").path)
            }
        }
        candidates.append(t3CLI)
        return candidates.first { fm.isExecutableFile(atPath: $0) } ?? t3CLI
    }

    /// Asks that server's own command for a read-only token. At most once every five minutes.
    private func issueToken() {
        guard Date().timeIntervalSince(lastIssue) > 300 else { return }
        lastIssue = Date()
        let command = cli()
        debug("t3 \(name): asking \(command) for a token")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = ["auth", "session", "issue", "--base-dir", home.path, "--scope", "orchestration:read",
                             "--ttl", "90d", "--label", T3Source.sessionLabel, "--token-only"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let value = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            guard process.terminationStatus == 0, value.count > 20, !value.contains(" ") else {
                log("t3 \(name): could not issue a token (exit \(process.terminationStatus))")
                return
            }
            try value.write(to: tokenFile, atomically: true, encoding: .utf8)
            try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenFile.path)
            token = value
            log("t3 \(name): issued a new read-only token")
        } catch {
            log("t3 \(name): could not run the t3 command: \(error.localizedDescription)")
        }
    }

    static let sessionLabel = "Micro 2 bridge"

    private func runCLI(_ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cli())
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }

    /// Revokes every session this bridge issued on that server. Returns how many.
    func revokeOwnSessions() -> Int {
        var count = 0
        if let data = runCLI(["auth", "session", "list", "--json", "--base-dir", home.path]),
           let sessions = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for session in sessions {
                guard (session["client"] as? [String: Any])?["label"] as? String == T3Source.sessionLabel,
                      let id = session["sessionId"] as? String else { continue }
                if runCLI(["auth", "session", "revoke", "--base-dir", home.path, id]) != nil { count += 1 }
            }
        }
        try? fm.removeItem(at: tokenFile)
        token = nil
        return count
    }

    static func state(of t: [String: Any]) -> ThreadState {
        if let pending = t["pendingRuntimeRequest"] as? [String: Any], (pending["blocking"] as? Bool) != false {
            return .awaiting
        }
        if let activity = t["activityRunStatus"] as? String, !activity.isEmpty { return .working }
        if t["activeRunId"] is String { return .working }
        let status = t["status"] as? String ?? "idle"
        if ["preparing", "queued", "starting", "running", "waiting"].contains(status) { return .working }
        if status == "failed" { return .error }
        if let completed = parseDate(t["latestRunCompletedAt"]) {
            guard let visited = parseDate(t["lastVisitedAt"]) else { return .unread }
            if completed > visited { return .unread }
        }
        return .idle
    }

    private func parse(_ t: [String: Any], environmentId: String, now: Date) -> ThreadInfo? {
        func isSet(_ v: Any?) -> Bool { v != nil && !(v is NSNull) }
        func time(_ keys: [String]) -> Date { keys.compactMap { parseDate(t[$0]) }.max() ?? .distantPast }
        if isSet(t["deletedAt"]) || isSet(t["archivedAt"]) { return nil }
        if let lineage = t["lineage"] as? [String: Any], isSet(lineage["parentThreadId"]) { return nil }
        if let until = parseDate(t["snoozedUntil"]), until > now { return nil }
        if (t["settledOverride"] as? String) == "settled" { return nil }
        guard let id = t["id"] as? String else { return nil }
        let sentKey = isSet(t["latestUserAuthoredMessageAt"]) ? "latestUserAuthoredMessageAt" : "latestRunRequestedAt"
        let source = t["creationSource"] as? String ?? ""
        let pending = t["pendingRuntimeRequest"] as? [String: Any]
        return ThreadInfo(
            environmentId: environmentId, id: id, title: t["title"] as? String ?? "",
            state: T3Source.state(of: t), pinned: isSet(t["pinnedAt"]), pinKey: t["pinOrderKey"] as? String,
            created: time(["createdAt"]),
            mainTime: time(["createdAt", "unsettledAt", "latestRunRequestedAt", "latestRunCompletedAt"]),
            sentTime: time(["createdAt", sentKey]),
            pendingSince: parseDate(pending?["createdAt"]), completedAt: parseDate(t["latestRunCompletedAt"]),
            human: source == "web" || source == "mobile" || isSet(t["latestUserAuthoredMessageAt"]))
    }

    /// Refreshes `threads`. Calls back on the main queue.
    func fetch(session: URLSession, done: @escaping () -> Void) {
        if token == nil { issueToken() }
        guard let token, let origin = origin(), let environmentId,
              let url = URL(string: origin + "/api/orchestration/shell?omitIdleSubagents=true&omitOlderSettled=true") else {
            failures += 1
            done(); return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2", forHTTPHeaderField: "x-t3-orchestration-protocol")
        session.dataTask(with: request) { [weak self] data, response, _ in
            var parsed: [ThreadInfo]?
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200, let data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let raw = obj["threads"] as? [[String: Any]], let self {
                let now = Date()
                parsed = raw.compactMap { self.parse($0, environmentId: environmentId, now: now) }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if status == 401 || status == 403 {
                    log("t3 \(self.name): token rejected (\(status)), asking for a new one")
                    self.token = nil
                }
                if let parsed {
                    self.threads = parsed
                    self.failures = 0
                } else {
                    self.failures += 1
                    if self.failures == 3 {
                        log("t3 \(self.name): not answering, dropping its threads")
                        self.threads = []
                    }
                }
                done()
            }
        }.resume()
    }
}

final class T3Client {
    let sources: [T3Source]
    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 6
        return URLSession(configuration: c)
    }()

    init(homes: [String]) {
        sources = homes.map(expand)
            .filter { fm.fileExists(atPath: $0.appendingPathComponent("userdata").path) }
            .map(T3Source.init)
    }

    /// Refreshes every source, then hands back all sidebar threads. Nil when no source answers.
    func fetchAll(done: @escaping ([ThreadInfo]?) -> Void) {
        let group = DispatchGroup()
        for source in sources {
            group.enter()
            source.fetch(session: session) { group.leave() }
        }
        group.notify(queue: .main) { [sources] in
            if sources.allSatisfy({ $0.failures >= 3 }) { done(nil); return }
            done(sources.flatMap { $0.threads })
        }
    }

    private static func byPin(_ a: ThreadInfo, _ b: ThreadInfo) -> Bool {
        switch (a.pinKey, b.pinKey) {
        case let (x?, y?): return x == y ? a.id < b.id : x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: return a.created == b.created ? a.id < b.id : a.created > b.created
        }
    }

    private static func newest(_ key: KeyPath<ThreadInfo, Date>) -> (ThreadInfo, ThreadInfo) -> Bool {
        { a, b in a[keyPath: key] == b[keyPath: key] ? a.id < b.id : a[keyPath: key] > b[keyPath: key] }
    }

    /// The T3 Code sidebar read top to bottom: Pinned, the main list, then the Working shelf.
    static func sidebarOrder(_ all: [ThreadInfo]) -> [ThreadInfo] {
        let pinned = all.filter { $0.pinned }.sorted(by: byPin)
        let main = all.filter { !$0.pinned && $0.state != .working }.sorted(by: newest(\.mainTime))
        let working = all.filter { !$0.pinned && $0.state == .working }.sorted(by: newest(\.sentTime))
        return pinned + main + working
    }

    /// Threads that want you: waiting on an answer (longest wait first), failed, then finished and unread.
    static func attention(_ all: [ThreadInfo]) -> [ThreadInfo] {
        let waiting = all.filter { $0.state == .awaiting }
            .sorted { ($0.pendingSince ?? .distantPast, $0.id) < ($1.pendingSince ?? .distantPast, $1.id) }
        let failed = all.filter { $0.state == .error }.sorted(by: newest(\.mainTime))
        let unread = all.filter { $0.state == .unread }
            .sorted { ($0.completedAt ?? .distantPast) == ($1.completedAt ?? .distantPast) ? $0.id < $1.id : ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        return waiting + failed + unread
    }

    /// What needs you first, then your own running work, then scheduled work, then idle threads.
    static func priorityOrder(_ all: [ThreadInfo]) -> [ThreadInfo] {
        let working = all.filter { $0.state == .working }
        let idle = all.filter { $0.state == .idle || $0.state == .off }
        return attention(all)
            + working.filter { $0.human }.sorted(by: newest(\.sentTime))
            + working.filter { !$0.human }.sorted(by: newest(\.sentTime))
            + idle.filter { $0.pinned }.sorted(by: byPin)
            + idle.filter { !$0.pinned }.sorted(by: newest(\.mainTime))
    }

    static func slots(from all: [ThreadInfo], order: String) -> [Slot?] {
        let ordered = order == "sidebar" ? sidebarOrder(all) : priorityOrder(all)
        var result: [Slot?] = ordered.prefix(6).map { $0.slot }
        while result.count < 6 { result.append(nil) }
        return result
    }
}

