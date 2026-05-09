//
//  ChangePasswordView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/8/26.
//

import SwiftUI
import SwiftData

struct ChangePasswordView: View {

    let driver: DriverProfile

    @Environment(\.modelContext) private var context

    @AppStorage("mustChangePassword")
    var mustChangePassword = true

    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var errorText = ""

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.11, blue: 0.18),
                    Color(red: 0.15, green: 0.22, blue: 0.35),
                    Color.black.opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {

                Spacer()

                Text("Change Password")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                VStack(spacing: 16) {

                    SecureField(
                        "New Password",
                        text: $newPassword
                    )
                    .textFieldStyle(.roundedBorder)

                    SecureField(
                        "Confirm Password",
                        text: $confirmPassword
                    )
                    .textFieldStyle(.roundedBorder)

                    if !errorText.isEmpty {

                        Text(errorText)
                            .foregroundStyle(.red)
                    }

                    Button("Save Password") {

                        savePassword()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .padding()

                Spacer()
            }
        }
    }

    func savePassword() {

        guard !newPassword.isEmpty else {

            errorText = "Password required"
            return
        }

        guard newPassword == confirmPassword else {

            errorText = "Passwords do not match"
            return
        }

        driver.password = newPassword
        driver.mustChangePassword = false

        do {

            try context.save()

            mustChangePassword = false

            print("✅ Password changed")

        } catch {

            errorText = "Failed saving password"
        }
    }
}
