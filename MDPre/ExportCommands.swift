//
//  ExportCommands.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import SwiftUI

struct ExportHandlerKey: FocusedValueKey {
    typealias Value = ExportHandler
}

extension FocusedValues {
    var exportHandler: ExportHandler? {
        get { self[ExportHandlerKey.self] }
        set { self[ExportHandlerKey.self] = newValue }
    }
}

struct ExportCommands: Commands {
    @FocusedValue(\.exportHandler) var exportHandler

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Divider()

            Button("Export as PDF...") {
                exportHandler?.exportPDF()
            }
            .keyboardShortcut("e", modifiers: [.command])
            .disabled(exportHandler == nil)

            Button("Export as HTML...") {
                exportHandler?.exportHTML()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(exportHandler == nil)
        }

        CommandGroup(replacing: .printItem) {
            Button("Print...") {
                exportHandler?.printDocument()
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(exportHandler == nil)
        }
    }
}
