//
//  SharedFolderSetupView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/10/26.
//
import SwiftUI
import UniformTypeIdentifiers

struct SharedFolderSetupView: View {

    @State private var showFolderPicker = false
    @State private var selectedFolderName = ""

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

            VStack(spacing: 26) {

                Spacer()

                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 70))
                    .foregroundStyle(.blue)

                Text("Connect Shared Folder")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text(
                    "Select the shared company folder provided by your administrator."
                )
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal)

                Button {

                    showFolderPicker = true

                } label: {

                    Label(
                        selectedFolderName.isEmpty
                        ? "Select Shared Folder"
                        : selectedFolderName,
                        systemImage: "folder.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                if !selectedFolderName.isEmpty {

                    Text("Folder Connected ✅")
                        .foregroundStyle(.green)
                }

                Spacer()
            }
            .padding()
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in

            switch result {

            case .success(let url):

                let didAccess =
                    url.startAccessingSecurityScopedResource()

                if didAccess {

                    StorageManager.saveTruckReportsFolder(url)

                    selectedFolderName =
                        url.lastPathComponent

                    print(
                        "✅ Shared folder selected:",
                        url.path
                    )

                    url.stopAccessingSecurityScopedResource()
                }

            case .failure(let error):

                print(
                    "❌ Folder picker failed:",
                    error
                )
            }
        }
    }
}
