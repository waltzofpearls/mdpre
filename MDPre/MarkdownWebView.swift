//
//  MarkdownWebView.swift
//  MDPre (Markdown Preview)
//
//  Copyright 2026 Rollie Ma (Ruo-Lei Ma) rollie@rollie.dev
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    var sourceFileURL: URL?
    var exportHandler: ExportHandler?
    var fullWidth: Bool = false
    var onNavigateToFile: ((URL) -> Void)?
    var initialScrollPercent: Double = 0
    var onScrollSync: ((Double) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let schemeHandler = LocalFileSchemeHandler()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "mdpre-res")
        config.userContentController.add(context.coordinator, name: "scrollSync")
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
            if markdown != context.coordinator.lastRenderedMarkdown {
                context.coordinator.lastRenderedMarkdown = markdown
                let fragment = context.coordinator.pendingFragment
                context.coordinator.pendingFragment = nil
                renderMarkdown(in: webView, thenScrollTo: fragment)
            }
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

    class LocalFileSchemeHandler: NSObject, WKURLSchemeHandler {
        func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
            guard let url = urlSchemeTask.request.url else {
                urlSchemeTask.didFailWithError(URLError(.badURL))
                return
            }
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = "file"
            guard let fileURL = components?.url else {
                urlSchemeTask.didFailWithError(URLError(.badURL))
                return
            }

            let directory = fileURL.deletingLastPathComponent()
            _ = FolderAccessManager.shared.startAccessing(directory: directory)

            guard let data = try? Data(contentsOf: fileURL) else {
                urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
                return
            }
            let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        }

        func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MarkdownWebView
        var isLoaded = false
        var pendingMarkdown: String?
        var pendingFragment: String?
        var lastRenderedMarkdown: String?

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
                lastRenderedMarkdown = markdown
                let escaped = markdown
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "`", with: "\\`")
                    .replacingOccurrences(of: "${", with: "\\${")
                webView.evaluateJavaScript("renderMarkdown(`\(escaped)`, `\(parent.baseURLJS)`)") { _, _ in
                    let percent = self.parent.initialScrollPercent
                    if percent > 0 {
                        webView.evaluateJavaScript("scrollToPercent(\(percent))")
                    }
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "scrollSync", let percent = message.body as? Double {
                parent.onScrollSync?(percent)
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
