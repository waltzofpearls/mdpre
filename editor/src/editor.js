import { EditorView, keymap, lineNumbers, highlightActiveLine, highlightActiveLineGutter, drawSelection, rectangularSelection, highlightSpecialChars, Decoration } from "@codemirror/view";
import { EditorState, Compartment, Transaction, StateEffect, StateField } from "@codemirror/state";
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands";
import { markdown, markdownLanguage } from "@codemirror/lang-markdown";
import { languages } from "@codemirror/language-data";
import { syntaxHighlighting, defaultHighlightStyle, indentOnInput, bracketMatching, HighlightStyle } from "@codemirror/language";
import { closeBrackets, closeBracketsKeymap } from "@codemirror/autocomplete";
import { highlightSelectionMatches, SearchCursor } from "@codemirror/search";
import { tags } from "@lezer/highlight";

// --- Theme ---

const lightTheme = EditorView.theme({
  "&": { height: "100%", fontSize: "13px" },
  ".cm-scroller": { fontFamily: "ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, monospace", overflow: "auto" },
  ".cm-content": { padding: "24px 0" },
  ".cm-line": { padding: "0 24px" },
  ".cm-gutters": { backgroundColor: "transparent", borderRight: "none", paddingLeft: "8px" },
  ".cm-activeLineGutter": { backgroundColor: "transparent" },
  ".cm-find-match": { backgroundColor: "#fff3aa", borderRadius: "2px" },
  ".cm-find-current": { backgroundColor: "#f9a825", borderRadius: "2px" },
}, { dark: false });

const darkTheme = EditorView.theme({
  "&": { height: "100%", fontSize: "13px", backgroundColor: "#1e1e1e", color: "#d4d4d4" },
  ".cm-scroller": { fontFamily: "ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, monospace", overflow: "auto" },
  ".cm-content": { padding: "24px 0", caretColor: "#d4d4d4" },
  ".cm-line": { padding: "0 24px" },
  ".cm-cursor": { borderLeftColor: "#d4d4d4" },
  ".cm-gutters": { backgroundColor: "transparent", color: "#858585", borderRight: "none", paddingLeft: "8px" },
  ".cm-activeLine": { backgroundColor: "#ffffff0a" },
  ".cm-activeLineGutter": { backgroundColor: "transparent", color: "#c6c6c6" },
  ".cm-selectionBackground": { backgroundColor: "#264f78 !important" },
  "&.cm-focused .cm-selectionBackground": { backgroundColor: "#264f78 !important" },
  ".cm-matchingBracket": { backgroundColor: "#0064001a", outline: "1px solid #888" },
  ".cm-find-match": { backgroundColor: "#5a4a00", borderRadius: "2px" },
  ".cm-find-current": { backgroundColor: "#e2c033", color: "#000", borderRadius: "2px" },
}, { dark: true });

const darkHighlight = HighlightStyle.define([
  { tag: tags.heading, color: "#569cd6", fontWeight: "bold" },
  { tag: tags.emphasis, color: "#c586c0", fontStyle: "italic" },
  { tag: tags.strong, color: "#4ec9b0", fontWeight: "bold" },
  { tag: tags.keyword, color: "#569cd6" },
  { tag: tags.atom, color: "#569cd6" },
  { tag: tags.bool, color: "#569cd6" },
  { tag: tags.url, color: "#3794ff", textDecoration: "underline" },
  { tag: tags.link, color: "#3794ff" },
  { tag: tags.string, color: "#ce9178" },
  { tag: tags.meta, color: "#569cd6" },
  { tag: tags.comment, color: "#6a9955" },
  { tag: tags.monospace, color: "#d7ba7d" },
  { tag: tags.strikethrough, textDecoration: "line-through" },
  { tag: tags.processingInstruction, color: "#808080" },
  { tag: tags.quote, color: "#6a9955", fontStyle: "italic" },
  { tag: tags.contentSeparator, color: "#808080" },
]);

