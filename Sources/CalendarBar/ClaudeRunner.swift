import Foundation

enum ClaudeError: LocalizedError {
    case launchFailed(String)
    case failed(String)
    case timeout
    case badOutput(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let m): return "Couldn't run claude: \(m)"
        case .failed(let m): return m
        case .timeout: return "claude timed out."
        case .badOutput(let m): return "Couldn't read Claude's reply: \(m)"
        }
    }
}

/// Runs headless Claude Code (`claude -p`) so it fetches events with its own Google Calendar connector.
enum ClaudeRunner {
    static func fetchEventsJSON(executable: String, model: String, from: Date, to: Date, timeout: TimeInterval = 180) async throws -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssxxx"
        let prompt = """
        Use the Google Calendar tools to list events from every calendar I have selected \
        between \(f.string(from: from)) and \(f.string(from: to)) (timezone \(TimeZone.current.identifier)). \
        Skip cancelled events. Reply with ONLY a JSON array, no prose and no code fences. Each element: \
        {"id":string,"title":string,"start":ISO8601 with offset (date-only YYYY-MM-DD for all-day),\
        "end":same,"allDay":bool,"location":string|null,"link":string|null,"declined":bool}. \
        "declined" is true if I declined the invite.
        """
        var args = ["-p", prompt,
                    "--output-format", "json",
                    "--allowedTools", "mcp__claude_ai_Google_Calendar",
                    "--no-session-persistence"]
        if !model.isEmpty { args += ["--model", model] }

        let out = try await run(executable, args, timeout: timeout)
        guard let data = out.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeError.badOutput(String(out.prefix(300)))
        }
        let result = obj["result"] as? String ?? ""
        if obj["is_error"] as? Bool == true { throw ClaudeError.failed(result) }
        guard let lo = result.firstIndex(of: "["), let hi = result.lastIndex(of: "]"), lo < hi else {
            throw ClaudeError.badOutput(String(result.prefix(300)))
        }
        return String(result[lo...hi])
    }

    private static func run(_ executable: String, _ args: [String], timeout: TimeInterval) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let p = Process()
            // Login shell so PATH (and the claude install location) resolve for a GUI-launched app.
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            p.arguments = ["-l", "-c", "exec \"$0\" \"$@\"", executable] + args
            p.currentDirectoryURL = FileManager.default.temporaryDirectory
            let out = Pipe(), err = Pipe()
            p.standardOutput = out
            p.standardError = err
            p.standardInput = FileHandle.nullDevice

            var outData = Data(), errData = Data()
            let lock = NSLock()
            out.fileHandleForReading.readabilityHandler = { h in
                let d = h.availableData; lock.lock(); outData.append(d); lock.unlock()
            }
            err.fileHandleForReading.readabilityHandler = { h in
                let d = h.availableData; lock.lock(); errData.append(d); lock.unlock()
            }
            var timedOut = false
            p.terminationHandler = { proc in
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                lock.lock()
                let o = String(decoding: outData + out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                let e = String(decoding: errData, as: UTF8.self)
                let to = timedOut
                lock.unlock()
                if to { cont.resume(throwing: ClaudeError.timeout) }
                else if proc.terminationStatus != 0 && o.isEmpty {
                    cont.resume(throwing: ClaudeError.failed(e.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else { cont.resume(returning: o) }
            }
            do { try p.run() } catch {
                cont.resume(throwing: ClaudeError.launchFailed(error.localizedDescription)); return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if p.isRunning { lock.lock(); timedOut = true; lock.unlock(); p.terminate() }
            }
        }
    }
}
