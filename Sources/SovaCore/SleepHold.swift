import Foundation

/// Keeps the Mac from sleeping with the lid closed, and can always give sleep back.
public protocol SleepHold {
    /// `nil` means the session runs until it is stopped.
    func engage(until: Date?) throws
    /// Safe to call when nothing is engaged.
    func release() throws
    /// At launch: a journal left by a previous run means that run died with sleep still off.
    func recoverLeftover()
}

public struct HoldError: Error, LocalizedError, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// `sudo -n pmset -a disablesleep 1|0`, the one thing Sova does as root.
///
/// The journal (one line: the session end as Unix seconds) is written before
/// sleep is switched off and removed after it is switched back on, so a crash
/// at any point leaves a trace. scripts/guard.sh reads the same file.
public struct PmsetHold: SleepHold {
    public typealias Run = (_ tool: String, _ args: [String]) throws -> (status: Int32, output: String)

    static let sudo = "/usr/bin/sudo"
    static let pmset = "/usr/bin/pmset"

    /// A session without an end is written to the journal as this instant (31.12.9999),
    /// so scripts/guard.sh sees a future time and only acts when Sova is gone.
    public static let neverEnds = Date(timeIntervalSince1970: 253_402_300_799)

    private let journal: URL
    private let run: Run

    public init(journal: URL, run: @escaping Run = PmsetHold.runProcess) {
        self.journal = journal
        self.run = run
    }

    public func engage(until: Date?) throws {
        let end = until ?? Self.neverEnds
        try FileManager.default.createDirectory(at: journal.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "\(Int(end.timeIntervalSince1970))\n".write(to: journal, atomically: true, encoding: .utf8)
        do {
            try setSleepDisabled(true)
        } catch {
            abandon()
            throw error
        }
        // Read it back: the menu must not claim a hold that macOS did not take.
        let state = try? run(Self.pmset, ["-g"])
        guard let state, Self.parseSleepDisabled(state.output) else {
            try? release()
            throw HoldError("macOS не включила запрет сна (в pmset нет SleepDisabled 1)")
        }
    }

    public func release() throws {
        do {
            try setSleepDisabled(false)
        } catch {
            // Mark the session as already over, so guard.sh finishes the job
            // even while this program is still alive.
            if FileManager.default.fileExists(atPath: journal.path) {
                try? "0\n".write(to: journal, atomically: true, encoding: .utf8)
            }
            throw error
        }
        try? FileManager.default.removeItem(at: journal)
    }

    public func recoverLeftover() {
        guard FileManager.default.fileExists(atPath: journal.path) else { return }
        try? release()
    }

    /// A switch-on failed or timed out, so nobody knows whether it landed. Read the real state:
    /// SleepDisabled 0 means nothing was changed and the journal is dropped; SleepDisabled 1 (or
    /// an unreadable state) means the journal is marked expired so the guard gives sleep back.
    private func abandon() {
        let state = try? run(Self.pmset, ["-g"])
        let sleepDisabled = state.map { Self.parseSleepDisabled($0.output) } ?? true
        if sleepDisabled {
            try? "0\n".write(to: journal, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: journal)
        }
    }

    private func setSleepDisabled(_ on: Bool) throws {
        let r = try run(Self.sudo, ["-n", Self.pmset, "-a", "disablesleep", on ? "1" : "0"])
        guard r.status == 0 else {
            let hint = r.output.contains("password") ? " Нет разрешения: запусти scripts/install.sh." : ""
            throw HoldError("pmset вернул \(r.status).\(hint)")
        }
    }

    static func parseSleepDisabled(_ output: String) -> Bool {
        output.split(whereSeparator: \.isNewline).contains { line in
            let words = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            return words.count >= 2 && words[0] == "SleepDisabled" && words[1] == "1"
        }
    }

    /// Runs a tool and gives up on it after 10 seconds, so a stuck sudo cannot freeze the menu.
    public static func runProcess(_ tool: String, _ args: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        try process.run()
        if finished.wait(timeout: .now() + 10) == .timedOut {
            process.terminate()
            _ = finished.wait(timeout: .now() + 3)
            throw HoldError("команда \(tool) не ответила за 10 секунд")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
