//
//  FuelReceiptManager.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 6/6/26.
//
import Foundation
import UIKit
import Photos

final class FuelReceiptManager {

    static let shared = FuelReceiptManager()

    private init() {}

    func saveAllReceiptsToPhotos(
        fuelEntries: [SupabaseFuel]
    ) async {

        for entry in fuelEntries {

            guard let path = entry.receipt_path else { continue }

            let urlString =
                "\(SupabaseConfig.projectURL)/storage/v1/object/public/fuel-receipts/\(path)"

            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)

                guard let image = UIImage(data: data) else { continue }

                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }

                let deleted =
                    await deleteReceiptFromSupabase(path: path)

                if deleted {
                    await FuelSupabaseManager.shared.markReceiptSaved(
                        fuelID: entry.id
                    )

                    print("✅ Saved and deleted:", path)
                } else {
                    print("✅ Saved to Photos, delete failed:", path)
                }

            } catch {
                print("❌ Failed receipt:", path, error)
            }
        }
    }

    func deleteReceiptFromSupabase(path: String) async -> Bool {

        let encodedPath =
            path.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed
            ) ?? path

        let urlString =
            "\(SupabaseConfig.projectURL)/storage/v1/object/fuel-receipts/\(encodedPath)"

        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        request.setValue(
            SupabaseConfig.anonKey,
            forHTTPHeaderField: "apikey"
        )

        request.setValue(
            "Bearer \(SupabaseConfig.anonKey)",
            forHTTPHeaderField: "Authorization"
        )

        do {
            let (data, response) =
                try await URLSession.shared.data(for: request)

            if let text = String(data: data, encoding: .utf8) {
                print("🗑 Delete response:", text)
            }

            if let http = response as? HTTPURLResponse {
                print("🗑 Delete status:", http.statusCode)
                return (200...299).contains(http.statusCode)
            }

            return false

        } catch {
            print("❌ Delete receipt failed:", error)
            return false
        }
    }
}
