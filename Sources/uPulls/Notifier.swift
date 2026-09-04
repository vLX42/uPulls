import AppKit
import UserNotifications

/// Thin wrapper over UNUserNotificationCenter. Notifications only work from a
/// real .app bundle, so everything degrades to a no-op under `swift run`.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    let isAvailable: Bool = Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil

    private override init() {
        super.init()
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(title: String, body: String, subtitle: String? = nil, url: URL, thread: String, sound: Bool = true) {
        guard isAvailable else {
            NSLog("[uPulls] %@ — %@", title, body)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let subtitle { content.subtitle = subtitle }
        content.threadIdentifier = thread
        content.userInfo = ["url": url.absoluteString]
        if sound { content.sound = .default }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        let center = UNUserNotificationCenter.current()
        center.add(request) { error in
            if let error { NSLog("[uPulls] notification failed: %@", error.localizedDescription) }
        }
        center.getNotificationSettings { s in
            NSLog("[uPulls] notification authorization=%d alerts=%d", s.authorizationStatus.rawValue, s.alertSetting.rawValue)
        }
    }

    // Menu-bar apps are "active" surprisingly often; always show the banner.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard let raw = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: raw) else { return }
        await MainActor.run { NSWorkspace.shared.open(url) }
    }
}
