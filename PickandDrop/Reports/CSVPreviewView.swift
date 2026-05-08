//
//  CSVPreviewView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/7/26.
//

import SwiftUI

struct CSVPreviewView: View {

    let fileURL: URL

    @State private var csvText = ""

    var body: some View {

        ScrollView {

            Text(csvText)
                .font(.system(.caption, design: .monospaced))
                .padding()
        }
        .navigationTitle(fileURL.lastPathComponent)
        .onAppear {
            loadCSV()
        }
    }

    func loadCSV() {

        do {

            csvText = try String(
                contentsOf: fileURL,
                encoding: .utf8
            )

        } catch {

            csvText = "❌ Failed to load CSV"
        }
    }
}
