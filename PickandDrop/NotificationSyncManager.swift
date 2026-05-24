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
    var createdAt: Date = Date()
}

@MainActor
final class NotificationSyncManager: ObservableObject {
    @Published var notifications: [AppNotification] = []

    private let folderName = "AdminNotifications"

    private var baseURL: URL {
        StorageManager.truckReportsFolder()
            .appendingPathComponent("AdminNotifications")
    }

    func setupFolder() {
        let folder = baseURL

        do {
            try FileManager.default.createDirectory(
                at: baseURL,
                withIntermediateDirectories: true
            )
        } catch {
            print("❌ Failed creating notification folder:", error)
        }
    }

    func sendNotification(_ notification: AppNotification) {
        setupFolder()

        let folder = baseURL
        
        print("📁 Notification folder:", folder.path)

        let fileURL = folder.appendingPathComponent("\(notification.id.uuidString).json")

        do {
            let data = try JSONEncoder.prettyDate.encode(notification)
            try data.write(to: fileURL, options: [.atomic])
            print("✅ Notification saved:", fileURL.lastPathComponent)
        } catch {
            print("❌ Failed saving notification:", error)
        }
    }

    func loadNotifications() {
        setupFolder()

        let folder = baseURL

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )

            let loaded: [AppNotification] = files.compactMap { url in
                guard url.pathExtension == "json" else { return nil }

                do {
                    let data = try Data(contentsOf: url)
                    return try JSONDecoder.prettyDate.decode(AppNotification.self, from: data)
                } catch {
                    print("⚠️ Bad notification file:", url.lastPathComponent)
                    return nil
                }
            }

            notifications = loaded.sorted {
                $0.createdAt > $1.createdAt
            }
            print("🔔 Loaded notifications:", notifications.count)

        } catch {
            print("❌ Failed loading notifications:", error)
        }
    }
    
    

    func deleteNotification(_ notification: AppNotification) {
        let folder = baseURL

        let fileURL = folder.appendingPathComponent("\(notification.id.uuidString).json")

        do {
            try FileManager.default.removeItem(at: fileURL)
            notifications.removeAll { $0.id == notification.id }
            print("🗑 Deleted notification")
        } catch {
            print("❌ Failed deleting notification:", error)
        }
    }

    func deleteAllNotifications() {
        let folder = baseURL

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )

            for file in files where file.pathExtension == "json" {
                try? FileManager.default.removeItem(at: file)
            }

            notifications.removeAll()
            print("🧹 Cleared all notifications")

        } catch {
            print("❌ Failed clearing notifications:", error)
        }
    }
}

extension JSONEncoder {
    static var prettyDate: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var prettyDate: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
