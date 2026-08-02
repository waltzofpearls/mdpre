//
//  CLICommands.swift
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

/// Tracks whether the `mdp` symlink exists, so the menu item can switch between
/// Install and Uninstall without relaunching the app. `CLIInstaller.isInstalled`
/// on its own is a plain computed property that SwiftUI cannot observe.
@Observable
final class CLIInstallState {
    static let shared = CLIInstallState()

    var isInstalled = CLIInstaller.isInstalled

    func refresh() {
        isInstalled = CLIInstaller.isInstalled
    }
}

struct CLICommands: Commands {
    @State private var state = CLIInstallState.shared

    var body: some Commands {
        CommandGroup(after: .appSettings) {
            if state.isInstalled {
                Button("Uninstall Command Line Tool...") {
                    CLIInstaller.uninstall()
                    state.refresh()
                }
            } else {
                Button("Install Command Line Tool...") {
                    CLIInstaller.install()
                    state.refresh()
                }
            }
        }
    }
}
