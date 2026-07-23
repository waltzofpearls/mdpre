//
//  EditorWebView.swift
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
import WebKit

struct EditorWebView: NSViewRepresentable {
    let markdown: String
    var themeMode: ThemeMode = .system
    var initialScrollPercent: Double = 0
    var onContentChange: ((String) -> Void)?
    var onScrollSync: ((Double) -> Void)?
    var onWebViewReady: ((WKWebView) -> Void)?
    var onToggleFind: (() -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "editorChange")
        config.userContentController.add(context.coordinator, name: "scrollSync")
        config.userContentController.add(context.coordinator, name: "toggleFind")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        webView.autoresizingMask = [.width, .height]
        webView.appearance = themeMode.appearance

        if let templateURL = Bundle.main.url(forResource: "editor-template", withExtension: "html") {
            webView.loadFileURL(templateURL, allowingReadAccessTo: templateURL.deletingLastPathComponent())
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        webView.appearance = themeMode.appearance

        if context.coordinator.isLoaded {
            if markdown != context.coordinator.lastPushedContent {
                context.coordinator.lastPushedContent = markdown
                let escaped = markdown
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "`", with: "\\`")
                    .replacingOccurrences(of: "${", with: "\\${")
                webView.evaluateJavaScript("setContent(`\(escaped)`)")
            }
        } else {
            context.coordinator.pendingMarkdown = markdown
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: EditorWebView
        var isLoaded = false
        var pendingMarkdown: String?
        var lastPushedContent: String?

        init(parent: EditorWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            parent.onWebViewReady?(webView)
            if let markdown = pendingMarkdown {
                pendingMarkdown = nil
                lastPushedContent = markdown
                let escaped = markdown
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "`", with: "\\`")
                    .replacingOccurrences(of: "${", with: "\\${")
                webView.evaluateJavaScript("setContent(`\(escaped)`)") { _, _ in
                    let percent = self.parent.initialScrollPercent
                    if percent > 0 {
                        webView.evaluateJavaScript("scrollToPercent(\(percent))")
                    }
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "editorChange":
                if let content = message.body as? String {
                    lastPushedContent = content
                    parent.onContentChange?(content)
                }
            case "scrollSync":
                if let percent = message.body as? Double {
                    parent.onScrollSync?(percent)
                }
            case "toggleFind":
                parent.onToggleFind?()
            default:
                break
            }
        }
    }
}