const themeCompartment = new Compartment();
const highlightCompartment = new Compartment();

// --- Find highlight decorations ---

const highlightEffect = StateEffect.define();

const findHighlightField = StateField.define({
  create() { return Decoration.none; },
  update(value, tr) {
    for (const e of tr.effects) {
      if (e.is(highlightEffect)) return e.value;
    }
    return value.map(tr.changes);
  },
  provide: f => EditorView.decorations.from(f),
});

function getThemeExtensions(isDark) {
  return {
    theme: isDark ? darkTheme : lightTheme,
    highlight: isDark ? syntaxHighlighting(darkHighlight) : syntaxHighlighting(defaultHighlightStyle),
  };
}

// --- Editor setup ---

let editor = null;
let changeDebounceTimer = null;
let ignoreNextUpdate = false;
let ignoreNextScroll = false;

export function initEditor(container) {
  const isDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  const themeExts = getThemeExtensions(isDark);

  editor = new EditorView({
    state: EditorState.create({
      doc: "",
      extensions: [
        lineNumbers(),
        highlightActiveLineGutter(),
        highlightSpecialChars(),
        history(),
        drawSelection(),
        EditorState.allowMultipleSelections.of(true),
        indentOnInput(),
        bracketMatching(),
        closeBrackets(),
        rectangularSelection(),
        highlightActiveLine(),
        highlightSelectionMatches(),
        keymap.of([
          { key: "Mod-b", run: () => { formatBold(); return true; } },
          { key: "Mod-i", run: () => { formatItalic(); return true; } },
          { key: "Mod-k", run: () => { formatLink(); return true; } },
          { key: "Mod-f", run: () => {
            if (window.webkit?.messageHandlers?.toggleFind) {
              window.webkit.messageHandlers.toggleFind.postMessage(true);
            }
            return true;
          }},
          ...closeBracketsKeymap,
          ...defaultKeymap,
          ...historyKeymap,
          indentWithTab,
        ]),
        markdown({ base: markdownLanguage, codeLanguages: languages }),
        themeCompartment.of(themeExts.theme),
        highlightCompartment.of(themeExts.highlight),
        EditorView.lineWrapping,
        findHighlightField,
        EditorView.updateListener.of((update) => {
          if (update.docChanged && !ignoreNextUpdate) {
            clearTimeout(changeDebounceTimer);
            changeDebounceTimer = setTimeout(() => {
              const content = editor.state.doc.toString();
              if (window.webkit?.messageHandlers?.editorChange) {
                window.webkit.messageHandlers.editorChange.postMessage(content);
              }
            }, 300);
          }
          if (update.docChanged) {
            ignoreNextUpdate = false;
          }
        }),
        EditorView.domEventHandlers({
          scroll() {
            if (ignoreNextScroll) {
              ignoreNextScroll = false;
              return;
            }
            const percent = getScrollPercent();
            if (window.webkit?.messageHandlers?.scrollSync) {
              window.webkit.messageHandlers.scrollSync.postMessage(percent);
            }
          },
        }),
      ],
    }),
    parent: container,
  });

  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
    const exts = getThemeExtensions(e.matches);
    editor.dispatch({
      effects: [
        themeCompartment.reconfigure(exts.theme),
        highlightCompartment.reconfigure(exts.highlight),
      ],
    });
  });
}

// --- Content API ---

export function setContent(text) {
  if (!editor) return;
  const current = editor.state.doc.toString();
  if (current === text) return;
  ignoreNextUpdate = true;
  editor.dispatch({
    changes: { from: 0, to: editor.state.doc.length, insert: text },
    annotations: Transaction.addToHistory.of(false),
  });
}

export function getContent() {
  return editor ? editor.state.doc.toString() : "";
}

// --- Scroll sync ---

function getScrollPercent() {
  if (!editor) return 0;
  const scroller = editor.scrollDOM;
  const scrollHeight = scroller.scrollHeight - scroller.clientHeight;
  if (scrollHeight <= 0) return 0;
  return scroller.scrollTop / scrollHeight;
}

