//
//  DriverSupabaseManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 6/4/26.
//

import Foundation

final class DriverSupabaseManager {

    static let shared = DriverSupabaseManager()

    private init() {}

    func fetchDrivers() async -> [SupabaseDriver] {

        do {

            let data = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_drivers",
                query: "?select=*&order=name"
            )

            let drivers = try JSONDecoder()
                .decode([SupabaseDriver].self, from: data)

            print("✅ Loaded drivers:", drivers.count)

            return drivers

        } catch {

            print("❌ Failed loading drivers:", error)

            return []
        }
    }
    
    func addDriver(
        name: String,
        username: String,
        password: String,
        truckNumber: String,
        role: String
    ) async {

        let body: [String: Any] = [
            "name": name,
            "username": username,
            "truck_number": truckNumber,
            "role": role,
            "is_active": true,
            "password": password
        ]

        do {

            let data = try JSONSerialization.data(
                withJSONObject: body
            )

            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_drivers",
                method: "POST",
                body: data
            )

            print("✅ Driver added")

        } catch {

            print("❌ Failed adding driver:", error)
        }
    }
    
    func setDriverActive(
        id: UUID,
        isActive: Bool
    ) async {

        let body: [String: Any] = [
            "is_active": isActive
        ]

        do {
            let data = try JSONSerialization.data(
                withJSONObject: body
            )

            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_drivers?id=eq.\(id.uuidString)",
                method: "PATCH",
                body: data
            )

            print("✅ Driver updated")

        } catch {
            print("❌ Driver update failed:", error)
        }
    }
    
    func resetPassword(
        id: UUID
    ) async {

        let body: [String: Any] = [
            "password": "1234"
        ]

        do {
            let data = try JSONSerialization.data(
                withJSONObject: body
            )

            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_drivers?id=eq.\(id.uuidString)",
                method: "PATCH",
                body: data
            )

            print("✅ Password reset")

        } catch {
            print("❌ Password reset failed:", error)
        }
    }
    
    func deleteDriver(
        id: UUID
    ) async {

        do {
            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_drivers?id=eq.\(id.uuidString)",
                method: "DELETE"
            )

            print("✅ Driver deleted")

        } catch {
            print("❌ Driver delete failed:", error)
        }
    }
}
