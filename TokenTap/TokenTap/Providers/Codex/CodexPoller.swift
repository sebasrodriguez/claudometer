import Foundation

/// Spawns an ephemeral Codex CLI process via PTY, sends /status, captures output.
final class CodexPoller: Sendable {

    func pollUsage(codexPath: String? = nil) async throws -> String {
        let binary = try findBinary(override: codexPath)
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
        var ws = winsize()
        ws.ws_col = 200
        ws.ws_row = 50

        let pid = forkpty(&masterFd, nil, nil, &ws)

        if pid < 0 {
            throw PollerError.spawnFailed("forkpty failed: \(String(cString: strerror(errno)))")
        }

        if pid == 0 {
            // Child process
            let home = NSHomeDirectory()
            setenv("HOME", home, 1)
            setenv("USER", NSUserName(), 1)
            setenv("TERM", "dumb", 1)
            setenv("NO_COLOR", "1", 1)
            let currentPath = String(cString: getenv("PATH") ?? strdup("/usr/bin:/bin"))
            setenv("PATH", "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:\(currentPath)", 1)
            chdir(home)

            let cPath = strdup(binaryPath)!
            let argv: [UnsafeMutablePointer<CChar>?] = [cPath, nil]
            execv(binaryPath, argv)
            _exit(127)
        }

        // Parent process
        defer {
            kill(pid, SIGTERM)
            usleep(200_000)
            kill(pid, SIGKILL)
            var status: Int32 = 0
            waitpid(pid, &status, 0)
            close(masterFd)
        }

        // Wait for Codex to initialize
        let _ = readUntilStable(fd: masterFd, timeout: 15.0, stableFor: 1.5)
        usleep(1_000_000)

        // Type "/status" with delays
        for byte in Array("/status".utf8) {
            var b = byte
            Darwin.write(masterFd, &b, 1)
            usleep(50_000)
        }

        // Wait for autocomplete, drain, press Enter
        usleep(500_000)
        let _ = readUntilStable(fd: masterFd, timeout: 3.0, stableFor: 0.5)
        var cr: UInt8 = 0x0D
        Darwin.write(masterFd, &cr, 1)

        // Wait for output
        usleep(3_000_000)
        let output = readUntilStable(fd: masterFd, timeout: 15.0, stableFor: 2.0)

        if output.isEmpty {
            throw PollerError.noOutput
        }

        return output
    }

    private func readUntilStable(fd: Int32, timeout: TimeInterval, stableFor: TimeInterval) -> String {
        var accumulated = Data()
        let startTime = Date()
        var lastDataTime = Date()
        var buffer = [UInt8](repeating: 0, count: 8192)

        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        defer { _ = fcntl(fd, F_SETFL, flags) }

        while true {
            if Date().timeIntervalSince(startTime) >= timeout { break }
            if Date().timeIntervalSince(lastDataTime) >= stableFor && !accumulated.isEmpty { break }

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

    private func findBinary(override: String?) throws -> String {
        if let override = override, !override.isEmpty {
            if FileManager.default.isExecutableFile(atPath: override) {
                return override
            }
            throw PollerError.claudeNotFound
        }

        let home = NSHomeDirectory()
        let candidates = [
            "/opt/homebrew/bin/codex",
            "\(home)/.local/bin/codex",
            "/usr/local/bin/codex",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Try which via login shell
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-l", "-c", "which codex"]
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
