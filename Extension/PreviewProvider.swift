import QuickLookUI
import UniformTypeIdentifiers

/// Data-based QuickLook preview: hands QuickLook a finished HTML page and
/// lets the system display it. The extension never spawns WebKit helper
/// processes — WKWebView cannot launch its WebContent process inside the
/// QuickLook extension sandbox on macOS 26, which shows as an eternal
/// loading spinner.
final class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    private static let renderer = Result {
        try Renderer(resourceURL: Bundle.main.resourceURL.unwrap(or: RendererError.missingResource("Resources")))
    }

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let renderer = try Self.renderer.get()
        let url = request.fileURL
        let text = try Renderer.decodeText(at: url)
        let page = try renderer.renderPage(
            text: text,
            name: url.lastPathComponent,
            ext: url.pathExtension
        )
        let reply = QLPreviewReply(
            dataOfContentType: .html,
            contentSize: CGSize(width: 800, height: 850)
        ) { reply in
            reply.title = url.lastPathComponent
            reply.stringEncoding = .utf8
            return Data(page.utf8)
        }
        return reply
    }
}

private extension Optional {
    func unwrap(or error: Error) throws -> Wrapped {
        guard let value = self else { throw error }
        return value
    }
}
