//
//  MDPreApp.swift
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

#if !APP_STORE
import Sparkle
#endif
import SwiftUI

@main
struct MDPreApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    #if !APP_STORE
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )
    #endif

    var body: some Scene {
        DocumentGroup(newDocument: MDPreDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .defaultSize(width: 980, height: 760)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Markdown Preview") {
                    var gregorianCalendar = Calendar(identifier: .gregorian)
                    gregorianCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
                    let year = gregorianCalendar.component(.year, from: Date())
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "MDPre: Markdown Preview",
                        NSApplication.AboutPanelOptionKey(rawValue: "Copyright"):
                            "Copyright \(year) Rollie Ma (Ruo-Lei Ma) rollie@rollie.dev",
                    ])
                }
            }
            #if !APP_STORE
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updaterController.checkForUpdates(nil)
                }
            }
            #endif
            CommandGroup(after: .newItem) {
                Button("Open Folder...") {
                    appDelegate.openFolderPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            AppearanceCommands()
            ExportCommands()
            FindCommands()
            CLICommands()
        }
    }
}
