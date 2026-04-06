//
//  MDPreApp.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import SwiftUI

@main
struct MDPreApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        DocumentGroup(viewing: MDPreDocument.self) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .defaultSize(width: 980, height: 760)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Folder...") {
                    appDelegate.openFolderPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(after: .appSettings) {
                if CLIInstaller.isInstalled {
                    Button("Uninstall Command Line Tool...") {
                        CLIInstaller.uninstall()
                    }
                } else {
                    Button("Install Command Line Tool...") {
                        CLIInstaller.install()
                    }
                }
            }
            ExportCommands()
        }
    }
}
