import Foundation

/// Reads the token the GitHub CLI already holds so most developers need no setup.
enum GHCLI {
    enum Outcome {
        case token(String)
        case notInstalled
        case failed(String)
    }

    static func token() -> Outcome {
        let candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        guard let gh = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return .notInstalled
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: gh)
        proc.arguments = ["auth", "token"]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = out
        do {
            try proc.run()
            proc.waitUntilExit()
            let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if proc.terminationStatus == 0, !text.isEmpty, !text.contains(" ") {
                return .token(text)
            }
            return .failed(text.isEmpty ? "gh returned nothing. Run `gh auth login` first." : text)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
