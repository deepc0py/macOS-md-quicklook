#!/usr/bin/env bash
# Fetches pinned, offline copies of the web renderer dependencies.
# Outputs are committed to the repo; this script exists to document
# provenance and to make version bumps a one-command operation.
set -euo pipefail

DEST="$(cd "$(dirname "$0")/.." && pwd)/Extension/Resources/vendor"
mkdir -p "$DEST"

fetch() {
  local url="$1" out="$2"
  echo "fetching $out"
  curl -fsSL --retry 3 "$url" -o "$DEST/$out"
}

# Markdown engine (CommonMark + GFM tables/strikethrough/autolink via preset)
fetch https://cdn.jsdelivr.net/npm/markdown-it@14.1.0/dist/markdown-it.min.js                       markdown-it.min.js
fetch https://cdn.jsdelivr.net/npm/markdown-it-footnote@4.0.0/dist/markdown-it-footnote.min.js       markdown-it-footnote.min.js
fetch https://cdn.jsdelivr.net/npm/markdown-it-task-lists@2.1.1/dist/markdown-it-task-lists.min.js   markdown-it-task-lists.min.js
fetch https://cdn.jsdelivr.net/npm/markdown-it-emoji@3.0.0/dist/markdown-it-emoji.min.js             markdown-it-emoji.min.js

# Syntax highlighting (common-languages build)
fetch https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/highlight.min.js             highlight.min.js
fetch https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/styles/github.min.css        hljs-github.min.css
fetch https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/styles/github-dark.min.css   hljs-github-dark.min.css

# Grammars beyond the common build that developers hit routinely
for lang in scala dockerfile powershell protobuf elixir haskell dart groovy clojure erlang julia nginx; do
  fetch "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/languages/$lang.min.js" "hljs-$lang.min.js"
done

# GitHub look-and-feel (auto light/dark)
fetch https://cdn.jsdelivr.net/npm/github-markdown-css@5.8.1/github-markdown.css                     github-markdown.css

(cd "$DEST" && rm -f SHA256SUMS && shasum -a 256 -- * | tee SHA256SUMS)
