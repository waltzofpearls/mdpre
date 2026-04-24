//
//  FolderContentView.swift
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

struct FolderContentView: View {
    @Bindable var viewModel: FolderViewModel
    @State private var exportHandler: ExportHandler?
    @State private var scrollPercent: Double = 0
    @State private var stats: DocumentStats = .empty

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showFindBar {
                FindBar(isVisible: $viewModel.showFindBar)
            }
            Group {
                if viewModel.selectedFile != nil {
                    switch viewModel.viewMode {
                    case .preview:
                        markdownPreview
                    case .source:
                        SourceWebView(
                            markdown: viewModel.selectedFileContent,
                            initialScrollPercent: scrollPercent,
                            onScrollSync: { percent in
                                scrollPercent = percent
                            }
                        )
                    case .split:
                        HSplitView {
                            SourceWebView(
                                markdown: viewModel.selectedFileContent,
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
                } else {
                    ContentUnavailableView(
                        "No File Selected",
                        systemImage: "doc.text",
                        description: Text("Select a markdown file from the sidebar.")
                    )
                }
            }
            StatusBarView(stats: stats)
        }
        .onAppear {
            exportHandler = ExportHandler(markdown: viewModel.selectedFileContent)
            viewModel.updateWindowTitle()
            stats = DocumentStats.compute(from: viewModel.selectedFileContent)
        }
        .onChange(of: viewModel.selectedFileContent) { _, newValue in
            exportHandler?.markdown = newValue
            stats = DocumentStats.compute(from: newValue)
        }
        .onChange(of: viewModel.selectedFile) { _, _ in
            viewModel.updateWindowTitle()
            viewModel.viewMode = .preview
            scrollPercent = 0
            // Reset toolbar to match preview mode
            if let toolbar = viewModel.window?.toolbar {
                if let segmented = toolbar.items.first(where: { $0.itemIdentifier == .viewMode })?.view as? NSSegmentedControl {
                    segmented.selectedSegment = 0
                }
                if let tocItem = toolbar.items.first(where: { $0.itemIdentifier == .tableOfContents }) {
                    tocItem.isEnabled = true
                }
            }
        }
        .focusedSceneValue(\.exportHandler, exportHandler)
    }

    private var markdownPreview: some View {
        MarkdownWebView(
            markdown: viewModel.selectedFileContent,
            sourceFileURL: viewModel.selectedFile,
            exportHandler: exportHandler,
            fullWidth: true,
            onNavigateToFile: { url in
                if viewModel.files.contains(url) {
                    viewModel.selectedFile = url
                } else {
                    NSDocumentController.shared.openDocument(
                        withContentsOf: url, display: true
                    ) { _, _, _ in }
                }
            },
            initialScrollPercent: scrollPercent,
            onScrollSync: { percent in
                scrollPercent = percent
                if viewModel.viewMode == .split {
                    syncScroll(percent: percent, fromSource: false)
                }
            }
        )
    }

    private func syncScroll(percent: Double, fromSource: Bool) {
        guard let window = viewModel.window,
              let contentView = window.contentView else { return }
        let webViews = findAllWebViews(in: contentView)
        guard webViews.count >= 2 else { return }
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
}
