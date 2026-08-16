//
//  AdminDriverAuthManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 8/16/26.
//

import Foundation

struct AdminDriverAuthResponse: Codable {
    let success: Bool?
    let authUserID: UUID?
    let username: String?
    let email: String?
    let error: String?
}

enum AdminDriverAuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Edge Function URL."

        case .invalidResponse:
            return "Invalid response from Supabase."

        case .server(let message):
            return message
        }
    }
}

final class AdminDriverAuthManager {

    static let shared = AdminDriverAuthManager()

    private init() {}
    
    func createAccount(
        name: String,
        username: String,
        truckNumber: String,
        role: String,
        temporaryPassword: String
    ) async throws {

        guard let token =
            SupabaseAuthManager.shared.accessToken
        else {
            throw AdminDriverAuthError.server(
                "Admin is not authenticated."
            )
        }

        guard let url = URL(
            string:
                "\(SupabaseConfig.projectURL)/functions/v1/admin-driver-account"
        ) else {
            throw AdminDriverAuthError.invalidURL
        }

        let cleanUsername =
            username
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        let body: [String: Any] = [
            "action": "create",
            "name":
                name.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            "username": cleanUsername,
            "truckNumber":
                truckNumber.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            "role": role,
            "temporaryPassword":
                temporaryPassword
        ]

        let data =
            try JSONSerialization.data(
                withJSONObject: body
            )

        var request =
            URLRequest(url: url)

        request.httpMethod = "POST"

        request.setValue(
            SupabaseConfig.anonKey,
            forHTTPHeaderField: "apikey"
        )

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        request.httpBody = data

        let (responseData, response) =
            try await URLSession.shared.data(
                for: request
            )

        guard let http =
            response as? HTTPURLResponse
        else {
            throw AdminDriverAuthError.invalidResponse
        }

        let decoded =
            try? JSONDecoder().decode(
                AdminDriverAuthResponse.self,
                from: responseData
            )

        guard (200...299).contains(
            http.statusCode
        ) else {
            throw AdminDriverAuthError.server(
                decoded?.error
                ?? "Unable to create driver account."
            )
        }

        print("✅ Secure driver account created")
    }
    
    func deleteAccount(
        username: String
    ) async throws {

        guard let token =
            SupabaseAuthManager.shared.accessToken
        else {
            throw AdminDriverAuthError.server(
                "Admin is not authenticated."
            )
        }

        guard let url = URL(
            string:
                "\(SupabaseConfig.projectURL)/functions/v1/admin-driver-account"
        ) else {
            throw AdminDriverAuthError.invalidURL
        }

        let cleanUsername =
            username
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        let body: [String: Any] = [
            "action": "delete",
            "username": cleanUsername
        ]

        let data =
            try JSONSerialization.data(
                withJSONObject: body
            )

        var request =
            URLRequest(url: url)

        request.httpMethod = "POST"

        request.setValue(
            SupabaseConfig.anonKey,
            forHTTPHeaderField: "apikey"
        )

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.httpBody = data

        let (responseData, response) =
            try await URLSession.shared.data(
                for: request
            )

        guard let http =
            response as? HTTPURLResponse
        else {
            throw AdminDriverAuthError.invalidResponse
        }

        let decoded =
            try? JSONDecoder().decode(
                AdminDriverAuthResponse.self,
                from: responseData
            )

        guard (200...299).contains(
            http.statusCode
        ) else {
            throw AdminDriverAuthError.server(
                decoded?.error
                ?? "Unable to delete driver."
            )
        }

        print("✅ Secure driver account deleted")
    }

    func resetPassword(
        username: String,
        temporaryPassword: String
    ) async throws {

        guard let token =
            SupabaseAuthManager.shared.accessToken
        else {
            throw AdminDriverAuthError.server(
                "Admin is not authenticated."
            )
        }

        guard let url = URL(
            string:
                "\(SupabaseConfig.projectURL)/functions/v1/admin-driver-account"
        ) else {
            throw AdminDriverAuthError.invalidURL
        }

        let body: [String: Any] = [
            "action": "reset",
            "username":
                username
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .lowercased(),
            "temporaryPassword": temporaryPassword
        ]

        let data =
            try JSONSerialization.data(
                withJSONObject: body
            )

        var request =
            URLRequest(url: url)

        request.httpMethod = "POST"

        request.setValue(
            SupabaseConfig.anonKey,
            forHTTPHeaderField: "apikey"
        )

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        request.httpBody = data

        let (responseData, response) =
            try await URLSession.shared.data(
                for: request
            )

        guard let http =
            response as? HTTPURLResponse
        else {
            throw AdminDriverAuthError.invalidResponse
        }

        let decoded =
            try? JSONDecoder().decode(
                AdminDriverAuthResponse.self,
                from: responseData
            )

        guard (200...299).contains(
            http.statusCode
        ) else {

            throw AdminDriverAuthError.server(
                decoded?.error
                ?? "Unable to reset password."
            )
        }

        print("✅ Secure driver password reset")
    }
}
