# MDPre

A lightweight macOS markdown preview app with GitHub-style rendering.

## Features

- GitHub Flavored Markdown rendering with syntax highlighting
- Single file and folder viewing modes
- Folder mode with sidebar navigation (Preview.app-like)
- Internal markdown link navigation between documents
- Export as PDF, HTML, or print
- Pinch-to-zoom support
- Dark mode support
- Live directory monitoring for file changes

## CLI

MDPre includes a command-line tool `mdp` for quick previewing:

```sh
# Preview a single file
mdp README.md

# Preview all markdown files in a folder
mdp ./docs/
```

## Install

Build from source in Xcode. Requires macOS 15.7 or later.

The `mdp` CLI is bundled inside the app at `MDPre.app/Contents/MacOS/mdp`. Symlink it to your PATH:

```sh
ln -s /Applications/MDPre.app/Contents/MacOS/mdp /usr/local/bin/mdp
```

## License

MIT
