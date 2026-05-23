//
//  Untitled.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/22/26.
//
import Foundation
import UIKit

struct DriverSessionFile: Codable {
    var sessions: [DriverSession]
}

struct DriverSession: Codable {
    var username: String
    var deviceName: String
    var loginTime: Date
}

struct DriverSessionManager {

    static func sessionURL() -> URL {
        StorageManager
            .truckReportsFolder()
            .appendingPathComponent("DriverSessions.json")
    }

    static func loadSessions() -> [DriverSession] {
        let url = sessionURL()

        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(DriverSessionFile.self, from: data)
        else {
            return []
        }

        return file.sessions
    }

    static func saveSessions(_ sessions: [DriverSession]) {
        let file = DriverSessionFile(sessions: sessions)

        do {
            let data = try JSONEncoder().encode(file)
            try data.write(to: sessionURL(), options: .atomic)
            print("✅ Driver sessions saved")
        } catch {
            print("❌ Failed saving sessions:", error)
        }
    }

    static func isLoggedIn(username: String) -> Bool {
        let username = username.lowercased()
        let cutoff = Date().addingTimeInterval(-12 * 60 * 60)

        return loadSessions().contains {
            $0.username.lowercased() == username &&
            $0.loginTime > cutoff
        }
    }

    static func login(username: String) {
        var sessions = loadSessions()
        let username = username.lowercased()

        sessions.removeAll {
            $0.username.lowercased() == username
        }

        sessions.append(
            DriverSession(
                username: username,
                deviceName: UIDevice.current.name,
                loginTime: Date()
            )
        )

        saveSessions(sessions)
    }

    static func logout(username: String) {
        let username = username.lowercased()

        var sessions = loadSessions()

        sessions.removeAll {
            $0.username.lowercased() == username
        }

        saveSessions(sessions)
    }
}
