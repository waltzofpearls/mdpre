//
//  SidebarView.swift
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
            Text(fileURL.lastPathComponent)
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
        guard filePath != folderPath else { return "./" }
        let prefix = folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
        guard filePath.hasPrefix(prefix) else { return "./" }
        return "./" + String(filePath.dropFirst(prefix.count)) + "/"
    }
}
