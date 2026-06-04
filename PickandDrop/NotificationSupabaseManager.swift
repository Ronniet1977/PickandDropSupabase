//
//  NotificationSupabaseManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 6/4/26.
//

import Foundation

final class NotificationSupabaseManager {

    static let shared = NotificationSupabaseManager()

    private init() {}

    func sendNotification(
        type: String,
        driverName: String,
        truckNumber: String,
        message: String,
        loadTicket: String? = nil
    ) async {

        let notification = PickDropNotification(
            id: nil,
            type: type,
            driver_name: driverName,
            truck_number: truckNumber,
            message: message,
            load_ticket: loadTicket,
            created_at: nil
        )

        do {

            let body = try JSONEncoder().encode(notification)

            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_notifications",
                method: "POST",
                body: body
            )

            print("✅ Notification sent")

        } catch {

            print("❌ Failed:", error)
        }
    }
    
    func fetchNotifications() async -> [PickDropNotification] {

        do {

            let data = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_notifications",
                query: "?select=*&order=created_at.desc"
            )

            let notifications =
                try JSONDecoder()
                    .decode(
                        [PickDropNotification].self,
                        from: data
                    )

            print("✅ Loaded notifications:", notifications.count)

            return notifications

        } catch {

            print("❌ Failed loading notifications:", error)

            return []
        }
    }
}
