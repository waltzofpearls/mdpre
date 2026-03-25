//
//  MDPreDocument.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import SwiftUI
import UniformTypeIdentifiers

nonisolated extension UTType {
    static let markdown = UTType("net.daringfireball.markdown")!
}

nonisolated struct MDPreDocument: FileDocument {
    var text: String

    static let readableContentTypes: [UTType] = [.markdown, .plainText]
    static let writableContentTypes: [UTType] = []

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}
