import SwiftUI
import QuickLook

/// Full-screen QuickLook presenter. Present via .fullScreenCover.
/// QLPreviewController handles PDF, DOCX, XLSX, PPTX, images, and more natively.
/// UIKit's built-in Done button dismisses the modal; the SwiftUI isPresented binding
/// is updated automatically when UIKit tears down the presentation.
struct QuickLookPreview: UIViewControllerRepresentable {

    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let ql = QLPreviewController()
        ql.dataSource = context.coordinator
        let nav = UINavigationController(rootViewController: ql)
        nav.navigationBar.tintColor = UIColor(red: 0.239, green: 0.353, blue: 0.996, alpha: 1)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        private let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            url as NSURL
        }
    }
}
