import Foundation

/// When the display goes dark because nobody touched the Mac. Pure: no IOKit, no running commands.
///
/// During a session the system's own display sleep is held off (a locked Mac would cut agents
/// off from the desktop), so Sova dims the built-in display by itself after the same idle time
/// the user set in System Settings.
public enum IdlePolicy {
    /// Used when the system value cannot be read.
    public static let fallback: TimeInterval = 600

    public static func shouldDim(sessionActive: Bool, idleSeconds: TimeInterval, threshold: TimeInterval?) -> Bool {
        guard sessionActive, let threshold else { return false }
        return idleSeconds >= threshold
    }

    /// The `displaysleep` minutes in `pmset -g` output. `nil` means "never" (0 minutes),
    /// so nothing is dimmed; an unreadable output gives `fallback`.
    public static func threshold(fromPmset output: String) -> TimeInterval? {
        for line in output.split(whereSeparator: \.isNewline) {
            let words = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard words.count >= 2, words[0] == "displaysleep", let minutes = Int(words[1]) else { continue }
            return minutes <= 0 ? nil : TimeInterval(minutes * 60)
        }
        return fallback
    }
}
