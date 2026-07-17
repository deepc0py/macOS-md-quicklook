// Development harness: runs the extension's exact JavaScriptCore pipeline
// (Renderer.swift + the bundled JS) outside the sandbox and emits the full
// HTML page QuickLook would receive. Used by `make test-render`.
//
//   render-cli <resources-dir> <input-file> [output-file]

import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: render-cli <resources-dir> <input-file> [output-file]\n".utf8))
    exit(64)
}

let resources = URL(fileURLWithPath: arguments[1], isDirectory: true)
let input = URL(fileURLWithPath: arguments[2])

let renderer = try Renderer(resourceURL: resources)
let text = try Renderer.decodeText(at: input)
let page = try renderer.renderPage(
    text: text,
    name: input.lastPathComponent,
    ext: input.pathExtension
)

if arguments.count >= 4 {
    try page.write(to: URL(fileURLWithPath: arguments[3]), atomically: true, encoding: .utf8)
} else {
    FileHandle.standardOutput.write(Data(page.utf8))
}
