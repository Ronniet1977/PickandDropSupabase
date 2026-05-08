//
//  ReportsView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/7/26.
//

import SwiftUI

struct ReportsView: View {

    @State private var reportFiles: [URL] = []

    var body: some View {

        NavigationStack {

            List {

                ForEach(reportFiles, id: \.self) { file in

                    NavigationLink {

                        CSVPreviewView(fileURL: file)

                    } label: {

                        VStack(alignment: .leading) {

                            Text(file.lastPathComponent)
                                .font(.headline)

                            if file.lastPathComponent.contains("FINAL") {

                                Text("✅ Final Report")
                                    .font(.caption)
                                    .foregroundStyle(.green)

                            } else {

                                Text("🟢 Active Report")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reports")
            .onAppear {
                loadFiles()
            }
        }
    }

    func loadFiles() {

        let folder = StorageManager.truckReportsFolder()

        do {

            let files = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )

            reportFiles = files
                .filter {
                    $0.pathExtension == "csv"
                }
                .sorted {
                    $0.lastPathComponent > $1.lastPathComponent
                }

        } catch {

            print("❌ Failed loading reports:", error)
        }
    }
}
