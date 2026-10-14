import SwiftUI
import PDFKit

struct PDFPreviewView: UIViewRepresentable {
    
    let url: URL
    
    func makeUIView(
        context: Context
    ) -> PDFView {
        
        let pdfView = PDFView()
        
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        pdfView.document =
        PDFDocument(url: url)
        
        return pdfView
    }
    
    func updateUIView(
        _ pdfView: PDFView,
        context: Context
    ) {
        
        if pdfView.document?.documentURL != url {
            
            pdfView.document =
            PDFDocument(url: url)
        }
    }
}

