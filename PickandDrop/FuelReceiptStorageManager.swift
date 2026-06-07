//
//  FuelReceiptStorageManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 6/6/26.
//

import Foundation
import UIKit

final class FuelReceiptStorageManager {

    static let shared = FuelReceiptStorageManager()

    private init() {}

    func uploadReceipt(
        image: UIImage,
        driverName: String
    ) async -> String? {

        guard let imageData = image.jpegData(compressionQuality: 0.45) else {
            return nil
        }

        let safeDriver = driverName
            .replacingOccurrences(
                of: "[^a-zA-Z0-9_-]",
                with: "_",
                options: .regularExpression
            )

        let fileName = "\(UUID().uuidString).jpg"

        let path = "\(safeDriver)/\(fileName)"

        let urlString =
            "\(SupabaseConfig.projectURL)/storage/v1/object/fuel-receipts/\(path)"

        guard let url = URL(string: urlString) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")

        do {
            let (data, response) = try await URLSession.shared.upload(
                for: request,
                from: imageData
            )

            if let text = String(data: data, encoding: .utf8) {
                print("📦 Storage response:", text)
            }

            if let http = response as? HTTPURLResponse {

                if (200...299).contains(http.statusCode) {
                    print("✅ Receipt uploaded:", path)
                    return path
                } else {
                    print("❌ Receipt upload failed:", http.statusCode)
                }
            }
            return nil

        } catch {
            print("❌ Receipt upload error:", error)
            return nil
        }
    }
    
    func fuelReceiptURL(_ path: String) -> URL? {
        URL(
            string:
            "\(SupabaseConfig.projectURL)/storage/v1/object/fuel-receipts/\(path)"
        )
    }
}
