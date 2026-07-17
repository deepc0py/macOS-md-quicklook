# macOS-md-quicklook

Styled QuickLook previews for Markdown — press Space on a `.md` file in
Finder and read it rendered, not as plain text. Built for macOS Tahoe 26
as a native Quick Look preview extension. Fully offline, ad-hoc signed,
no App Store, no third-party binaries: `git clone && make install`.

| GitHub-flavored Markdown | Jira wiki markup |
| --- | --- |
| ![Markdown preview](docs/screenshot-markdown.png) | ![Jira preview](docs/screenshot-jira.png) |

## What renders

- **CommonMark + GFM**: tables, task lists, strikethrough, autolinks
  (via `markdown-it` with the GFM feature set)
- **Footnotes**, **emoji shortcodes** (`:rocket:`), YAML **front matter**
  (shown as a collapsible block)
- **Syntax highlighting** for the highlight.js common set plus Scala,
  Dockerfile, PowerShell, Protobuf, Elixir, Haskell, Dart, Groovy,
  Clojure, Erlang, Julia, and nginx
- **Mermaid diagrams** in ` ```mermaid ` fences
- **Jira / Confluence wiki markup** (`h1.`, `{code}`, `||tables||`,
  `{quote}`, `{color}`, `[link|url]`, nested `*`/`#` lists, …) —
  translated to Markdown before rendering, with a badge marking the
  conversion
- Automatic **light / dark mode**, GitHub look and feel

File extensions claimed: `md, markdown, mdown, mkdn, mkd, mdwn, mdtxt,
mdtext, mdx, rmd, qmd` (UTI `net.daringfireball.markdown`) and
`jira, confluence` (UTI `com.deepc0py.jira-wiki`).

## Install

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```sh
git clone git@github.com:deepc0py/macOS-md-quicklook.git
cd macOS-md-quicklook
make install
```

`make install` builds Release, installs to `~/Applications`, registers
the extension, and opens the companion app. Then:

1. If previews still show plain text, open **System Settings → General →
   Login Items & Extensions → Quick Look** and enable
   **Markdown QuickLook Preview** (the app has a button for this).
2. Press Space on any Markdown file in Finder.

The companion app window doubles as a self-test: its right pane renders
the bundled sample **through the same QuickLook machinery Finder uses**.
If that pane is styled, spacebar previews are working. Drop any file
onto it to test.

The build is ad-hoc signed (`CODE_SIGN_IDENTITY=-`): no developer
account, no notarization, nothing leaves the machine. Everything the
renderer needs is vendored into the extension bundle; the extension is
sandboxed with no network entitlement, so previews can never phone home.

## How it works

```mermaid
flowchart LR
    Finder -- space --> QL[QuickLook]
    QL --> Appex[PreviewExtension.appex\nQLPreviewingController]
    Appex --> WK[WKWebView, offline]
    WK --> MD[markdown-it + plugins]
    WK --> HL[highlight.js]
    WK --> MM[mermaid]
```

- `Extension/PreviewViewController.swift` reads the file (UTF-8 first,
  BOM/xattr detection, then CP1252/Latin-1), loads `preview.html` into a
  WKWebView, and calls `renderDocument(payload)`. The QuickLook
  completion handler fires only after the render succeeds, so failures
  surface instead of showing a blank panel.
- `Extension/Resources/markdown.js` configures markdown-it (GFM,
  footnotes, task lists, emoji), routes fenced code through highlight.js
  and ` ```mermaid ` fences through mermaid, and strips active content
  (`<script>`, event handlers, `javascript:` URLs) from inline HTML.
- `Extension/Resources/jira.js` converts Jira wiki markup. Files named
  `*.jira`/`*.confluence` always convert; other files convert only when
  they score at least two strong Jira signals (`h1.` headings, `{code}`,
  `{noformat}`, `||header||`, `bq.`, `{quote}`, `{panel}`) **and**
  contain no Markdown headings or fences. `make test-jira` runs a
  regression check over the sample.
- External links open in your browser; the preview itself never
  navigates away.

## Limitations

- Images referenced by relative path don't load: QuickLook's sandbox
  grants the extension access to the previewed file only. Remote images
  are also blocked (no network entitlement) — deliberately.
- `qlmanage -p` does not host third-party preview extensions on modern
  macOS; test with Finder or the companion app instead.
- Jira markup without a header row renders its tables as plain rows —
  Markdown tables require a header.

## Vendored dependencies

Pinned and committed under `Extension/Resources/vendor/` (checksums in
`SHA256SUMS`, re-fetch with `scripts/fetch-vendor.sh`):

| Package | Version | License |
| --- | --- | --- |
| [markdown-it](https://github.com/markdown-it/markdown-it) | 14.1.0 | MIT |
| [markdown-it-footnote](https://github.com/markdown-it/markdown-it-footnote) | 4.0.0 | MIT |
| [markdown-it-task-lists](https://github.com/revin/markdown-it-task-lists) | 2.1.1 | ISC |
| [markdown-it-emoji](https://github.com/markdown-it/markdown-it-emoji) | 3.0.0 | MIT |
| [highlight.js](https://github.com/highlightjs/highlight.js) | 11.11.1 | BSD-3-Clause |
| [github-markdown-css](https://github.com/sindresorhus/github-markdown-css) | 5.8.1 | MIT |
| [mermaid](https://github.com/mermaid-js/mermaid) | 11.4.1 | MIT |

The Jira conversion rules are informed by
[J2M](https://github.com/FokkeZB/J2M) (MIT).

## Uninstall

```sh
make uninstall
```

## License

MIT — see [LICENSE](LICENSE).
