/// When the built-in display is dimmed to black after the lid closes.
/// (Not turned off: a display that sleeps locks the Mac, see ScreenKeeper.)
/// Pure: no IOKit, no running commands.
public enum LidPolicy {
    /// The display is dimmed only while a session is running, the menu setting is on,
    /// the lid is closed and no external display is connected (clamshell mode keeps that one on).
    public static func shouldDimDisplay(
        sessionActive: Bool,
        turnOffDisplayOnLidClose: Bool,
        lidClosed: Bool,
        hasExternalDisplay: Bool
    ) -> Bool {
        sessionActive && turnOffDisplayOnLidClose && lidClosed && !hasExternalDisplay
    }
}
