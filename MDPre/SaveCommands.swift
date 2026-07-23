//
//  SaveCommands.swift
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

struct SaveActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var saveAction: (() -> Void)? {
        get { self[SaveActionKey.self] }
        set { self[SaveActionKey.self] = newValue }
    }
}

struct SaveCommands: Commands {
    @FocusedValue(\.saveAction) var saveAction

    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                saveAction?()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(saveAction == nil)
        }
    }
}
