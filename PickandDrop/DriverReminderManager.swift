import Foundation
import UserNotifications

final class DriverReminderManager {
    
    static let shared = DriverReminderManager()
    
    private init() {}
    
    // MARK: - Request Permission
    
    func requestPermission() async -> Bool {
        
        do {
            
            let granted =
            try await UNUserNotificationCenter.current()
                .requestAuthorization(
                    options: [
                        .alert,
                        .sound,
                        .badge
                    ]
                )
            
            print(
                granted
                ? "🔔 Notification permission granted"
                : "🔕 Notification permission denied"
            )
            
            return granted
            
        } catch {
            
            print(
                "❌ Notification permission error:",
                error
            )
            
            return false
        }
    }
    
    // MARK: - Schedule Driver Reminders
    
    func scheduleDriverReminders() async {
        
        let center =
        UNUserNotificationCenter.current()
        
        // Remove our old versions before rescheduling.
        center.removePendingNotificationRequests(
            withIdentifiers: [
                "driver-morning-reminder",
                "driver-finish-day-reminder"
            ]
        )
        
        // MARK: 6:30 AM
        
        let morningContent =
        UNMutableNotificationContent()
        
        morningContent.title = "Pick & Drop"
        morningContent.body =
        "Remember to check Pick & Drop for today's work."
        morningContent.sound = .default
        
        var morningTime =
        DateComponents()
        
        morningTime.hour = 6
        morningTime.minute = 30
        
        let morningTrigger =
        UNCalendarNotificationTrigger(
            dateMatching: morningTime,
            repeats: true
        )
        
        let morningRequest =
        UNNotificationRequest(
            identifier:
                "driver-morning-reminder",
            content: morningContent,
            trigger: morningTrigger
        )
        
        do {
            
            try await center.add(morningRequest)
            
            print("🔔 Morning reminder scheduled: 6:30 AM")
            
        } catch {
            
            print(
                "❌ Failed scheduling driver reminders:",
                error
            )
        }
    }
    
    // MARK: - Schedule Finish Day Reminder
    
    func scheduleFinishDayReminder() async {
        
        let center =
        UNUserNotificationCenter.current()
        
        // Remove any existing one first.
        center.removePendingNotificationRequests(
            withIdentifiers: [
                "driver-finish-day-reminder"
            ]
        )
        
        let content =
        UNMutableNotificationContent()
        
        content.title = "Pick & Drop"
        content.body =
        "You're still working. Remember to Finish Day when you're done."
        content.sound = .default
        
        var components =
        Calendar.current.dateComponents(
            [.year, .month, .day],
            from: Date()
        )
        
        components.hour = 16
        components.minute = 0
        
        guard let reminderDate =
                Calendar.current.date(from: components)
        else {
            return
        }
        
        // Don't schedule today's 4 PM reminder
        // if 4 PM has already passed.
        guard reminderDate > Date() else {
            print("🔔 4 PM has already passed — no reminder scheduled")
            return
        }
        
        let trigger =
        UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
        
        let request =
        UNNotificationRequest(
            identifier:
                "driver-finish-day-reminder",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("🔔 Finish Day reminder scheduled for 4:00 PM")
        } catch {
            print(
                "❌ Failed scheduling Finish Day reminder:",
                error
            )
        }
    }
    
    
    // MARK: - Cancel Finish Day Reminder
    
    func cancelFinishDayReminder() {
        
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers: [
                    "driver-finish-day-reminder"
                ]
            )
        
        print("🔕 Finish Day reminder cancelled")
    }
}

