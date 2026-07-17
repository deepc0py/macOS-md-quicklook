import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    private static let sampleURL = Bundle.main.url(forResource: "Sample", withExtension: "md")!

    @State private var previewedURL = Self.sampleURL
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 320)
            Divider()
            previewPane
        }
    }

    // MARK: Setup

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Markdown QuickLook")
                    .font(.title2.weight(.semibold))
                Text("Styled spacebar previews for Markdown and Jira wiki files in Finder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 18) {
                step("1", "Keep this app installed",
                     "macOS discovers the preview extension from this app. Keep it in your Applications folder.")
                VStack(alignment: .leading, spacing: 8) {
                    step("2", "Enable the extension",
                         "Turn on “Markdown QuickLook Preview” under Quick Look extensions in System Settings.")
                    Button("Open Quick Look Settings") { openExtensionSettings() }
                        .padding(.leading, 30)
                }
                step("3", "Preview",
                     "Select any Markdown file in Finder and press Space.")
            }

            Spacer()

            Text("If the document on the right renders with styling, the extension is active.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private func step(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.callout.weight(.semibold).monospacedDigit())
                .frame(width: 20, height: 20)
                .background(Circle().fill(.quaternary))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func openExtensionSettings() {
        let pane = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences"
            + "?extensionPointIdentifier=com.apple.quicklook.preview")!
        NSWorkspace.shared.open(pane)
    }

    // MARK: Live preview

    private var previewPane: some View {
        VStack(spacing: 0) {
            QuickLookPreview(url: previewedURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.document")
                    .foregroundStyle(.secondary)
                Text(previewedURL == Self.sampleURL
                     ? "Drop a Markdown or Jira file here to test it"
                     : previewedURL.lastPathComponent)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                if previewedURL != Self.sampleURL {
                    Button("Show Sample") { previewedURL = Self.sampleURL }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { previewedURL = url }
            }
            return true
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(4)
            }
        }
    }
}
