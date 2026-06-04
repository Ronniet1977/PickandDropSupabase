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