export function scrollToPercent(percent) {
  if (!editor) return;
  ignoreNextScroll = true;
  const scroller = editor.scrollDOM;
  const scrollHeight = scroller.scrollHeight - scroller.clientHeight;
  scroller.scrollTop = percent * scrollHeight;
}

// --- Formatting helpers ---

function wrapSelection(before, after) {
  if (!editor) return;
  const { from, to } = editor.state.selection.main;
  const selected = editor.state.sliceDoc(from, to);

  if (selected.startsWith(before) && selected.endsWith(after)) {
    editor.dispatch({
      changes: { from, to, insert: selected.slice(before.length, -after.length || undefined) },
      selection: { anchor: from, head: from + selected.length - before.length - after.length },
    });
  } else {
    const insert = before + selected + after;
    editor.dispatch({
      changes: { from, to, insert },
      selection: { anchor: from + before.length, head: from + before.length + selected.length },
    });
  }
  editor.focus();
}

function prefixLines(prefix) {
  if (!editor) return;
  const { from, to } = editor.state.selection.main;
  const startLine = editor.state.doc.lineAt(from);
  const endLine = editor.state.doc.lineAt(to);

  const changes = [];
  let allPrefixed = true;
  for (let i = startLine.number; i <= endLine.number; i++) {
    const line = editor.state.doc.line(i);
    if (!line.text.startsWith(prefix)) {
      allPrefixed = false;
      break;
    }
  }

  for (let i = startLine.number; i <= endLine.number; i++) {
    const line = editor.state.doc.line(i);
    if (allPrefixed) {
      changes.push({ from: line.from, to: line.from + prefix.length, insert: "" });
    } else {
      changes.push({ from: line.from, to: line.from, insert: prefix });
    }
  }

  editor.dispatch({ changes });
  editor.focus();
}

function prefixLinesNumbered() {
  if (!editor) return;
  const { from, to } = editor.state.selection.main;
  const startLine = editor.state.doc.lineAt(from);
  const endLine = editor.state.doc.lineAt(to);

  const changes = [];
  const numbered = /^\d+\.\s/.test(editor.state.doc.line(startLine.number).text);

  for (let i = startLine.number; i <= endLine.number; i++) {
    const line = editor.state.doc.line(i);
    if (numbered) {
      const match = line.text.match(/^\d+\.\s/);
      if (match) {
        changes.push({ from: line.from, to: line.from + match[0].length, insert: "" });
      }
    } else {
      const num = i - startLine.number + 1;
      changes.push({ from: line.from, to: line.from, insert: `${num}. ` });
    }
  }

  editor.dispatch({ changes });
  editor.focus();
}

// --- Formatting API ---

export function formatBold() { wrapSelection("**", "**"); }
export function formatItalic() { wrapSelection("_", "_"); }
export function formatStrikethrough() { wrapSelection("~~", "~~"); }
export function formatCode() { wrapSelection("`", "`"); }

export function formatCodeBlock() {
  if (!editor) return;
  const { from, to } = editor.state.selection.main;
  const selected = editor.state.sliceDoc(from, to);
  const insert = "```\n" + selected + "\n```";
  editor.dispatch({
    changes: { from, to, insert },
    selection: { anchor: from + 4, head: from + 4 + selected.length },
  });
  editor.focus();
}

