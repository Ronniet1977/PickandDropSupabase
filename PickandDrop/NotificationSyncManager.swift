//
//  NotificationSyncManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/23/26.
//

import Foundation
import Combine

struct AppNotification: Identifiable, Codable, Hashable {

    var id: UUID = UUID()
    var type: String
    var driverName: String
    var truckNumber: String
    var message: String
    var loadTicket: String?
    var createdAt: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case driverName = "driver_name"
        case truckNumber = "truck_number"
        case message
        case loadTicket = "load_ticket"
        case createdAt = "created_at"
    }
}

@MainActor
final class NotificationSyncManager: ObservableObject {

    @Published var notifications: [AppNotification] = []

    func sendNotification(_ notification: AppNotification) {

        Task {
            do {
                let body = try JSONEncoder().encode(notification)

                _ = try await SupabaseRESTManager.shared.request(
                    table: "pickdrop_notifications",
                    method: "POST",
                    body: body
                )

                print("✅ Supabase notification sent")

            } catch {
                print("❌ Supabase notification failed:", error)
            }
        }
    }

    func loadNotifications() {

        Task {
            do {
                let data = try await SupabaseRESTManager.shared.request(
                    table: "pickdrop_notifications",
                    query: "?select=*&order=created_at.desc"
                )

                let loaded = try JSONDecoder()
                    .decode([AppNotification].self, from: data)

                notifications = loaded

                print("🔔 Supabase notifications loaded:", notifications.count)

            } catch {
                print("❌ Failed loading Supabase notifications:", error)
            }
        }
    }

    func deleteNotification(_ notification: AppNotification) {

        Task {
            do {
                _ = try await SupabaseRESTManager.shared.request(
                    table: "pickdrop_notifications",
                    method: "DELETE",
                    query: "?id=eq.\(notification.id.uuidString)"
                )

                notifications.removeAll { $0.id == notification.id }

                print("🗑 Supabase notification deleted")

            } catch {
                print("❌ Failed deleting Supabase notification:", error)
            }
        }
    }

    func deleteAllNotifications() {

        Task {
            do {
                _ = try await SupabaseRESTManager.shared.request(
                    table: "pickdrop_notifications",
                    method: "DELETE",
                    query: "?id=not.is.null"
                )

                notifications.removeAll()

                print("🧹 Supabase notifications cleared")

            } catch {
                print("❌ Failed clearing Supabase notifications:", error)
            }
        }
    }
}
