//
//  PDFKitView.swift
//  PickandDrop
//
//  Created by Ronald Thayer Jr on 5/7/26.
//

import SwiftUI
import PDFKit

#if os(iOS)

struct PDFKitView: UIViewRepresentable {

    let url: URL

    func makeUIView(context: Context) -> PDFView {

        let pdfView = PDFView()

        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.document = PDFDocument(url: url)

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {

    }
}

#elseif os(macOS)

struct PDFKitView: NSViewRepresentable {

    let url: URL

    func makeNSView(context: Context) -> PDFView {

        let pdfView = PDFView()

        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.document = PDFDocument(url: url)

        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {

    }
}

#endif
