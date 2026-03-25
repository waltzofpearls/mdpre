//
//  MarkdownWebView.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    var sourceFileURL: URL?
    var exportHandler: ExportHandler?
    var fullWidth: Bool = false
    var onNavigateToFile: ((URL) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.autoresizingMask = [.width, .height]

        if let templateURL = Bundle.main.url(forResource: "template", withExtension: "html") {
            webView.loadFileURL(templateURL, allowingReadAccessTo: templateURL.deletingLastPathComponent())
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        exportHandler?.webView = webView

        if context.coordinator.isLoaded {
            let fragment = context.coordinator.pendingFragment
            context.coordinator.pendingFragment = nil
            renderMarkdown(in: webView, thenScrollTo: fragment)
        } else {
            context.coordinator.pendingMarkdown = markdown
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private var baseURLJS: String {
        guard let sourceFile = sourceFileURL else { return "" }
        return sourceFile.deletingLastPathComponent().absoluteString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
    }

    private func renderMarkdown(in webView: WKWebView, thenScrollTo fragment: String? = nil) {
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        webView.evaluateJavaScript("renderMarkdown(`\(escaped)`, `\(baseURLJS)`)") { _, _ in
            if let fragment {
                let safeFragment = fragment.replacingOccurrences(of: "'", with: "\\'")
                webView.evaluateJavaScript("document.getElementById('\(safeFragment)')?.scrollIntoView()")
            }
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownWebView
        var isLoaded = false
        var pendingMarkdown: String?
        var pendingFragment: String?

        init(parent: MarkdownWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            if parent.fullWidth {
                webView.evaluateJavaScript("setFullWidth(true)")
            }
            if let markdown = pendingMarkdown {
                pendingMarkdown = nil
                let escaped = markdown
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "`", with: "\\`")
                    .replacingOccurrences(of: "${", with: "\\${")
                webView.evaluateJavaScript("renderMarkdown(`\(escaped)`, `\(parent.baseURLJS)`)")
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                // Anchor-only link — let the browser handle scrolling
                if url.fragment != nil, url.path == webView.url?.path {
                    return .allow
                }
                // Local file link (rewritten to mdpre-file:// to bypass WKWebView sandbox)
                if url.scheme == "mdpre-file" {
                    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    components?.scheme = "file"
                    let fragment = components?.fragment
                    components?.fragment = nil
                    if let fileURL = components?.url {
                        if FolderViewModel.isMarkdown(fileURL) {
                            pendingFragment = fragment
                            parent.onNavigateToFile?(fileURL)
                        } else {
                            NSWorkspace.shared.open(fileURL)
                        }
                    }
                    return .cancel
                }
                // Everything else — open externally
                NSWorkspace.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}
