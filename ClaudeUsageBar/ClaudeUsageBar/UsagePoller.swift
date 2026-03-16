import Foundation

enum PollerError: LocalizedError {
    case claudeNotFound
    case timeout
    case spawnFailed(String)
    case noOutput

    var errorDescription: String? {
        switch self {
        case .claudeNotFound:
            return "Claude CLI not found. Install it or set the path in Settings."
        case .timeout:
            return "Timed out waiting for Claude to respond."
        case .spawnFailed(let msg):
            return "Failed to spawn Claude: \(msg)"
        case .noOutput:
            return "No output captured from Claude."
        }
    }
}

final class UsagePoller: Sendable {

    func pollUsage(claudePath: String? = nil) async throws -> String {
        let binary = try findClaudeBinary(override: claudePath)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.runWithForkPty(binaryPath: binary)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runWithForkPty(binaryPath: String) throws -> String {
        var masterFd: Int32 = 0

        // Set up window size
        var ws = winsize()
        ws.ws_col = 200
        ws.ws_row = 50

        let pid = forkpty(&masterFd, nil, nil, &ws)

        if pid < 0 {
            throw PollerError.spawnFailed("forkpty failed: \(String(cString: strerror(errno)))")
        }

        if pid == 0 {
            // ---- Child process ----
            let home = NSHomeDirectory()
            setenv("HOME", home, 1)
            setenv("USER", NSUserName(), 1)
            setenv("TERM", "dumb", 1)
            setenv("NO_COLOR", "1", 1)
            setenv("CLAUDE_NO_TELEMETRY", "1", 1)
            let currentPath = String(cString: getenv("PATH") ?? strdup("/usr/bin:/bin"))
            setenv("PATH", "\(home)/.local/bin:\(home)/.claude/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\(currentPath)", 1)
            chdir(home)

            let cPath = strdup(binaryPath)!
            let arg1 = strdup("--dangerously-skip-permissions")!
            let argv: [UnsafeMutablePointer<CChar>?] = [cPath, arg1, nil]
            execv(binaryPath, argv)
            _exit(127)
        }

        // ---- Parent process ----
        defer {
            kill(pid, SIGTERM)
            usleep(200_000)
            kill(pid, SIGKILL)
            var status: Int32 = 0
            waitpid(pid, &status, 0)
            close(masterFd)
        }

        // Phase 1: Wait for Claude to initialize
        let _ = readUntilStable(fd: masterFd, timeout: 15.0, stableFor: 1.5)

        // Let TUI fully initialize its input handler
        usleep(1_000_000) // 1s

        // Phase 2: Type "/usage" with delays between chars for autocomplete
        for byte in Array("/usage".utf8) {
            var b = byte
            Darwin.write(masterFd, &b, 1)
            usleep(50_000) // 50ms between chars
        }

        // Wait for autocomplete to settle, then drain rendering
        usleep(500_000)
        let _ = readUntilStable(fd: masterFd, timeout: 3.0, stableFor: 0.5)

        // Press Enter to execute
        var cr: UInt8 = 0x0D
        Darwin.write(masterFd, &cr, 1)

        // Phase 3: Wait for usage data to be fetched and rendered
        usleep(3_000_000) // 3s
        let usageOutput = readUntilStable(fd: masterFd, timeout: 15.0, stableFor: 2.0)

        if usageOutput.isEmpty {
            throw PollerError.noOutput
        }

        return usageOutput
    }

    /// Read from fd until no new data arrives for `stableFor` seconds, or `timeout` is reached.
    private func readUntilStable(fd: Int32, timeout: TimeInterval, stableFor: TimeInterval) -> String {
        var accumulated = Data()
        let startTime = Date()
        var lastDataTime = Date()
        var buffer = [UInt8](repeating: 0, count: 8192)

        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        defer { _ = fcntl(fd, F_SETFL, flags) }

        while true {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= timeout { break }

            let sinceLastData = Date().timeIntervalSince(lastDataTime)
            if sinceLastData >= stableFor && !accumulated.isEmpty { break }

            let n = Darwin.read(fd, &buffer, buffer.count)
            if n > 0 {
                accumulated.append(contentsOf: buffer[0..<n])
                lastDataTime = Date()
            } else if n == 0 {
                break
            } else {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    usleep(50_000)
                } else {
                    break
                }
            }
        }

        return String(data: accumulated, encoding: .utf8) ?? ""
    }

    private func findClaudeBinary(override: String?) throws -> String {
        if let override = override, !override.isEmpty {
            if FileManager.default.isExecutableFile(atPath: override) {
                return override
            }
            throw PollerError.claudeNotFound
        }

        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try `which claude` via login shell
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-l", "-c", "which claude"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty,
               FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        throw PollerError.claudeNotFound
    }
}
