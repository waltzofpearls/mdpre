//
//  ExportCommands.swift
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
