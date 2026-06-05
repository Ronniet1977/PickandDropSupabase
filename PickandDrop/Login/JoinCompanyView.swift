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

                    Button("Create Account") {
                        Task {
                            await createAccount()
                        }
                    }
                }
            }
            .navigationTitle("Join Company")
        }
    }
    
    func createAccount() async {

        guard let company =
            await CompanySupabaseManager
                .shared
                .fetchCompanySettings()
        else {

            await MainActor.run {
                message = "Company not found"
            }

            return
        }

        guard joinCode.uppercased() ==
              company.company_join_code.uppercased()
        else {

            await MainActor.run {
                message = "Invalid company code"
            }

            return
        }

        await DriverSupabaseManager.shared.addDriver(
            name: driverName,
            username: username.lowercased(),
            password: "1234",
            truckNumber: truckNumber,
            role: "driver"
        )

        await MainActor.run {
            message = "✅ Account created.\nTemporary password: 1234"
        }
    }
}
