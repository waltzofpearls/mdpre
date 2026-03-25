//
//  ContentView.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: MDPreDocument
    var fileURL: URL?
    @State private var exportHandler: ExportHandler?

    var body: some View {
        MarkdownWebView(
            markdown: document.text,
            sourceFileURL: fileURL,
            exportHandler: exportHandler,
            onNavigateToFile: { url in
                NSDocumentController.shared.openDocument(
                    withContentsOf: url, display: true
                ) { _, _, _ in }
            }
        )
            .frame(minWidth: 700, idealWidth: 980, minHeight: 500, idealHeight: 700)
            .onAppear {
                exportHandler = ExportHandler(markdown: document.text)
            }
            .onChange(of: document.text) { _, newValue in
                exportHandler?.markdown = newValue
            }
            .focusedSceneValue(\.exportHandler, exportHandler)
    }
}

#Preview {
    ContentView(document: .constant(MDPreDocument()))
}
