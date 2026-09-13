import Foundation
import UserNotifications

enum WaveReminderID {
    static let hours24 = "line24.wave-24"
    static let hours48 = "line24.wave-48"
    static var all: [String] { [hours24, hours48] }
}

enum WaveReminderTiming {
    static let hours24: TimeInterval = 24 * 60 * 60
    static let hours48: TimeInterval = 48 * 60 * 60

    /// Returns fire dates that are still in the future; past windows are skipped.
    static func futureFireDates(
        startedAt: Date,
        now: Date = Date(),
        interval24: TimeInterval = hours24,
        interval48: TimeInterval = hours48
    ) -> [(id: String, date: Date)] {
        var result: [(id: String, date: Date)] = []
        let at24 = startedAt.addingTimeInterval(interval24)
        let at48 = startedAt.addingTimeInterval(interval48)
        if at24 > now {
            result.append((WaveReminderID.hours24, at24))
        }
        if at48 > now {
            result.append((WaveReminderID.hours48, at48))
        }
        return result
    }
}

protocol WaveReminderScheduling: AnyObject {
    func requestAuthorizationIfNeeded() async -> Bool
    func scheduleWaveReminders(
        startedAt: Date,
        locale: ContentLocale,
        now: Date,
        interval24: TimeInterval,
        interval48: TimeInterval
    ) async
    func cancelWaveReminders() async
}

extension WaveReminderScheduling {
    func scheduleWaveReminders(startedAt: Date, locale: ContentLocale) async {
        await scheduleWaveReminders(
            startedAt: startedAt,
            locale: locale,
            now: Date(),
            interval24: WaveReminderTiming.hours24,
            interval48: WaveReminderTiming.hours48
        )
    }
}

@MainActor
final class WaveReminderScheduler: NSObject, WaveReminderScheduling, UNUserNotificationCenterDelegate {
    var onOpenWaveChecklist: (() -> Void)?

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    func scheduleWaveReminders(
        startedAt: Date,
        locale: ContentLocale,
        now: Date,
        interval24: TimeInterval,
        interval48: TimeInterval
    ) async {
        await cancelWaveReminders()
        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return }

        let fires = WaveReminderTiming.futureFireDates(
            startedAt: startedAt,
            now: now,
            interval24: interval24,
            interval48: interval48
        )
        for item in fires {
            let content = UNMutableNotificationContent()
            content.title = "Line 24"
            if item.id == WaveReminderID.hours24 {
                content.body = locale == .uk
                    ? "Минуло 24 години після події. Короткий чек-лист."
                    : "24 hours since the event. Short checklist."
            } else {
                content.body = locale == .uk
                    ? "Минуло 48 годин після події. Повторіть чек-лист."
                    : "48 hours since the event. Repeat the checklist."
            }
            content.sound = .default
            content.userInfo = ["open": "wave"]

            let interval = max(1, item.date.timeIntervalSince(now))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func cancelWaveReminders() async {
        center.removePendingNotificationRequests(withIdentifiers: WaveReminderID.all)
        center.removeDeliveredNotifications(withIdentifiers: WaveReminderID.all)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let open = response.notification.request.content.userInfo["open"] as? String
        guard open == "wave" else { return }
        await MainActor.run {
            onOpenWaveChecklist?()
        }
    }
}
