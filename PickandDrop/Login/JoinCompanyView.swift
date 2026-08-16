//
//  JoinCompanyView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 6/5/26.
//

import SwiftUI

struct JoinCompanyView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var joinCode = ""
    @State private var driverName = ""
    @State private var truckNumber = ""
    @State private var username = ""

    @State private var message = ""
    
    @State private var isCreatingAccount = false
    @State private var temporaryPassword = ""
    @State private var showAccountCreated = false

    var body: some View {

        NavigationStack {

            Form {

                Section("Company") {

                    TextField(
                        "Join Code",
                        text: $joinCode
                    )
                }

                Section("Driver") {

                    TextField(
                        "Driver Name",
                        text: $driverName
                    )

                    TextField(
                        "Truck Number",
                        text: $truckNumber
                    )

                    TextField(
                        "Username",
                        text: $username
                    )
                }

                if !message.isEmpty {

                    Text(message)
                        .foregroundStyle(
                            message.contains("✅") ? .green : .red
                        )
                }

                if message.contains("✅") {

                    Button("OK") {
                        dismiss()
                    }

                } else {

                    Button {
                        Task {
                            await createAccount()
                        }
                    } label: {

                        if isCreatingAccount {

                            ProgressView()

                        } else {

                            Label(
                                "Create Account",
                                systemImage: "person.badge.plus"
                            )
                        }
                    }
                    .disabled(isCreatingAccount)
                }
            }
            .navigationTitle("Join Company")
            .alert(
                "Account Created",
                isPresented: $showAccountCreated
            ) {

                Button("Copy Password") {
                    UIPasteboard.general.string =
                        temporaryPassword
                }

                Button("Done", role: .cancel) {
                    dismiss()
                }

            } message: {

                Text(
                    """
                    Username: \(username.lowercased())

                    Temporary Password:
                    \(temporaryPassword)

                    You will be required to change this password when you log in.
                    """
                )
            }
        }
    }
    
    @MainActor
    private func createAccount() async {

        guard !isCreatingAccount else {
            return
        }

        let cleanJoinCode =
            joinCode.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanName =
            driverName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanTruck =
            truckNumber.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanUsername =
            username
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        guard
            !cleanJoinCode.isEmpty,
            !cleanName.isEmpty,
            !cleanTruck.isEmpty,
            !cleanUsername.isEmpty
        else {
            message =
                "Please complete all fields."
            return
        }

        isCreatingAccount = true
        message = ""

        defer {
            isCreatingAccount = false
        }

        do {

            guard let url = URL(
                string:
                    "\(SupabaseConfig.projectURL)/functions/v1/join-company"
            ) else {
                throw JoinCompanyError.invalidURL
            }

            let body: [String: String] = [
                "joinCode": cleanJoinCode,
                "name": cleanName,
                "truckNumber": cleanTruck,
                "username": cleanUsername
            ]

            let bodyData =
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
                "Bearer \(SupabaseConfig.anonKey)",
                forHTTPHeaderField:
                    "Authorization"
            )

            request.setValue(
                "application/json",
                forHTTPHeaderField:
                    "Content-Type"
            )

            request.httpBody =
                bodyData

            let (data, response) =
                try await URLSession.shared.data(
                    for: request
                )

            guard let http =
                response as? HTTPURLResponse
            else {
                throw JoinCompanyError.invalidResponse
            }

            let result =
                try JSONDecoder().decode(
                    JoinCompanyResponse.self,
                    from: data
                )

            guard
                (200...299).contains(
                    http.statusCode
                ),
                result.success == true,
                let returnedPassword =
                    result.temporaryPassword
            else {

                throw JoinCompanyError.server(
                    result.error
                    ?? "Unable to create account."
                )
            }

            temporaryPassword =
                returnedPassword

            username =
                result.username
                ?? cleanUsername

            showAccountCreated = true

            print(
                "✅ Secure company join account created"
            )

        } catch {

            message =
                error.localizedDescription

            print(
                "❌ Join Company failed:",
                error.localizedDescription
            )
        }
    }
}

struct JoinCompanyResponse: Codable {
    let success: Bool?
    let username: String?
    let temporaryPassword: String?
    let error: String?
}

enum JoinCompanyError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Join Company URL."

        case .invalidResponse:
            return "Invalid response from server."

        case .server(let message):
            return message
        }
    }
}
