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

enum AuthRestoreResult {
    case restored
    case noSession
    case invalidSession
    case temporaryFailure
}

final class AppUpdateManager {
    
    static let shared = AppUpdateManager()
    
    private init() {}
    
    func updateConfig(
        forceUpdate: Bool,
        minimumBuild: Int,
        latestBuild: Int,
        appStoreURL: String
    ) async -> Bool {
        
        let body: [String: Any] = [
            "force_update": forceUpdate,
            "minimum_build": minimumBuild,
            "latest_build": latestBuild,
            "app_store_url": appStoreURL
        ]
        
        do {
            
            let data =
            try JSONSerialization.data(
                withJSONObject: body
            )
            
            _ =
            try await SupabaseRESTManager.shared.request(
                table: "pickdrop_app_config",
                method: "PATCH",
                query: "?id=eq.1",
                body: data
            )
            
            print("✅ App update config saved")
            
            return true
            
        } catch {
            
            print(
                "❌ Failed saving app update config:",
                error
            )
            
            return false
        }
    }
    
    func fetchConfig() async -> SupabaseAppConfig? {
        
        do {
            
            let data =
            try await SupabaseRESTManager.shared.request(
                table: "pickdrop_app_config",
                query: "?select=*&id=eq.1&limit=1"
            )
            
            return try JSONDecoder()
                .decode(
                    [SupabaseAppConfig].self,
                    from: data
                )
                .first
            
        } catch {
            
            print(
                "❌ Failed loading app update config:",
                error
            )
            
            return nil
        }
    }
}

final class SupabaseAuthManager {

    static let shared = SupabaseAuthManager()

    private init() {}

    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var currentUserID: UUID?
    
    @MainActor
    private var restoreTask:
    Task<AuthRestoreResult, Never>?

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
    
    @MainActor
    func restoreSession() async -> AuthRestoreResult {
        
        // If a refresh is already running,
        // everybody waits for that SAME refresh
        // instead of using the refresh token twice.
        if let existingTask = restoreTask {
            
            print(
                "🔄 Auth restore already running — waiting for existing request"
            )
            
            return await existingTask.value
        }
        
        let task =
        Task<AuthRestoreResult, Never> {
            
            await self.performRestoreSession()
        }
        
        restoreTask = task
        
        let result =
        await task.value
        
        restoreTask = nil
        
        return result
    }

    private func performRestoreSession() async -> AuthRestoreResult {
        
        guard let storedRefreshToken =
                AuthKeychain.loadRefreshToken()
        else {
            
            print(
                "ℹ️ No saved Auth session"
            )
            
            return .noSession
        }
        
        guard let url = URL(
            string:
                "\(SupabaseConfig.projectURL)/auth/v1/token?grant_type=refresh_token"
        ) else {
            
            print(
                "❌ Invalid refresh URL"
            )
            
            return .temporaryFailure
        }
        
        let body: [String: Any] = [
            "refresh_token":
                storedRefreshToken
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
                forHTTPHeaderField:
                    "Content-Type"
            )
            
            request.setValue(
                "application/json",
                forHTTPHeaderField:
                    "Accept"
            )
            
            request.httpBody = data
            
            let (
                responseData,
                response
            ) =
            try await URLSession.shared.data(
                for: request
            )
            
            guard let http =
                    response as? HTTPURLResponse
            else {
                
                print(
                    "⚠️ Auth restore received invalid response"
                )
                
                return .temporaryFailure
            }
            
            // MARK: Successful refresh
            
            if (200...299).contains(
                http.statusCode
            ) {
                
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
                
                // Save rotated refresh token.
                AuthKeychain.saveRefreshToken(
                    session.refresh_token
                )
                
                print(
                    "✅ Supabase Auth session restored"
                )
                
                print(
                    "👤 Auth User ID:",
                    session.user.id
                )
                
                return .restored
            }
            
            let error =
            authError(
                from: responseData,
                fallback:
                    "Unable to restore session."
            )
            
            // MARK: Truly invalid session
            
            if http.statusCode == 400 ||
                http.statusCode == 401 {
                
                print(
                    "❌ Auth session is invalid:",
                    error.localizedDescription
                )
                
                accessToken = nil
                refreshToken = nil
                currentUserID = nil
                
                AuthKeychain.deleteRefreshToken()
                
                return .invalidSession
            }
            
            // MARK: Server/rate-limit/etc.
            // Do NOT destroy the saved session.
            
            print(
                "⚠️ Temporary Auth restore failure:",
                http.statusCode,
                error.localizedDescription
            )
            
            return .temporaryFailure
            
        } catch {
            
            // Network loss, timeout, DNS, etc.
            // Do NOT delete Jesse's refresh token.
            
            print(
                "⚠️ Temporary Auth restore error:",
                error.localizedDescription
            )
            
            return .temporaryFailure
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
