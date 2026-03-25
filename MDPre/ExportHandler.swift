//
//  ExportHandler.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import AppKit
import WebKit
import UniformTypeIdentifiers

@Observable
class ExportHandler {
    var markdown: String
    weak var webView: WKWebView?

    init(markdown: String) {
        self.markdown = markdown
    }

    func exportPDF() {
        guard let webView else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "document.pdf"
        panel.title = "Export as PDF"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let config = WKPDFConfiguration()
        webView.createPDF(configuration: config) { result in
            if case .success(let data) = result {
                try? data.write(to: url)
            }
        }
    }

    func exportHTML() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "document.html"
        panel.title = "Export as HTML"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let html = buildSelfContainedHTML()
        try? html.write(to: url, atomically: true, encoding: .utf8)
    }

    func printDocument() {
        guard let webView,
              let window = webView.window else { return }

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.orientation = .portrait
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36

        let printOp = webView.printOperation(with: printInfo)
        printOp.showsPrintPanel = true
        printOp.showsProgressPanel = true
        printOp.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    func buildSelfContainedHTML() -> String {
        let css = loadResource("github-markdown", ext: "css") ?? ""
        let highlightCSS = loadResource("highlight-github.min", ext: "css") ?? ""
        let highlightDarkCSS = loadResource("highlight-github-dark.min", ext: "css") ?? ""
        let markedJS = loadResource("marked.min", ext: "js") ?? ""
        let highlightJS = loadResource("highlight.min", ext: "js") ?? ""

        let escapedMarkdown = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>\(css)</style>
        <style media="(prefers-color-scheme: light)">\(highlightCSS)</style>
        <style media="(prefers-color-scheme: dark)">\(highlightDarkCSS)</style>
        <style>
            body { margin: 0; padding: 0; background-color: var(--bgColor-default); }
            .markdown-body {
                box-sizing: border-box;
                min-width: 200px;
                max-width: 980px;
                margin: 0 auto;
                padding: 45px;
            }
        </style>
        <script>\(markedJS)</script>
        <script>\(highlightJS)</script>
        </head>
        <body>
        <article class="markdown-body" id="content"></article>
        <script>
            marked.setOptions({
                gfm: true,
                breaks: false,
                highlight: function(code, lang) {
                    if (lang && hljs.getLanguage(lang)) {
                        return hljs.highlight(code, { language: lang }).value;
                    }
                    return hljs.highlightAuto(code).value;
                }
            });
            document.getElementById('content').innerHTML = marked.parse(`\(escapedMarkdown)`);
        </script>
        </body>
        </html>
        """
    }

    private func loadResource(_ name: String, ext: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
