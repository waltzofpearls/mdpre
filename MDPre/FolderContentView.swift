//
//  FolderContentView.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import SwiftUI

struct FolderContentView: View {
    var viewModel: FolderViewModel
    @State private var exportHandler: ExportHandler?

    var body: some View {
        Group {
            if viewModel.selectedFile != nil {
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
                    }
                )
            } else {
                ContentUnavailableView(
                    "No File Selected",
                    systemImage: "doc.text",
                    description: Text("Select a markdown file from the sidebar.")
                )
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
        }
        .focusedSceneValue(\.exportHandler, exportHandler)
    }
}
