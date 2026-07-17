/* Jira / Confluence wiki markup -> Markdown.
 * Conversion rules informed by J2M (https://github.com/FokkeZB/J2M, MIT license),
 * reimplemented here for the QuickLook preview pipeline. */
"use strict";
(function () {
  const JIRA_EXTENSIONS = new Set(["jira", "confluence", "wiki"]);

  // Files with these signals are treated as Jira markup even when named *.md.
  // Deliberately conservative: real Markdown headings or fences veto conversion.
  function shouldConvert(text, ext) {
    if (JIRA_EXTENSIONS.has(ext)) return true;
    if (/^#{1,6}\s/m.test(text) || /^```/m.test(text)) return false;
    let score = 0;
    if (/^h[1-6]\.\s/m.test(text)) score += 2;
    if (/\{code(?::[^}]*)?\}/.test(text)) score += 2;
    if (/\{noformat\}/.test(text)) score += 2;
    if (/^\|\|.+\|\|\s*$/m.test(text)) score += 1;
    if (/^bq\.\s/m.test(text)) score += 1;
    if (/\{quote\}/.test(text)) score += 1;
    if (/\{panel[:}]/.test(text)) score += 1;
    return score >= 2;
  }

  function fencedBlock(lang, body) {
    const trimmed = body.replace(/^\n/, "").replace(/\n?$/, "\n");
    return "```" + lang + "\n" + trimmed + "```";
  }

  function codeLanguage(params) {
    if (!params) return "";
    let lang = "";
    for (const part of params.split("|")) {
      const eq = part.indexOf("=");
      if (eq === -1) {
        if (!lang) lang = part.trim();
      } else if (part.slice(0, eq).trim().toLowerCase() === "language") {
        lang = part.slice(eq + 1).trim();
      }
    }
    return lang;
  }

  function toMarkdown(input) {
    const stash = [];
    const keep = (chunk) => {
      stash.push(chunk);
      return "\u0000J2M" + (stash.length - 1) + "\u0000";
    };

    let text = input
      .replace(/\{code(?::([^}]*))?\}([\s\S]*?)\{code\}/g, (_, params, body) =>
        keep(fencedBlock(codeLanguage(params), body)))
      .replace(/\{noformat\}([\s\S]*?)\{noformat\}/g, (_, body) =>
        keep(fencedBlock("", body)));

    text = text
      // block-level structures
      .replace(/\{quote\}([\s\S]*?)\{quote\}/g, (_, body) =>
        "\n" + body.trim().split("\n").map((l) => "> " + l).join("\n") + "\n")
      .replace(/\{panel(?::title=([^}|]*)[^}]*|:[^}]*)?\}([\s\S]*?)\{panel\}/g, (_, title, body) => {
        const lines = body.trim().split("\n").map((l) => "> " + l);
        if (title) lines.unshift("> **" + title.trim() + "**", ">");
        return "\n" + lines.join("\n") + "\n";
      })
      .replace(/\{color:([^}]+)\}([\s\S]*?)\{color\}/g, '<span style="color:$1">$2</span>')
      .replace(/^bq\.\s+/gm, "> ")
      // tables: Jira header rows become header + separator
      .replace(/^\|\|(.+?)\|\|\s*$/gm, (_, row) => {
        const cells = row.split("||").map((c) => c.trim());
        return "| " + cells.join(" | ") + " |\n|" + cells.map(() => " --- ").join("|") + "|";
      })
      // lists before headings: heading conversion emits '# ' which would
      // otherwise be re-parsed as an ordered-list marker
      .replace(/^[ \t]*([*#]+)\s+/gm, (_, markers) => {
        const indent = "  ".repeat(markers.length - 1);
        return indent + (markers.endsWith("#") ? "1. " : "- ");
      })
      .replace(/^h([1-6])\.\s*/gm, (_, level) => "#".repeat(Number(level)) + " ")
      // media and links
      .replace(/!([^!\s|]+\.[A-Za-z0-9]+)(?:\|[^!\n]*)?!/g, "![]($1)")
      .replace(/\[~([^\]\n]+)\]/g, "**@$1**")
      .replace(/\[((?:https?|mailto|ftp):[^\]\s]+)\]/g, "<$1>")
      .replace(/\[([^|\]\n]+)\|([^|\]\n]+)(?:\|[^\]\n]*)?\]/g, "[$1]($2)")
      // inline formatting; delimiter characters are excluded from group
      // boundaries so emitted markdown ('**', '~~', '---') never re-matches
      .replace(/\{\{([^}\n]+?)\}\}/g, "`$1`")
      .replace(/\^([^^\s][^^\n]*?)\^/g, "<sup>$1</sup>")
      .replace(/~([^~\s][^~\n]*?)~/g, "<sub>$1</sub>")
      .replace(/\?\?((?:[^?\n]|\?(?!\?))+)\?\?/g, "<cite>$1</cite>")
      .replace(/(^|[\s(|>])\*([^*\s](?:[^*\n]*[^*\s])?)\*/gm, "$1**$2**")
      .replace(/(^|[\s(|])-([^-\s](?:[^-\n]*[^-\s])?)-(?=$|[\s|).,;:!?])/gm, "$1~~$2~~")
      .replace(/(^|[\s(|])\+([^+\s](?:[^+\n]*[^+\s])?)\+(?=$|[\s|).,;:!?])/gm, "$1<ins>$2</ins>")
      // horizontal rules
      .replace(/^-{4,}\s*$/gm, "---");

    return text.replace(/\u0000J2M(\d+)\u0000/g, (_, i) => stash[Number(i)]);
  }

  window.JiraMarkup = { shouldConvert, toMarkdown };
})();
