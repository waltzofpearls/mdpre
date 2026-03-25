//
//  SidebarView.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: FolderViewModel

    var body: some View {
        List(viewModel.files, id: \.self, selection: $viewModel.selectedFile) { fileURL in
            SidebarRow(fileURL: fileURL, folderURL: viewModel.folderURL)
        }
        .onChange(of: viewModel.selectedFile) { _, newValue in
            if let newValue {
                viewModel.loadContent(for: newValue)
            }
        }
        .listStyle(.sidebar)
    }
}

struct SidebarRow: View {
    let fileURL: URL
    let folderURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fileURL.deletingPathExtension().lastPathComponent)
                .font(.body)
                .lineLimit(1)

            let relativePath = relativeDirectory()
            if !relativePath.isEmpty {
                Text(relativePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func relativeDirectory() -> String {
        let filePath = fileURL.deletingLastPathComponent().path
        let folderPath = folderURL.path
        guard filePath != folderPath else { return "" }
        let prefix = folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
        guard filePath.hasPrefix(prefix) else { return "" }
        return String(filePath.dropFirst(prefix.count))
    }
}
