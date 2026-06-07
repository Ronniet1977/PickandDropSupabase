//
//  SupabaseStorageImage.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 6/7/26.
//

import SwiftUI
import UIKit

struct SupabaseStorageImage: View {
    let path: String

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await loadImage()
        }
    }

    func loadImage() async {
        guard let url = URL(
            string: "\(SupabaseConfig.projectURL)/storage/v1/object/fuel-receipts/\(path)"
        ) else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse {
                print("Receipt image status:", http.statusCode)
            }

            if let loadedImage = UIImage(data: data) {
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            print("Receipt image load failed:", error)

            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
