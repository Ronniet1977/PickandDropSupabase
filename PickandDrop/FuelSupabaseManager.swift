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
        amount: Double,
        receiptPath: String? = nil
    ) async {

        var body: [String: Any] = [
            "driver_name": driverName,
            "truck_number": truckNumber,
            "amount": amount
        ]

        if let receiptPath {
            body["receipt_path"] = receiptPath
        }

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
    
    func deleteAllFuel() async {

        do {
            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_fuel",
                method: "DELETE",
                query: "?id=not.is.null"
            )

            print("🧹 Supabase fuel cleared")

        } catch {
            print("❌ Failed clearing fuel:", error)
        }
    }
    
    func markReceiptSaved(
        fuelID: UUID
    ) async {

        let body: [String: Any] = [
            "receipt_saved_by_admin": true,
            "receipt_saved_at": ISO8601DateFormatter().string(from: Date()),
            "receipt_path": NSNull()
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: body)

            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_fuel",
                method: "PATCH",
                query: "?id=eq.\(fuelID.uuidString)",
                body: data
            )

            print("✅ Fuel receipt marked saved")

        } catch {
            print("❌ Failed marking receipt saved:", error)
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



