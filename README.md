<p align="center">
  <img src="docs/icon.png" alt="MDPre: Markdown Preview" width="128">
</p>

# MDPre: Markdown Preview

A macOS markdown preview app built for developers, with light editing, text to speech, AI cost estimation, and live reload.

**Single file preview**

<img src="docs/preview.png" alt="Single file preview">

**Editing with formatting toolbar**

<img src="docs/edit.png" alt="Editor with formatting toolbar">

**Side-by-side editor and preview**

<img src="docs/split.png" alt="Split view with editor and preview">

**Text to speech with the current word highlighted**

<img src="docs/speech.png" alt="Text to speech following along word by word">

**Folder mode with sidebar**

<img src="docs/folder-mode.png" alt="Folder mode with sidebar">

**Dark mode**

<img src="docs/dark-mode.png" alt="Single file preview in dark mode">

## Features

- **GitHub Flavored Markdown** rendered with [marked](https://github.com/markedjs/marked) and [github-markdown-css](https://github.com/sindresorhus/github-markdown-css), with syntax highlighting via [highlight.js](https://highlightjs.org/)
- **Text to speech** with the current word highlighted as it reads, plus play, pause, skip, a draggable progress bar, adjustable speed, and voice selection per language
- **Live reload** that automatically refreshes when files are edited in an external editor (vim, VS Code, etc.)
- **CLI tool** to open files and folders from the terminal with `mdp`
- **Folder mode** to browse a directory of Markdown files with a sidebar, similar to Preview.app
- **Light editing** with a [CodeMirror 6](https://codemirror.net/) editor, syntax highlighting, and a formatting toolbar for bold, italic, headings, lists, links, images, tables, and code blocks
- **Side by side view** with editor and preview, synchronized scrolling
- **Manual save** with Cmd+S, and an unsaved changes prompt when closing or switching files
- **Find in document** with live highlighting and match navigation (Cmd+F), in preview and editor
- **Table of contents** to jump to any section from the toolbar dropdown
- **Export** as PDF (Cmd+E), HTML (Cmd+Shift+E), or print (Cmd+P)
- **Internal link navigation** between Markdown documents via relative links
- **Relative image loading** for images referenced with relative paths
- **Appearance** switching between Light, Dark, and System from the toolbar
- **Pinch to zoom** to scale content with trackpad gestures
- **Document stats** showing word count, character count, token count, and estimated AI processing cost
- **Automatic updates** via Sparkle for update checking and installation

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+F | Find in document |
| Cmd+S | Save |
| Cmd+B | Bold (in editor) |
| Cmd+I | Italic (in editor) |
| Cmd+K | Link (in editor) |
| Cmd+E | Export as PDF |
| Cmd+Shift+E | Export as HTML |
| Cmd+P | Print |
| Cmd+Shift+O | Open folder |

## Install

**Mac App Store:** [MDPre: Markdown Preview](https://apps.apple.com/app/id6766780905)

**Direct download:** Download the latest DMG from [GitHub Releases](https://github.com/waltzofpearls/mdpre/releases), open it, and drag Markdown Preview to your Applications folder. The direct download version checks for updates automatically via Sparkle.

## Requirements

- macOS 15.7 or later
- Xcode 26 or later to build from source, since the app icon uses the Icon Composer format

## Build

```sh
git clone https://github.com/waltzofpearls/mdpre.git
cd mdpre
open MDPre.xcodeproj
```

Then build and run in Xcode (Cmd+R).

### Release Build

To build a signed and notarized DMG for distribution:

```sh
APPLE_PASSWORD=your-app-specific-password make build
```

This runs: xcodebuild, gon sign, create-dmg, gon notarize. See the [Makefile](Makefile) for details.

## CLI Tool

Markdown Preview bundles a command line tool called `mdp`.

### Usage

```sh
mdp README.md          # preview a single file
mdp ./docs/            # preview a folder with sidebar
mdp file1.md file2.md  # open multiple files
mdp --help             # show usage
mdp --version          # show the version
```

### Installing

From the app menu: **Markdown Preview > Install Command Line Tool...**

Or manually create a symlink:

```sh
sudo ln -sf /Applications/Markdown\ Preview.app/Contents/MacOS/mdp /usr/local/bin/mdp
```

### Mac App Store Limitation

In the Mac App Store build, `mdp` is sandboxed and cannot pass file access to the
app, so the first time you open something from a folder, Markdown Preview asks for
permission to read that folder. Grant it once and files in that folder open without
prompting afterwards. The direct download build never prompts.

## AI Cost Estimation

<img src="docs/ai-cost.png" alt="Estimated input cost across models">

The status bar shows word count, character count, estimated token count, and AI processing cost.
Click the cost amount to see a breakdown across several popular language models.
Token counting uses a BPE tokenizer (o200k_base) bundled in the app. No network calls required.

## License

[Apache 2.0](LICENSE)
