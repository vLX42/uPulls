import AppKit
import Combine

/// Checks GitHub Releases for a newer build and installs it in place:
/// download zip → unpack → strip quarantine → swap the bundle → relaunch.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    struct Release: Equatable {
        let version: String
        let zipURL: URL
        let pageURL: URL
    }

    enum State: Equatable {
        case idle, checking, upToDate, downloading, installing
        case failed(String)
    }

    @Published private(set) var latest: Release?
    @Published private(set) var state: State = .idle
    @Published private(set) var lastChecked: Date?

    static let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    private static let releasesAPI = URL(string: "https://api.github.com/repos/vLX42/uPulls/releases/latest")!
    static let releasesPage = URL(string: "https://github.com/vLX42/uPulls/releases")!

    private var timer: Timer?

    var updateAvailable: Release? {
        guard let latest, Self.isNewer(latest.version, than: Self.currentVersion) else { return nil }
        return latest
    }

    func start(auto: Bool) {
        timer?.invalidate()
        guard auto else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in self?.check() }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }

    func check(token: String? = nil) {
        guard state != .checking, state != .downloading, state != .installing else { return }
        state = .checking
        Task {
            do {
                var req = URLRequest(url: Self.releasesAPI)
                req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                req.setValue("uPulls/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
                if let token, !token.isEmpty { req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization") }
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                    throw NSError(domain: "uPulls", code: 1, userInfo: [NSLocalizedDescriptionKey: "GitHub returned HTTP \((resp as? HTTPURLResponse)?.statusCode ?? 0)"])
                }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String,
                      let page = (json["html_url"] as? String).flatMap(URL.init),
                      let assets = json["assets"] as? [[String: Any]],
                      let zip = assets.compactMap({ $0["browser_download_url"] as? String }).first(where: { $0.hasSuffix(".zip") }).flatMap(URL.init)
                else { throw NSError(domain: "uPulls", code: 2, userInfo: [NSLocalizedDescriptionKey: "No downloadable release found"]) }
                let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                latest = Release(version: version, zipURL: zip, pageURL: page)
                NSLog("[uPulls] latest release %@ (running %@)", version, Self.currentVersion)
                lastChecked = Date()
                state = updateAvailable == nil ? .upToDate : .idle
            } catch {
                NSLog("[uPulls] update check failed: %@", error.localizedDescription)
                state = .failed(error.localizedDescription)
            }
        }
    }

    /// Replace the running bundle with the downloaded one and relaunch.
    func install() {
        guard let release = updateAvailable, state != .downloading, state != .installing else { return }
        state = .downloading
        Task {
            do {
                let (tmpZip, _) = try await URLSession.shared.download(from: release.zipURL)
                state = .installing
                let work = FileManager.default.temporaryDirectory.appendingPathComponent("uPulls-update-\(release.version)", isDirectory: true)
                try? FileManager.default.removeItem(at: work)
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                try Self.run("/usr/bin/ditto", ["-x", "-k", tmpZip.path, work.path])
                guard let newApp = Self.findApp(in: work) else {
                    throw NSError(domain: "uPulls", code: 3, userInfo: [NSLocalizedDescriptionKey: "The download did not contain an app"])
                }
                try? Self.run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

                let current = Bundle.main.bundleURL
                let backup = current.deletingLastPathComponent().appendingPathComponent(".uPulls-\(Self.currentVersion).old")
                try? FileManager.default.removeItem(at: backup)
                try FileManager.default.moveItem(at: current, to: backup)
                do {
                    try FileManager.default.moveItem(at: newApp, to: current)
                } catch {
                    try? FileManager.default.moveItem(at: backup, to: current)   // roll back
                    throw error
                }
                try? FileManager.default.removeItem(at: backup)
                try? FileManager.default.removeItem(at: work)
                NSLog("[uPulls] updated to %@ at %@, relaunching", release.version, current.path)
                Self.relaunch(current)
            } catch {
                NSLog("[uPulls] update failed: %@", error.localizedDescription)
                state = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers

    /// The zip keeps a parent folder (ditto --keepParent), so look one or two levels down.
    private static func findApp(in dir: URL, depth: Int = 0) -> URL? {
        guard depth < 3,
              let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey]) else { return nil }
        if let app = items.first(where: { $0.pathExtension == "app" }) { return app }
        for item in items where (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            if let app = findApp(in: item, depth: depth + 1) { return app }
        }
        return nil
    }

    private static func relaunch(_ app: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"\(app.path)\""
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", script]
        try? proc.run()
        NSApp.terminate(nil)
    }

    @discardableResult
    private static func run(_ tool: String, _ args: [String]) throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: tool)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard proc.terminationStatus == 0 else {
            throw NSError(domain: "uPulls", code: Int(proc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: out.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        return out
    }

    /// "1.2.0" > "1.1.9"; tolerates missing components.
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
