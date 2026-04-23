//
//  ContentView.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import Foundation
import SwiftUI
import WebKit

struct ContentView: View {
    @Binding var document: MDPreDocument
    var fileURL: URL?
    @State private var exportHandler: ExportHandler?
    @State private var renderID = 0
    @State private var hasCheckedAccess = false
    @State private var displayText = ""
    @State private var fileWatcher: FileWatcher?
    @State private var showFindBar = false
    @State private var viewMode: ViewMode = .preview
    @State private var scrollPercent: Double = 0
    @State private var stats: DocumentStats = .empty

    var body: some View {
        VStack(spacing: 0) {
            if showFindBar {
                FindBar(isVisible: $showFindBar)
            }
            switch viewMode {
            case .preview:
                markdownPreview
            case .source:
                SourceWebView(
                    markdown: displayText,
                    initialScrollPercent: scrollPercent,
                    onScrollSync: { percent in
                        scrollPercent = percent
                    }
                )
            case .split:
                HSplitView {
                    SourceWebView(
                        markdown: displayText,
                        initialScrollPercent: scrollPercent,
                        onScrollSync: { percent in
                            scrollPercent = percent
                            syncScroll(percent: percent, fromSource: true)
                        }
                    )
                    .frame(minWidth: 200)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Color(nsColor: .separatorColor))
                            .frame(width: 1)
                    }
                    markdownPreview
                        .frame(minWidth: 200)
                }
            }
            StatusBarView(stats: stats)
        }
        .frame(minWidth: 700, idealWidth: 980, minHeight: 500, idealHeight: 700)
        .onAppear {
            displayText = document.text
            exportHandler = ExportHandler(markdown: displayText)
            checkFolderAccessIfNeeded()
            startFileWatcher()
            stats = DocumentStats.compute(from: displayText)
        }
        .onDisappear {
            fileWatcher?.stopWatching()
            fileWatcher = nil
        }
        .onChange(of: document.text) { _, newValue in
            displayText = newValue
        }
        .onChange(of: displayText) { _, newValue in
            exportHandler?.markdown = newValue
            checkFolderAccessIfNeeded()
            stats = DocumentStats.compute(from: newValue)
        }
        .focusedSceneValue(\.exportHandler, exportHandler)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                ViewModeToolbarButton(viewMode: $viewMode)
            }
            ToolbarItem(placement: .automatic) {
                TableOfContentsToolbarButton()
                    .disabled(viewMode != .preview)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleFindBar)) { _ in
            showFindBar.toggle()
        }
    }

    private var markdownPreview: some View {
        MarkdownWebView(
            markdown: displayText,
            sourceFileURL: fileURL,
            exportHandler: exportHandler,
            onNavigateToFile: { url in
                NSDocumentController.shared.openDocument(
                    withContentsOf: url, display: true
                ) { _, _, _ in }
            },
            initialScrollPercent: scrollPercent,
            onScrollSync: { percent in
                scrollPercent = percent
                if viewMode == .split {
                    syncScroll(percent: percent, fromSource: false)
                }
            }
        )
        .id(renderID)
    }

    private func syncScroll(percent: Double, fromSource: Bool) {
        guard let window = NSApp.keyWindow,
              let contentView = window.contentView else { return }
        let webViews = findAllWebViews(in: contentView)
        guard webViews.count >= 2 else { return }
        // Source is first in the HSplitView, preview is second
        let targetWebView = fromSource ? webViews[1] : webViews[0]
        targetWebView.evaluateJavaScript("scrollToPercent(\(percent))")
    }

    private func findAllWebViews(in view: NSView) -> [WKWebView] {
        var results: [WKWebView] = []
        if let wv = view as? WKWebView { results.append(wv) }
        for subview in view.subviews {
            results.append(contentsOf: findAllWebViews(in: subview))
        }
        return results
    }

    private func checkFolderAccessIfNeeded() {
        guard !hasCheckedAccess else { return }
        guard let fileURL else { return }
        guard !displayText.isEmpty else { return }
        guard Self.hasLocalImages(in: displayText) else {
            hasCheckedAccess = true
            return
        }

        hasCheckedAccess = true
        let directory = fileURL.deletingLastPathComponent()

        if FolderAccessManager.shared.startAccessing(directory: directory) { return }

        // Defer to next run loop tick — calling runModal() during SwiftUI's
        // onAppear/onChange blocks the view update cycle and the alert never appears.
        DispatchQueue.main.async {
            FolderAccessManager.shared.requestAccess(for: directory) { granted in
                if granted {
                    renderID += 1
                }
            }
        }
    }

    private func startFileWatcher() {
        fileWatcher?.stopWatching()
        fileWatcher = nil
        guard let fileURL else { return }
        fileWatcher = FileWatcher(url: fileURL) { newContent in
            displayText = newContent
        }
    }

    private static func hasLocalImages(in text: String) -> Bool {
        let patterns: [(String, NSRegularExpression.Options)] = [
            (#"!\[[^\]]*\]\(([^)\s]+)"#, []),
            (#"<img[^>]*\ssrc\s*=\s*["']([^"']+)["']"#, [.caseInsensitive]),
        ]
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        for (pattern, options) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { continue }
            for match in regex.matches(in: text, range: fullRange) {
                guard match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound else { continue }
                let src = nsText.substring(with: match.range(at: 1))
                if !src.hasPrefix("http://") && !src.hasPrefix("https://") && !src.hasPrefix("data:") {
                    return true
                }
            }
        }
        return false
    }
}

#Preview {
    ContentView(document: .constant(MDPreDocument()))
}
