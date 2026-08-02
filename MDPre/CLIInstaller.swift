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

        alert.accessoryView = commandBox(command)

        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
        }
    }

    /// Slightly darker than the alert background in both appearances. The semantic
    /// fill colors render lighter than the alert in light mode, so the tint is
    /// specified explicitly.
    private static let commandBoxFill = NSColor(name: "commandBoxFill") { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor.black.withAlphaComponent(0.28)
            : NSColor.black.withAlphaComponent(0.06)
    }

    /// A selectable code box for one or more commands.
    ///
    /// NSBox is used rather than a layer backed view so the fill and border follow
    /// the light and dark appearance. The box is given an explicit frame because
    /// NSAlert sizes its accessory view from the frame, not from constraints.
    private static func commandBox(_ command: String) -> NSView {
        let label = NSTextField(labelWithString: command)
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.isSelectable = true
        label.usesSingleLineMode = false
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byClipping
        label.translatesAutoresizingMaskIntoConstraints = false

        let box = NSBox()
        box.boxType = .custom
        box.fillColor = commandBoxFill
        box.borderColor = .separatorColor
        box.borderWidth = 1
        box.cornerRadius = 6
        box.titlePosition = .noTitle
        box.contentViewMargins = .zero
        box.addSubview(label)

        let padX: CGFloat = 12, padY: CGFloat = 9
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: padX),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -padX),
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: padY),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -padY),
        ])

        let size = label.intrinsicContentSize
        box.frame = NSRect(x: 0, y: 0, width: size.width + padX * 2, height: size.height + padY * 2)
        return box
    }

    // MARK: - Alerts

    private static func showSuccessAlert() {
        let alert = NSAlert()
        alert.messageText = "Command Line Tool Installed"
        alert.informativeText = "The 'mdp' command is now available in your terminal. Usage:"
        alert.alertStyle = .informational
        alert.accessoryView = commandBox("mdp README.md\nmdp ./docs/")
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
