//
//  DriverFilesView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/20/26.
//

import SwiftUI
import UIKit

struct DriverFilesView: View {

    @State private var driverFolders: [URL] = []

    var body: some View {

        NavigationStack {

            List {

                ForEach(driverFolders, id: \.self) { folder in

                    NavigationLink {

                        DriverFolderDetailView(
                            folder: folder
                        )

                    } label: {

                        Label(
                            folder.lastPathComponent,
                            systemImage: "person.fill"
                        )
                    }
                }
            }
            .navigationTitle("Driver Files")
            .onAppear {
                loadDriverFolders()
            }
        }
    }

    func loadDriverFolders() {

        let driversFolder =
            StorageManager
                .truckReportsFolder()
                .appendingPathComponent("Drivers")

        do {

            driverFolders =
                try FileManager.default
                    .contentsOfDirectory(
                        at: driversFolder,
                        includingPropertiesForKeys: nil
                    )
                    .filter { $0.hasDirectoryPath }

        } catch {

            print(
                "❌ Failed loading driver folders:",
                error
            )
        }
    }
}

struct DriverFolderDetailView: View {

    let folder: URL

    @State private var files: [URL] = []

    var body: some View {

        List {

            ForEach(files, id: \.self) { file in

                if file.hasDirectoryPath {

                    NavigationLink {

                        DriverSubfolderView(folder: file)

                    } label: {

                        Label(
                            file.lastPathComponent,
                            systemImage: "folder.fill"
                        )
                    }

                } else {

                    VStack(alignment: .leading) {

                        Text(file.lastPathComponent)
                            .font(.headline)

                        Text(file.path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }        }
        .navigationTitle(folder.lastPathComponent)
        .onAppear {
            loadFiles()
        }
    }

    func loadFiles() {

        do {

            files =
                try FileManager.default
                    .contentsOfDirectory(
                        at: folder,
                        includingPropertiesForKeys: nil
                    )

        } catch {

            print(
                "❌ Failed loading files:",
                error
            )
        }
    }
}

struct DriverSubfolderView: View {

    let folder: URL

    @State private var files: [URL] = []

    var body: some View {

        List {

            ForEach(files, id: \.self) { file in

                if let image = UIImage(contentsOfFile: file.path) {

                    VStack(alignment: .leading, spacing: 10) {

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 18))

                        Text(file.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)

                } else {

                    Text(file.lastPathComponent)
                }
            }
        }
        .navigationTitle(folder.lastPathComponent)
        .onAppear {
            loadFiles()
        }
    }

    func loadFiles() {

        do {

            files =
                try FileManager.default
                    .contentsOfDirectory(
                        at: folder,
                        includingPropertiesForKeys: nil
                    )

        } catch {

            print(
                "❌ Failed loading subfolder:",
                error
            )
        }
    }
}
