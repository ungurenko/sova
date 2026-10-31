import AppKit
import SovaCore
import UserNotifications

enum Notifier {
    static func requestPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(_ text: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "Sova"
        content.body = text
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: SessionController!
    private var statusMenu: StatusMenu!
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A second copy must not start: its cleanup below would end the first copy's session.
        if let id = Bundle.main.bundleIdentifier, NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return
        }
        let support = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Sova")
        let hold = PmsetHold(journal: support.appendingPathComponent("session"))
        hold.recoverLeftover()

        controller = SessionController(
            hold: hold,
            now: { Date() },
            battery: { PowerSources.battery() },
            thermal: { ProcessInfo.processInfo.thermalState },
            notify: { Notifier.post($0) }
        )
        statusMenu = StatusMenu(controller: controller)
        Notifier.requestPermission()

        PowerSources.observe { [weak self] in self?.controller.conditionsChanged() }
        let recheck: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.controller.conditionsChanged() }
        }
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main, using: recheck)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: recheck)

        // A plain kill must give sleep back too.
        for signalNumber in [SIGTERM, SIGINT, SIGHUP] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated {
                    self?.controller.shutdown()
                    NSApp.terminate(nil)
                }
            }
            source.resume()
            signalSources.append(source)
        }

        // `Sova --seconds 90` starts a session at launch (used to test the real thing).
        let args = CommandLine.arguments
        let longest = Rules.durations.map(\.seconds).max() ?? 0
        if let flag = args.firstIndex(of: "--seconds"), flag + 1 < args.count,
           let seconds = Double(args[flag + 1]), seconds >= 1, seconds <= longest {
            controller.start(seconds: seconds)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
