import Cocoa
import Quartz
import WebKit

enum PreviewError: LocalizedError {
    case missingTemplate
    case undecodableFile(URL)

    var errorDescription: String? {
        switch self {
        case .missingTemplate:
            return "preview.html is missing from the extension bundle."
        case .undecodableFile(let url):
            return "\(url.lastPathComponent) is not a text file this preview can decode."
        }
    }
}

final class PreviewViewController: NSViewController, QLPreviewingController {

    private var webView: WKWebView!
    private var pendingRender: String?
    private var completionHandler: ((Error?) -> Void)?

    override var nibName: NSNib.Name? { nil }

    override func loadView() {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        self.webView = webView
        view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let payload: [String: String] = [
                "text": try Self.decodeText(at: url),
                "name": url.lastPathComponent,
                "ext": url.pathExtension,
            ]
            let json = try JSONSerialization.data(withJSONObject: payload)
            pendingRender = "renderDocument(\(String(decoding: json, as: UTF8.self)))"
            completionHandler = handler

            guard let template = Bundle.main.url(forResource: "preview", withExtension: "html"),
                  let resources = Bundle.main.resourceURL
            else {
                throw PreviewError.missingTemplate
            }
            webView.loadFileURL(template, allowingReadAccessTo: resources)
        } catch {
            handler(error)
        }
    }

    /// Decodes the file honoring BOMs and extended attributes, then common
    /// single-byte encodings; markdown in the wild is occasionally CP1252.
    private static func decodeText(at url: URL) throws -> String {
        var encoding = String.Encoding.utf8
        if let text = try? String(contentsOf: url, usedEncoding: &encoding) {
            return text
        }
        let data = try Data(contentsOf: url)
        for fallback in [String.Encoding.utf8, .windowsCP1252, .isoLatin1] {
            if let text = String(data: data, encoding: fallback) {
                return text
            }
        }
        throw PreviewError.undecodableFile(url)
    }

    private func finish(_ error: Error?) {
        pendingRender = nil
        completionHandler?(error)
        completionHandler = nil
    }
}

extension PreviewViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let script = pendingRender else { return }
        pendingRender = nil
        webView.evaluateJavaScript(script) { [weak self] _, error in
            self?.finish(error)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(error)
    }

    /// Keep navigation inside the preview local; hand external links to the
    /// user's browser instead of navigating the QuickLook panel.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            return decisionHandler(.cancel)
        }
        if url.isFileURL || url.scheme == "about" {
            return decisionHandler(.allow)
        }
        NSWorkspace.shared.open(url)
        decisionHandler(.cancel)
    }
}
