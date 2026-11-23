import Foundation
import UserNotifications

/// Banners only show while Mel isn't frontmost (no delegate opts in), which is what REQ 5.8 asks for.
public enum Notifier {
    public static func requestAuthorization() async {
        guard let center else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// `date` in the future schedules it (usage-limit reset); otherwise it shows now.
    public static func post(title: String, body: String, at date: Date? = nil) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger(at: date)))
    }

    /// Wall-clock trigger, so a Mac that sleeps through the reset still fires on wake.
    static func trigger(at date: Date?) -> UNCalendarNotificationTrigger? {
        guard let date, date > .now else { return nil }
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
    }

    /// `current()` raises outside an app bundle (swift test, command-line tools).
    private static var center: UNUserNotificationCenter? {
        Bundle.main.bundleURL.pathExtension == "app" ? .current() : nil
    }
}
