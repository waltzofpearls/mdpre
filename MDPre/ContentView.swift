//
//  ContentView.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @Binding var document: MDPreDocument
    var fileURL: URL?
    @State private var exportHandler: ExportHandler?
    @State private var renderID = 0
    @State private var hasCheckedAccess = false

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
            .id(renderID)
            .frame(minWidth: 700, idealWidth: 980, minHeight: 500, idealHeight: 700)
            .onAppear {
                exportHandler = ExportHandler(markdown: document.text)
                checkFolderAccessIfNeeded()
            }
            .onChange(of: document.text) { _, newValue in
                exportHandler?.markdown = newValue
                checkFolderAccessIfNeeded()
            }
            .focusedSceneValue(\.exportHandler, exportHandler)
    }

    private func checkFolderAccessIfNeeded() {
        guard !hasCheckedAccess else { return }
        guard let fileURL else { return }
        guard !document.text.isEmpty else { return }
        guard Self.hasLocalImages(in: document.text) else {
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
