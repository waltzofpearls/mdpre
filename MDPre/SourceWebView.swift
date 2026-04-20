//
//  SourceWebView.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-04-19.
//

import SwiftUI
import WebKit

struct SourceWebView: NSViewRepresentable {
    let markdown: String
    var initialScrollPercent: Double = 0
    var onScrollSync: ((Double) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "scrollSync")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.autoresizingMask = [.width, .height]

        if let templateURL = Bundle.main.url(forResource: "source-template", withExtension: "html") {
            webView.loadFileURL(templateURL, allowingReadAccessTo: templateURL.deletingLastPathComponent())
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.isLoaded {
            if markdown != context.coordinator.lastRenderedMarkdown {
                renderSource(in: webView, context: context)
            }
        } else {
            context.coordinator.pendingMarkdown = markdown
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func renderSource(in webView: WKWebView, context: Context) {
        context.coordinator.lastRenderedMarkdown = markdown
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        webView.evaluateJavaScript("renderSource(`\(escaped)`)")
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: SourceWebView
        var isLoaded = false
        var pendingMarkdown: String?
        var lastRenderedMarkdown: String?

        init(parent: SourceWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            if let markdown = pendingMarkdown {
                pendingMarkdown = nil
                lastRenderedMarkdown = markdown
                let escaped = markdown
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "`", with: "\\`")
                    .replacingOccurrences(of: "${", with: "\\${")
                webView.evaluateJavaScript("renderSource(`\(escaped)`)") { _, _ in
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
    }
}
