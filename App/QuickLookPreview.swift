import Quartz
import SwiftUI

/// Hosts a QLPreviewView so the app can display files through the same
/// QuickLook machinery Finder uses. When the preview extension is enabled,
/// documents render styled here; when it is not, they render as plain text —
/// which makes this view an honest self-test for the whole pipeline.
struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        guard let view = QLPreviewView(frame: .zero, style: .normal) else {
            fatalError("QLPreviewView could not be created")
        }
        view.shouldCloseWithWindow = false
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        if nsView.previewItem?.previewItemURL != url {
            nsView.previewItem = url as NSURL
        }
    }
}
