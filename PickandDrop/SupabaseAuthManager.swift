//
//  SupabaseAuthManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 8/16/26.
//

import Foundation

struct SupabaseAuthUser: Codable {
    let id: UUID
    let email: String?
}

struct SupabaseAuthSession: Codable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int?
    let token_type: String?
    let user: SupabaseAuthUser
}

struct SupabaseAuthErrorResponse: Codable {
    let error: String?
    let error_description: String?
    let msg: String?
}

enum SupabaseAuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Supabase Auth URL."

        case .invalidResponse:
            return "Invalid response from Supabase Auth."

        case .server(let message):
            return message
        }
    }
}

final class SupabaseAuthManager {

    static let shared = SupabaseAuthManager()

    private init() {}

    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var currentUserID: UUID?

    // MARK: - Sign In

    func signIn(
        email: String,
        password: String
    ) async throws -> SupabaseAuthSession {

        guard let url = URL(
            string:
                "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=password"
        ) else {
            throw SupabaseAuthError.invalidURL
        }

        let body: [String: Any] = [
            "email": email,
            "password": password
        ]

        let data = try JSONSerialization.data(
            withJSONObject: body
        )

        var request = URLRequest(url: url)

        request.httpMethod = "POST"

        request.setValue(
            SupabaseConfig.anonKey,
            forHTTPHeaderField: "apikey"
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
            throw SupabaseAuthError.invalidResponse
        }

        guard (200...299).contains(
            http.statusCode
        ) else {

            throw authError(
                from: responseData,
                fallback:
                    "Unable to sign in."
            )
        }

        let session =
            try JSONDecoder().decode(
                SupabaseAuthSession.self,
                from: responseData
            )

        accessToken =
            session.access_token

        refreshToken =
            session.refresh_token
        
        AuthKeychain.saveRefreshToken(
            session.refresh_token
        )

        currentUserID =
            session.user.id

        print("✅ Supabase Auth login successful")

        return session
    }

    // MARK: - Sign Up

    func signUp(
        email: String,
        password: String
    ) async throws {

        guard let url = URL(
            string:
                "\(SupabaseConfig.projectURL)/auth/v1/signup"
        ) else {
            throw SupabaseAuthError.invalidURL
        }

        let body: [String: Any] = [
            "email": email,
            "password": password
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
            throw SupabaseAuthError.invalidResponse
        }

        guard (200...299).contains(
            http.statusCode
        ) else {

            throw authError(
                from: responseData,
                fallback:
                    "Unable to create account."
            )
        }

        print("✅ Supabase Auth account created")
    }

    // MARK: - Change Password

    func updatePassword(
        newPassword: String
    ) async throws {

        guard
            let token = accessToken
        else {
            throw SupabaseAuthError.server(
                "No authenticated user."
            )
        }

        guard let url = URL(
            string:
                "\(SupabaseConfig.projectURL)/auth/v1/user"
        ) else {
            throw SupabaseAuthError.invalidURL
        }

        let body: [String: Any] = [
            "password": newPassword
        ]

        let data =
            try JSONSerialization.data(
                withJSONObject: body
            )

        var request =
            URLRequest(url: url)

        request.httpMethod = "PUT"

        request.setValue(
            SupabaseConfig.anonKey,
            forHTTPHeaderField: "apikey"
        )

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField:
                "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Content-Type"
        )

        request.httpBody = data

        let (responseData, response) =
            try await URLSession.shared.data(
                for: request
            )

        guard let http =
            response as? HTTPURLResponse
        else {
            throw SupabaseAuthError.invalidResponse
        }

        guard (200...299).contains(
            http.statusCode
        ) else {

            throw authError(
                from: responseData,
                fallback:
                    "Unable to update password."
            )
        }

        print("✅ Supabase Auth password updated")
    }
    
    // MARK: - Restore Session

    func restoreSession() async -> Bool {

        guard let storedRefreshToken =
            AuthKeychain.loadRefreshToken()
        else {
            print("ℹ️ No saved Auth session")
            return false
        }

        guard let url = URL(
            string:
                "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=refresh_token"
        ) else {
            print("❌ Invalid refresh URL")
            return false
        }

        let body: [String: Any] = [
            "refresh_token": storedRefreshToken
        ]

        do {

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
                throw SupabaseAuthError.invalidResponse
            }

            guard (200...299).contains(
                http.statusCode
            ) else {

                let error =
                    authError(
                        from: responseData,
                        fallback:
                            "Unable to restore session."
                    )

                print(
                    "❌ Auth session restore failed:",
                    error.localizedDescription
                )

                AuthKeychain.deleteRefreshToken()

                accessToken = nil
                refreshToken = nil
                currentUserID = nil

                return false
            }

            let session =
                try JSONDecoder().decode(
                    SupabaseAuthSession.self,
                    from: responseData
                )

            accessToken =
                session.access_token

            refreshToken =
                session.refresh_token

            currentUserID =
                session.user.id

            // Refresh token rotation means
            // we must save the NEW token.
            AuthKeychain.saveRefreshToken(
                session.refresh_token
            )

            print("✅ Supabase Auth session restored")
            print(
                "👤 Auth User ID:",
                session.user.id
            )

            return true

        } catch {

            print(
                "❌ Auth restore error:",
                error.localizedDescription
            )

            return false
        }
    }

    // MARK: - Sign Out

    func clearSession() {

        accessToken = nil
        refreshToken = nil
        currentUserID = nil

        AuthKeychain.deleteRefreshToken()

        print("✅ Local Auth session cleared")
    }

    // MARK: - Error Handling

    private func authError(
        from data: Data,
        fallback: String
    ) -> SupabaseAuthError {

        if let decoded =
            try? JSONDecoder().decode(
                SupabaseAuthErrorResponse.self,
                from: data
            ) {

            let message =
                decoded.msg ??
                decoded.error_description ??
                decoded.error ??
                fallback

            return .server(message)
        }

        return .server(fallback)
    }
}
