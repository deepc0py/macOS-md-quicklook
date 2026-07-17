/* QuickLook markdown renderer: GFM via markdown-it, syntax highlighting via
 * highlight.js, diagrams via mermaid. Entry point is window.renderDocument,
 * invoked by the PreviewExtension after the template finishes loading. */
"use strict";
(function () {
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
    const emojiPlugin = window.markdownitEmoji.full || window.markdownitEmoji;
    renderer = window
      .markdownit({
        html: true,
        linkify: true,
        highlight(code, lang) {
          const language = (lang || "").trim().toLowerCase().split(/\s+/)[0];
          if (language === "mermaid") {
            return '<pre class="mermaid">' + escapeHtml(code) + "</pre>";
          }
          if (language && window.hljs.getLanguage(language)) {
            const value = window.hljs.highlight(code, { language, ignoreIllegals: true }).value;
            return '<pre><code class="hljs language-' + language + '">' + value + "</code></pre>";
          }
          return "";
        },
      })
      .use(window.markdownitFootnote)
      .use(window.markdownitTaskLists, { label: true })
      .use(emojiPlugin);
    return renderer;
  }

  // Raw HTML passes through (like GitHub), but active content does not.
  function sanitize(html) {
    const template = document.createElement("template");
    template.innerHTML = html;
    template.content
      .querySelectorAll("script, iframe, object, embed, base, link, meta, form")
      .forEach((el) => el.remove());
    template.content.querySelectorAll("*").forEach((el) => {
      for (const attr of Array.from(el.attributes)) {
        const name = attr.name.toLowerCase();
        if (name.startsWith("on")) el.removeAttribute(attr.name);
        else if (
          (name === "href" || name === "src" || name === "xlink:href") &&
          /^\s*javascript:/i.test(attr.value)
        ) {
          el.removeAttribute(attr.name);
        }
      }
    });
    return template.content;
  }

  function splitFrontMatter(text) {
    const match = text.match(/^\uFEFF?---[ \t]*\n([\s\S]*?)\n(?:---|\.\.\.)[ \t]*(?:\n|$)/);
    if (!match) return { frontMatter: null, body: text };
    return { frontMatter: match[1], body: text.slice(match[0].length) };
  }

  function frontMatterNode(yaml) {
    const details = document.createElement("details");
    details.className = "front-matter";
    const summary = document.createElement("summary");
    summary.textContent = "Front matter";
    const pre = document.createElement("pre");
    pre.textContent = yaml;
    details.append(summary, pre);
    return details;
  }

  function renderMermaid() {
    const nodes = Array.from(document.querySelectorAll("pre.mermaid"));
    if (!nodes.length) return;
    const dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    window.mermaid.initialize({
      startOnLoad: false,
      securityLevel: "strict",
      theme: dark ? "dark" : "default",
    });
    // Diagram syntax errors are document content: mermaid marks the failing
    // node in place and the rest of the preview stays intact.
    window.mermaid.run({ nodes }).catch(() => {});
  }

  window.renderDocument = function renderDocument(payload) {
    const ext = (payload.ext || "").toLowerCase();
    let source = payload.text.replace(/\r\n?/g, "\n");

    let convertedFromJira = false;
    if (window.JiraMarkup.shouldConvert(source, ext)) {
      source = window.JiraMarkup.toMarkdown(source);
      convertedFromJira = true;
    }

    const { frontMatter, body } = splitFrontMatter(source);
    const article = document.getElementById("content");
    article.replaceChildren(sanitize(getRenderer().render(body)));
    if (frontMatter) article.prepend(frontMatterNode(frontMatter));

    document.querySelector(".jira-badge")?.remove();
    if (convertedFromJira) {
      const badge = document.createElement("div");
      badge.className = "jira-badge";
      badge.textContent = "Jira wiki markup";
      document.body.prepend(badge);
    }

    renderMermaid();
    return true;
  };
})();
