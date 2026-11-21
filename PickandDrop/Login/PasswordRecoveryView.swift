//
//  PasswordRecoveryView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 11/21/26.
//

import SwiftUI

struct PasswordRecoveryView: View {

    @Environment(\.dismiss)
    private var dismiss

    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var errorText = ""
    @State private var isSaving = false

    var body: some View {

        NavigationStack {

            Form {

                Section(
                    "Choose New Password"
                ) {

                    SecureField(
                        "New Password",
                        text: $newPassword
                    )

                    SecureField(
                        "Confirm Password",
                        text: $confirmPassword
                    )
                }

                if !errorText.isEmpty {

                    Section {

                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                }

                Section {

                    Button {

                        Task {
                            await savePassword()
                        }

                    } label: {

                        if isSaving {

                            ProgressView()

                        } else {

                            Text(
                                "Save New Password"
                            )
                            .frame(
                                maxWidth:
                                    .infinity
                            )
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle(
                "Reset Password"
            )
        }
    }

    private func savePassword() async {

        guard
            newPassword.count >= 6
        else {

            errorText =
                "Password must be at least 6 characters."

            return
        }

        guard
            newPassword ==
                confirmPassword
        else {

            errorText =
                "Passwords do not match."

            return
        }

        isSaving = true
        errorText = ""

        do {

            try await
                SupabaseAuthManager.shared
                    .updatePassword(
                        newPassword:
                            newPassword
                    )

            await MainActor.run {

                isSaving = false

                SupabaseAuthManager.shared
                    .clearSession()

                dismiss()
            }

        } catch {

            await MainActor.run {

                isSaving = false

                errorText =
                    error.localizedDescription
            }
        }
    }
}
