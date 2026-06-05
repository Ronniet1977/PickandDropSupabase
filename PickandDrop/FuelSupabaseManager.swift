//
//  FuelSupabaseManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 6/5/26.
//

import Foundation

final class FuelSupabaseManager {

    static let shared = FuelSupabaseManager()

    private init() {}

    func addFuel(
        driverName: String,
        truckNumber: String,
        amount: Double
    ) async {

        let body: [String: Any] = [
            "driver_name": driverName,
            "truck_number": truckNumber,
            "amount": amount
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: body)

            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_fuel",
                method: "POST",
                body: data
            )

            print("✅ Supabase fuel added")

        } catch {
            print("❌ Supabase fuel add failed:", error)
        }
    }

    func fetchFuel() async -> [SupabaseFuel] {

        do {
            let data = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_fuel",
                query: "?select=*&order=created_at.desc"
            )

            let fuel = try JSONDecoder()
                .decode([SupabaseFuel].self, from: data)

            print("✅ Loaded fuel:", fuel.count)

            return fuel

        } catch {
            print("❌ Failed loading fuel:", error)
            return []
        }
    }
}



