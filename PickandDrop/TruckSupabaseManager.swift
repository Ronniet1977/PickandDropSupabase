//
//  TruckSupabaseManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 9/16/26.
//

import Foundation

struct SupabaseTruck: Codable, Identifiable {
    let id: UUID
    let truck_number: String
    let is_active: Bool
    let created_at: String?
}

final class TruckSupabaseManager {

    static let shared = TruckSupabaseManager()

    private init() {}

    // MARK: - Fetch Active Trucks

    func fetchActiveTrucks() async -> [SupabaseTruck] {

        do {

            let data =
                try await SupabaseRESTManager.shared.request(
                    table: "pickdrop_trucks",
                    query:
                        "?select=*&is_active=eq.true&order=truck_number.asc"
                )

            let trucks =
                try JSONDecoder()
                    .decode(
                        [SupabaseTruck].self,
                        from: data
                    )

            print("🚚 Loaded active trucks:", trucks.count)

            return trucks

        } catch {

            print("❌ Failed loading trucks:", error)

            return []
        }
    }

    // MARK: - Fetch All Trucks

    func fetchAllTrucks() async -> [SupabaseTruck] {

        do {

            let data =
                try await SupabaseRESTManager.shared.request(
                    table: "pickdrop_trucks",
                    query:
                        "?select=*&order=truck_number.asc"
                )

            let trucks =
                try JSONDecoder()
                    .decode(
                        [SupabaseTruck].self,
                        from: data
                    )

            print("🚚 Loaded all trucks:", trucks.count)

            return trucks

        } catch {

            print("❌ Failed loading all trucks:", error)

            return []
        }
    }
    
    // MARK: - Add Truck

    func addTruck(
        truckNumber: String
    ) async -> Bool {

        let cleanNumber =
            truckNumber
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !cleanNumber.isEmpty else {
            return false
        }

        let body: [String: Any] = [
            "truck_number": cleanNumber,
            "is_active": true
        ]

        do {

            let data =
                try JSONSerialization.data(
                    withJSONObject: body
                )

            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_trucks",
                method: "POST",
                body: data
            )

            print("🚚 Truck added:", cleanNumber)

            return true

        } catch {

            print("❌ Failed adding truck:", error)

            return false
        }
    }


    // MARK: - Edit Truck

    func updateTruck(
        id: UUID,
        truckNumber: String
    ) async -> Bool {

        let cleanNumber =
            truckNumber
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !cleanNumber.isEmpty else {
            return false
        }

        let body: [String: Any] = [
            "truck_number": cleanNumber
        ]

        do {

            let data =
                try JSONSerialization.data(
                    withJSONObject: body
                )

            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_trucks",
                method: "PATCH",
                query: "?id=eq.\(id.uuidString)",
                body: data
            )

            print("🚚 Truck updated:", cleanNumber)

            return true

        } catch {

            print("❌ Failed updating truck:", error)

            return false
        }
    }


    // MARK: - Set Active

    func setTruckActive(
        id: UUID,
        isActive: Bool
    ) async -> Bool {

        let body: [String: Any] = [
            "is_active": isActive
        ]

        do {

            let data =
                try JSONSerialization.data(
                    withJSONObject: body
                )

            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_trucks",
                method: "PATCH",
                query: "?id=eq.\(id.uuidString)",
                body: data
            )

            print(
                isActive
                ? "🚚 Truck reactivated"
                : "🚚 Truck deactivated"
            )

            return true

        } catch {

            print(
                "❌ Failed changing truck status:",
                error
            )

            return false
        }
    }
}
