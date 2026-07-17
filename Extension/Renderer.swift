import Foundation
import JavaScriptCore

enum RendererError: LocalizedError {
    case contextCreationFailed
    case missingResource(String)
    case javascript(String)
    case undecodableFile(URL)

    var errorDescription: String? {
        switch self {
        case .contextCreationFailed:
            return "JavaScriptCore context could not be created."
        case .missingResource(let name):
            return "\(name) is missing from the extension bundle."
        case .javascript(let message):
            return "Renderer JavaScript failed: \(message)"
        case .undecodableFile(let url):
            return "\(url.lastPathComponent) is not a text file this preview can decode."
        }
    }
}

/// Runs the vendored markdown pipeline (markdown-it, highlight.js, the Jira
/// converter) inside JavaScriptCore and wraps the result in a complete HTML
/// page with all CSS inlined. No DOM, no web processes — QuickLook's own
/// HTML view does the displaying, which is the only rendering path the
/// macOS 26 extension sandbox permits.
final class Renderer {

    /// Load order matters: shim, engine, plugins, grammars, converter, core.
    private static let scripts = [
        "vendor/markdown-it.min.js",
        "vendor/markdown-it-footnote.min.js",
        "vendor/markdown-it-task-lists.min.js",
        "vendor/markdown-it-emoji.min.js",
        "vendor/highlight.min.js",
        "vendor/hljs-scala.min.js",
        "vendor/hljs-dockerfile.min.js",
        "vendor/hljs-powershell.min.js",
        "vendor/hljs-protobuf.min.js",
        "vendor/hljs-elixir.min.js",
        "vendor/hljs-haskell.min.js",
        "vendor/hljs-dart.min.js",
        "vendor/hljs-groovy.min.js",
        "vendor/hljs-clojure.min.js",
        "vendor/hljs-erlang.min.js",
        "vendor/hljs-julia.min.js",
        "vendor/hljs-nginx.min.js",
        "jira.js",
        "render.js",
    ]

    private let context: JSContext
    private let renderFunction: JSValue
    private let pageHeader: String
    private let pageFooter = "</article></body></html>"
    private var lastException: String?

    init(resourceURL: URL) throws {
        guard let context = JSContext() else {
            throw RendererError.contextCreationFailed
        }
        self.context = context

        var loadException: String?
        context.exceptionHandler = { _, exception in
            loadException = exception?.toString()
        }
        context.evaluateScript(
            "var window = globalThis; var self = globalThis;"
                + "var console = { log: function () {}, warn: function () {}, error: function () {} };"
        )

        func read(_ name: String) throws -> String {
            let url = resourceURL.appendingPathComponent(name)
            guard let source = try? String(contentsOf: url, encoding: .utf8) else {
                throw RendererError.missingResource(name)
            }
            return source
        }

        for name in Self.scripts {
            context.evaluateScript(try read(name), withSourceURL: URL(fileURLWithPath: name))
            if let message = loadException {
                throw RendererError.javascript("\(name): \(message)")
            }
        }

        guard let function = context.objectForKeyedSubscript("renderDocumentHTML"),
              !function.isUndefined
        else {
            throw RendererError.javascript("renderDocumentHTML is not defined")
        }
        renderFunction = function

        let style = try read("vendor/github-markdown.css")
            + "@media (prefers-color-scheme: light){\n" + (try read("vendor/hljs-github.min.css")) + "\n}"
            + "@media (prefers-color-scheme: dark){\n" + (try read("vendor/hljs-github-dark.min.css")) + "\n}"
            + (try read("style.css"))
        pageHeader = """
            <!DOCTYPE html><html><head><meta charset="utf-8">\
            <meta name="color-scheme" content="light dark"><style>
            \(style)
            </style></head><body><article class="markdown-body">
            """

        context.exceptionHandler = { [weak self] _, exception in
            self?.lastException = exception?.toString()
        }
    }

    func renderPage(text: String, name: String, ext: String) throws -> String {
        lastException = nil
        let payload: [String: String] = ["text": text, "name": name, "ext": ext]
        let result = renderFunction.call(withArguments: [payload])
        if let message = lastException {
            throw RendererError.javascript(message)
        }
        guard let body = result?.toString(), result?.isString == true else {
            throw RendererError.javascript("renderDocumentHTML did not return a string")
        }
        return pageHeader + body + pageFooter
    }

    /// Decodes honoring BOMs and extended attributes, then common single-byte
    /// encodings; markdown in the wild is occasionally CP1252.
    static func decodeText(at url: URL) throws -> String {
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
        throw RendererError.undecodableFile(url)
    }
}
