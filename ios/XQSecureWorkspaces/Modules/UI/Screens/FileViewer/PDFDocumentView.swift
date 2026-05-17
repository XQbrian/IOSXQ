import SwiftUI
import PDFKit

/// SwiftUI wrapper around `PDFKit.PDFView` that renders an in-memory PDF
/// document supplied as raw `Data`. Used by the FileViewer to display
/// generated previews of encrypted documents after they have been
/// decrypted and AI-classified on-device.
struct PDFDocumentView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)
        view.pageShadowsEnabled = true
        // Keep the document anchored so the watermark overlay sits over real content.
        view.minScaleFactor = view.scaleFactorForSizeToFit
        view.maxScaleFactor = 4.0
        return view
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document == nil, let doc = PDFDocument(data: data) {
            pdfView.document = doc
        }
    }
}
