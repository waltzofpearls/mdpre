//
//  CLIInstaller.swift
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

import AppKit

enum CLIInstaller {
    static let installPath = "/usr/local/bin/mdp"
    private static let installURL = URL(fileURLWithPath: installPath)
    private static let installDirURL = URL(fileURLWithPath: "/usr/local/bin")

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: installPath)
    }

    static var cliURL: URL? {
        Bundle.main.url(forAuxiliaryExecutable: "mdp")
    }

    // MARK: - Install

    static func install() {
        guard let source = cliURL else {
            showAlert(
                title: "CLI Tool Not Found",
                message: "The mdp binary was not found in the app bundle.",
                style: .warning
            )
            return
        }

        if installViaWorkspaceAuthorization(source: source) { return }

        showFallback(
            title: "Install Command Line Tool",
            message: "To install the 'mdp' command, copy and run this in Terminal.\n\nThis requires administrator privileges because /usr/local/bin is a system directory.",
            command: "sudo ln -sf '\(source.path)' '\(installPath)'"
        )
    }

    // MARK: - Uninstall

    static func uninstall() {
        showFallback(
            title: "Uninstall Command Line Tool",
            message: "To remove the 'mdp' command, copy and run this in Terminal.",
            command: "sudo rm -f '\(installPath)'"
        )
    }

    // MARK: - NSWorkspace authorization (requires privileged-file-operations entitlement)

    private static func installViaWorkspaceAuthorization(source: URL) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var succeeded = false

        NSWorkspace.shared.requestAuthorization(to: .createSymbolicLink) { auth, error in
            defer { semaphore.signal() }
            guard let auth else { return }

            let fm = FileManager(authorization: auth)
            do {
                if !FileManager.default.fileExists(atPath: installDirURL.path) {
                    try fm.createDirectory(at: installDirURL, withIntermediateDirectories: true)
                }
                if FileManager.default.fileExists(atPath: installPath) {
                    try fm.removeItem(at: installURL)
                }
                try fm.createSymbolicLink(at: installURL, withDestinationURL: source)
                succeeded = true
            } catch {}
        }

        semaphore.wait()

        if succeeded {
            showSuccessAlert()
        }
        return succeeded
    }

    // MARK: - Fallback with copyable command

    private static func showFallback(title: String, message: String, command: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy & Open Terminal")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(wrappingLabelWithString: command)
        textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textField.isSelectable = true
        textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 400).isActive = true
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
        }
    }

    // MARK: - Alerts

    private static func showSuccessAlert() {
        showAlert(
            title: "Command Line Tool Installed",
            message: "The 'mdp' command is now available in your terminal.\n\nUsage:\n  mdp README.md\n  mdp ./docs/",
            style: .informational
        )
    }

    private static func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