export function formatHeading(level) {
  const prefix = "#".repeat(level) + " ";
  if (!editor) return;
  const { from } = editor.state.selection.main;
  const line = editor.state.doc.lineAt(from);
  const match = line.text.match(/^#{1,6}\s/);
  if (match) {
    editor.dispatch({
      changes: { from: line.from, to: line.from + match[0].length, insert: prefix },
    });
  } else {
    editor.dispatch({
      changes: { from: line.from, to: line.from, insert: prefix },
    });
  }
  editor.focus();
}

export function formatUnorderedList() { prefixLines("- "); }
export function formatOrderedList() { prefixLinesNumbered(); }
export function formatBlockquote() { prefixLines("> "); }

export function formatHorizontalRule() {
  if (!editor) return;
  const { from } = editor.state.selection.main;
  const line = editor.state.doc.lineAt(from);
  const insert = line.from === 0 ? "---\n" : "\n---\n";
  editor.dispatch({
    changes: { from: line.to, to: line.to, insert },
  });
  editor.focus();
}

export function formatLink() {
  if (!editor) return;
  const { from, to } = editor.state.selection.main;
  const selected = editor.state.sliceDoc(from, to);
  const insert = `[${selected || "text"}](url)`;
  editor.dispatch({
    changes: { from, to, insert },
    selection: { anchor: from + 1, head: from + 1 + (selected.length || 4) },
  });
  editor.focus();
}

export function formatImage() {
  if (!editor) return;
  const { from, to } = editor.state.selection.main;
  const selected = editor.state.sliceDoc(from, to);
  const insert = `![${selected || "alt"}](url)`;
  editor.dispatch({
    changes: { from, to, insert },
    selection: { anchor: from + 2, head: from + 2 + (selected.length || 3) },
  });
  editor.focus();
}

export function formatTable() {
  if (!editor) return;
  const { from } = editor.state.selection.main;
  const line = editor.state.doc.lineAt(from);
  const table = "\n| Column 1 | Column 2 | Column 3 |\n|----------|----------|----------|\n| Cell 1   | Cell 2   | Cell 3   |\n";
  editor.dispatch({
    changes: { from: line.to, to: line.to, insert: table },
  });
  editor.focus();
}

// --- Find support ---

let findMatchPositions = [];
let findCurrentIndex = -1;

const matchDecoration = Decoration.mark({ class: "cm-find-match" });
const currentDecoration = Decoration.mark({ class: "cm-find-current" });

function highlightMatches() {
  if (!editor) return;
  const decorations = findMatchPositions.map((m, i) =>
    (i === findCurrentIndex ? currentDecoration : matchDecoration).range(m.from, m.to)
  );
  editor.dispatch({ effects: highlightEffect.of(Decoration.set(decorations, true)) });
}

function scrollToMatch() {
  if (!editor || findCurrentIndex < 0) return;
  const pos = findMatchPositions[findCurrentIndex];
  editor.dispatch({
    selection: { anchor: pos.from, head: pos.to },
    scrollIntoView: true,
  });
}

export function findInPage(query) {
  clearFind();
  if (!editor || !query) return JSON.stringify({ total: 0, current: 0 });

  const cursor = new SearchCursor(editor.state.doc, query, 0, editor.state.doc.length, s => s.toLowerCase());
  while (!cursor.next().done) {
    findMatchPositions.push({ from: cursor.value.from, to: cursor.value.to });
  }

  if (findMatchPositions.length > 0) {
    findCurrentIndex = 0;
    highlightMatches();
    scrollToMatch();
  }

  return JSON.stringify({ total: findMatchPositions.length, current: findMatchPositions.length > 0 ? 1 : 0 });
}

export function findNext() {
  if (!findMatchPositions.length) return JSON.stringify({ total: 0, current: 0 });
  findCurrentIndex = (findCurrentIndex + 1) % findMatchPositions.length;
  highlightMatches();
  scrollToMatch();
  return JSON.stringify({ total: findMatchPositions.length, current: findCurrentIndex + 1 });
}

export function findPrevious() {
  if (!findMatchPositions.length) return JSON.stringify({ total: 0, current: 0 });
  findCurrentIndex = (findCurrentIndex - 1 + findMatchPositions.length) % findMatchPositions.length;
  highlightMatches();
  scrollToMatch();
  return JSON.stringify({ total: findMatchPositions.length, current: findCurrentIndex + 1 });
}

export function clearFind() {
  if (editor) {
    editor.dispatch({ effects: highlightEffect.of(Decoration.none) });
  }
  findMatchPositions = [];
  findCurrentIndex = -1;
}
