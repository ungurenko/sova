import Foundation

/// The one user choice that is not part of a session: whether Sova darkens the screen
/// (lid closed, or idle) during a session. Stored in UserDefaults; on by default.
enum Settings {
    private static let turnDisplayOffOnLidCloseKey = "turnDisplayOffOnLidClose"

    static var turnDisplayOffOnLidClose: Bool {
        get { UserDefaults.standard.object(forKey: turnDisplayOffOnLidCloseKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: turnDisplayOffOnLidCloseKey) }
    }
}
