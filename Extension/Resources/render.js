/* Renderer core: markdown (GFM) / Jira wiki markup -> HTML body string.
 * Runs inside JavaScriptCore in the QuickLook extension (no DOM available)
 * and doubles as the engine for the browser dev harness (preview.html).
 * Entry point: renderDocumentHTML(payload) -> string. */
"use strict";
(function (global) {
  let renderer = null;

  function escapeHtml(s) {
    return s
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function getRenderer() {
    if (renderer) return renderer;
    const emojiPlugin = global.markdownitEmoji.full || global.markdownitEmoji;
    renderer = global
      .markdownit({
        html: true,
        linkify: true,
        highlight(code, lang) {
          const language = (lang || "").trim().toLowerCase().split(/\s+/)[0];
          // QuickLook's HTML view executes no scripts, so mermaid cannot run;
          // fences fall through to a plain block styled as diagram source.
          if (language && language !== "mermaid" && global.hljs.getLanguage(language)) {
            const value = global.hljs.highlight(code, { language, ignoreIllegals: true }).value;
            return '<pre><code class="hljs language-' + language + '">' + value + "</code></pre>";
          }
          return "";
        },
      })
      .use(global.markdownitFootnote)
      .use(global.markdownitTaskLists, { label: true })
      .use(emojiPlugin);
    return renderer;
  }

  // The preview host never executes JavaScript; stripping script tags is
  // defense in depth, not the security boundary.
  function stripScripts(html) {
    return html
      .replace(/<script\b[^>]*>[\s\S]*?<\/script\s*>/gi, "")
      .replace(/<script\b[^>]*\/?>/gi, "");
  }

  function splitFrontMatter(text) {
    const match = text.match(/^\uFEFF?---[ \t]*\n([\s\S]*?)\n(?:---|\.\.\.)[ \t]*(?:\n|$)/);
    if (!match) return { frontMatter: null, body: text };
    return { frontMatter: match[1], body: text.slice(match[0].length) };
  }

  global.renderDocumentHTML = function renderDocumentHTML(payload) {
    const ext = (payload.ext || "").toLowerCase();
    let source = payload.text.replace(/\r\n?/g, "\n");

    let convertedFromJira = false;
    if (global.JiraMarkup.shouldConvert(source, ext)) {
      source = global.JiraMarkup.toMarkdown(source);
      convertedFromJira = true;
    }

    const { frontMatter, body } = splitFrontMatter(source);
    let html = stripScripts(getRenderer().render(body));
    if (frontMatter) {
      html =
        '<details class="front-matter"><summary>Front matter</summary><pre>' +
        escapeHtml(frontMatter) +
        "</pre></details>" +
        html;
    }
    if (convertedFromJira) {
      html = '<div class="jira-badge">Jira wiki markup</div>' + html;
    }
    return html;
  };
})(typeof window !== "undefined" ? window : globalThis);
