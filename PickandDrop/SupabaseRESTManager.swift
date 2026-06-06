//
//  SupabaseRESTManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 6/4/26.
//

import Foundation

final class SupabaseRESTManager {

    static let shared = SupabaseRESTManager()

    private init() {}

    func request(
        table: String,
        method: String = "GET",
        query: String = "",
        body: Data? = nil
    ) async throws -> Data {

        let urlString =
            "\(SupabaseConfig.projectURL)/rest/v1/\(table)\(query)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if method == "POST" || method == "PATCH" || method == "DELETE" {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {

            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Supabase error:", http.statusCode, message)
            throw URLError(.badServerResponse)
        }

        return data
    }
}

final class CompanySupabaseManager {

    static let shared = CompanySupabaseManager()

    private init() {}

    func fetchCompanySettings() async -> SupabaseCompanySettings? {

        do {
            let data = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_company_settings",
                query: "?select=*&limit=1"
            )

            let settings = try JSONDecoder()
                .decode([SupabaseCompanySettings].self, from: data)

            print("✅ Loaded company settings")

            return settings.first

        } catch {
            print("❌ Failed loading company settings:", error)
            return nil
        }
    }
}

final class LoadSupabaseManager {

    static let shared = LoadSupabaseManager()

    private init() {}

    func fetchLoads() async -> [SupabaseLoad] {

        do {

            let data = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_loads",
                query: "?select=*&order=created_at.desc"
            )

            let loads = try JSONDecoder()
                .decode([SupabaseLoad].self, from: data)

            print("✅ Loaded loads:", loads.count)

            return loads

        } catch {

            print("❌ Failed loading loads:", error)

            return []
        }
    }
    
    func addLoad(
        driverName: String,
        truckNumber: String,
        pickupTicketNumber: String,
        pickupTons: Double
    ) async {

        let body: [String: Any] = [
            "driver_name": driverName,
            "truck_number": truckNumber,
            "pickup_ticket_number": pickupTicketNumber,
            "pickup_tons": pickupTons,
            "status": "pickedUp",
            "picked_up_at": ISO8601DateFormatter().string(from: Date()),
            "is_archived": false
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: body)

            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_loads",
                method: "POST",
                body: data
            )

            print("✅ Supabase load added")

        } catch {
            print("❌ Failed adding Supabase load:", error)
        }
    }
    
    func deliverLoad(
        loadID: UUID,
        deliveryTicketNumber: String,
        deliveryTons: Double
    ) async {

        let body: [String: Any] = [
            "delivery_ticket_number": deliveryTicketNumber,
            "delivery_tons": deliveryTons,
            "status": "delivered",
            "delivered_at": ISO8601DateFormatter().string(from: Date())
        ]

        do {

            let data = try JSONSerialization.data(
                withJSONObject: body
            )

            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_loads",
                method: "PATCH",
                query: "?id=eq.\(loadID.uuidString)",
                body: data
            )

            print("✅ Supabase load delivered")

        } catch {

            print("❌ Failed delivering load:", error)
        }
    }
    
    func archiveLoad(loadID: UUID) async {

        let body: [String: Any] = [
            "is_archived": true
        ]

        do {

            let data = try JSONSerialization.data(withJSONObject: body)

            _ = try await SupabaseRESTManager.shared.request(
                table: "pickdrop_loads",
                method: "PATCH",
                query: "?id=eq.\(loadID.uuidString)",
                body: data
            )

            print("✅ Archived load")

        } catch {

            print("❌ Failed archiving load:", error)
        }
    }
}
