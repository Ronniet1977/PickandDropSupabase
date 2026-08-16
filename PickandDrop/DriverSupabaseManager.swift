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
        truckNumber: String,
        role: String
    ) async {

        let body: [String: Any] = [
            "name": name,
            "username": username,
            "truck_number": truckNumber,
            "role": role,
            "is_active": true,
            "must_change_password": true
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

            print("✅ Driver profile added")

        } catch {
            print("❌ Failed adding driver profile:", error)
        }
    }
    
    func fetchDriver(
        username: String
    ) async -> SupabaseDriver? {

        let cleanUsername =
            username
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        do {
            let data =
                try await SupabaseRESTManager.shared.request(
                    table: "pickdrop_drivers",
                    query:
                        "?select=*&username=eq.\(cleanUsername)&limit=1"
                )

            let drivers =
                try JSONDecoder()
                    .decode(
                        [SupabaseDriver].self,
                        from: data
                    )

            return drivers.first

        } catch {
            print(
                "❌ Failed loading driver profile:",
                error
            )

            return nil
        }
    }
    
    func completePasswordChange() async -> Bool {

        do {

            let body =
                try JSONSerialization.data(
                    withJSONObject: [:]
                )

            let data =
                try await SupabaseRESTManager.shared.request(
                    table: "rpc/complete_pickdrop_password_change",
                    method: "POST",
                    body: body
                )

            let updated =
                try JSONDecoder().decode(
                    Bool.self,
                    from: data
                )

            if updated {
                print("✅ must_change_password cleared")
            } else {
                print("❌ No driver matched current Auth user")
            }

            return updated

        } catch {

            print(
                "❌ Failed completing password change:",
                error
            )

            return false
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
    
    func updateDutyStatus(
        username: String,
        dutyStatus: String
    ) async {

        let body: [String: Any] = [
            "duty_status": dutyStatus
        ]

        do {

            let data = try JSONSerialization.data(
                withJSONObject: body
            )
            print("🔄 Updating \(username) -> \(dutyStatus)")

            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_drivers",
                method: "PATCH",
                query: "?username=eq.\(username)",
                body: data
            )

            print("✅ Duty status:", dutyStatus)

        } catch {

            print("❌ Duty status failed:", error)
        }
    }
}
