//
//  NotificationScheduler.swift
//  F1Widget
//
//  Schedules local notifications for upcoming F1 sessions so the user gets a
//  banner (including on the lock screen) shortly before each session starts.
//

import Foundation
import UserNotifications

enum NotificationScheduler {

    /// Asks for permission. Returns true if granted (or previously granted).
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// Current permission state.
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Cancel everything we previously scheduled.
    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [] // empty array means "remove ours by prefix" below
        )
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ours = requests.filter { $0.identifier.hasPrefix("f1-") }.map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ours)
        }
    }

    /// Schedule notifications for all upcoming sessions in the given weekends.
    /// Re-call this whenever the schedule or settings change — it cancels first.
    static func reschedule(weekends: [RaceWeekend],
                           leadMinutes: Int,
                           filter: SessionFilter) async {
        cancelAll()
        // Wait a moment for cancellation to apply.
        try? await Task.sleep(for: .milliseconds(50))

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let now = Date()
        let lead = TimeInterval(max(leadMinutes, 0) * 60)
        let cal = Calendar.current

        for weekend in weekends {
            for session in weekend.sessions {
                guard filter.matches(session.kind) else { continue }
                let triggerAt = session.start.addingTimeInterval(-lead)
                guard triggerAt > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "🏁 \(session.kind.rawValue) — \(weekend.name)"
                content.subtitle = "\(weekend.locality), \(weekend.country)"
                content.body = leadMinutes <= 0
                    ? "Starts now"
                    : "Starts in \(leadMinutes) minute\(leadMinutes == 1 ? "" : "s") (\(timeString(session.start)))"
                content.sound = .default

                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: triggerAt)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

                let id = "f1-\(weekend.season)-\(weekend.round)-\(session.kind.rawValue)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }

    private static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}
