//
//  NotificationScheduler.swift
//  SimpleRecurringTaskManager
//
//  Schedules the due-time alert plus a handful of staggered follow-up
//  notifications, so a backgrounded app keeps pestering the user instead of
//  alerting once and going quiet — see the PRD's "aggressively notifies" core
//  differentiator. No critical-alerts entitlement is used (regular notifications
//  already respect Do Not Disturb by design, which is what the PRD asks for), but
//  `.timeSensitive` still lets them punch through most Focus filters.
//

import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()
    private init() {}

    static let categoryID = "TASK_DUE"
    static let snoozeActionID = "SNOOZE"

    // How many extra nags to fire after the initial alert, and how far apart, if
    // the task is still undealt-with.
    private static let followUpCount = 5
    private static let followUpIntervalMinutes = 5
    private static let deadlineSuffix = "-deadline"

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func registerCategories() {
        let snooze = UNNotificationAction(identifier: Self.snoozeActionID, title: "Snooze", options: [])
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [snooze],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Cancels any previously scheduled notifications for this task, then — if
    /// `fireDate` is a future date — schedules the alert and its follow-ups. The
    /// caller decides which of the task's several timers (next_due, snooze_until,
    /// a defer target) `fireDate` should be; passing nil (or a past date) just
    /// leaves the task silent, which is correct after e.g. marking it Done.
    func reschedule(for task: TaskItem, fireDate: Date?, alarmSound: AlarmSound) {
        cancel(taskID: task.id)
        guard let fireDate, fireDate > Date() else { return }

        schedule(taskID: task.id, title: task.title, body: "This task is due.", fireDate: fireDate, sound: alarmSound, suffix: "")
        for index in 1...Self.followUpCount {
            let followUpDate = fireDate.addingTimeInterval(TimeInterval(index * Self.followUpIntervalMinutes * 60))
            schedule(taskID: task.id, title: task.title, body: "This task is due.", fireDate: followUpDate, sound: alarmSound, suffix: "-followup-\(index)")
        }
    }

    /// The "Are you done?" / "Did you check it?" prompt fired when an "I'll Do It
    /// Now" / "I'll Check It Now" countdown expires.
    func scheduleDeadlinePrompt(taskID: UUID, title: String, body: String, fireDate: Date, alarmSound: AlarmSound) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [taskID.uuidString + Self.deadlineSuffix])
        guard fireDate > Date() else { return }
        schedule(taskID: taskID, title: title, body: body, fireDate: fireDate, sound: alarmSound, suffix: Self.deadlineSuffix)
    }

    private func schedule(taskID: UUID, title: String, body: String, fireDate: Date, sound: AlarmSound, suffix: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound.notificationSound
        content.categoryIdentifier = Self.categoryID
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["taskID": taskID.uuidString]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: taskID.uuidString + suffix, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancel(taskID: UUID) {
        var identifiers = [taskID.uuidString, taskID.uuidString + Self.deadlineSuffix]
        identifiers.append(contentsOf: (1...Self.followUpCount).map { taskID.uuidString + "-followup-\($0)" })
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
