//
//  AuthKeychain.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 8/16/26.
//

import Foundation
import Security

enum AuthKeychain {

    private static let service =
        "com.pickanddrop.auth"

    private static let refreshTokenAccount =
        "supabase.refreshToken"

    static func saveRefreshToken(
        _ token: String
    ) {
        
        guard let data =
                token.data(using: .utf8)
        else {
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,
            
            kSecAttrService as String:
                service,
            
            kSecAttrAccount as String:
                refreshTokenAccount
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String:
                data,
            
            kSecAttrAccessible as String:
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let updateStatus =
        SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )
        
        if updateStatus == errSecSuccess {
            
            print(
                "🔐 Auth refresh token updated"
            )
            
            return
        }
        
        if updateStatus != errSecItemNotFound {
            
            print(
                "❌ Keychain update failed:",
                updateStatus
            )
            
            return
        }
        
        var newItem = query
        
        newItem[
            kSecValueData as String
        ] = data
        
        newItem[
            kSecAttrAccessible as String
        ] =
        kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        
        let addStatus =
        SecItemAdd(
            newItem as CFDictionary,
            nil
        )
        
        if addStatus == errSecSuccess {
            
            print(
                "🔐 Auth refresh token saved"
            )
            
        } else {
            
            print(
                "❌ Keychain save failed:",
                addStatus
            )
        }
    }

    static func loadRefreshToken() -> String? {

        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                refreshTokenAccount,

            kSecReturnData as String:
                true,

            kSecMatchLimit as String:
                kSecMatchLimitOne
        ]

        var result: CFTypeRef?

        let status =
            SecItemCopyMatching(
                query as CFDictionary,
                &result
            )

        guard
            status == errSecSuccess,
            let data = result as? Data,
            let token =
                String(
                    data: data,
                    encoding: .utf8
                )
        else {
            return nil
        }

        return token
    }

    static func deleteRefreshToken() {

        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                service,

            kSecAttrAccount as String:
                refreshTokenAccount
        ]

        SecItemDelete(
            query as CFDictionary
        )

        print("🔐 Auth refresh token removed")
    }
}
