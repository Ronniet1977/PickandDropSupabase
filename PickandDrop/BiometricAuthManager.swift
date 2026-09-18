//
//  BiometricAuthManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 9/18/26.
//

import Foundation
import LocalAuthentication

enum BiometricAuthResult: Equatable {
    case success
    case unavailable
    case failed
}

struct BiometricAuthManager {

    static func authenticate() async -> BiometricAuthResult {

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) else {
            print(
                "⚠️ Biometrics unavailable:",
                error?.localizedDescription ?? "Unknown error"
            )

            return .unavailable
        }

        let reason =
            "Use Face ID to securely access Pick and Drop."

        do {

            let success =
                try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason
                )

            if success {
                print("✅ Biometric authentication successful")
                return .success
            }

            return .failed

        } catch {

            print(
                "❌ Biometric authentication failed:",
                error.localizedDescription
            )

            return .failed
        }
    }

    static var biometricName: String {

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) else {
            return "Biometrics"
        }

        switch context.biometryType {

        case .faceID:
            return "Face ID"

        case .touchID:
            return "Touch ID"

        case .opticID:
            return "Optic ID"

        default:
            return "Biometrics"
        }
    }

    static var isAvailable: Bool {

        let context = LAContext()
        var error: NSError?

        return context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
    }
}
