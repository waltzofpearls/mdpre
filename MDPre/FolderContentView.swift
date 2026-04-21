//
//  FolderContentView.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import SwiftUI
import WebKit

struct FolderContentView: View {
    @Bindable var viewModel: FolderViewModel
    @State private var exportHandler: ExportHandler?
    @State private var scrollPercent: Double = 0

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
        }
        .onAppear {
            exportHandler = ExportHandler(markdown: viewModel.selectedFileContent)
            viewModel.updateWindowTitle()
        }
        .onChange(of: viewModel.selectedFileContent) { _, newValue in
            exportHandler?.markdown = newValue
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
