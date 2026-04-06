//
//  CLIInstaller.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-04-05.
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

        // 1. Try Apple's privileged file operations API (sandbox-friendly, requires entitlement)
        if installViaWorkspaceAuthorization(source: source) { return }

        // 2. Try osascript with admin privileges (works for non-sandboxed DMG distribution)
        let shellCommand = "mkdir -p /usr/local/bin && ln -sf '\(source.path)' '\(installPath)'"
        switch runWithAdminPrivileges(shellCommand) {
        case .success:
            showSuccessAlert()
            return
        case .cancelled:
            return
        case .failed:
            break
        }

        // 3. Fallback: copy command for user to run in Terminal
        showFallback(
            title: "Install Command Line Tool",
            message: "To install the 'mdp' command, copy and run this in Terminal.\n\nThis requires administrator privileges because /usr/local/bin is a system directory.",
            command: "sudo ln -sf '\(source.path)' '\(installPath)'"
        )
    }

    // MARK: - Uninstall

    static func uninstall() {
        // 1. Try Apple's privileged file operations API
        if uninstallViaWorkspaceAuthorization() { return }

        // 2. Try osascript
        switch runWithAdminPrivileges("rm -f '\(installPath)'") {
        case .success:
            showAlert(
                title: "Command Line Tool Removed",
                message: "The 'mdp' command has been removed from /usr/local/bin.",
                style: .informational
            )
            return
        case .cancelled:
            return
        case .failed:
            break
        }

        // 3. Fallback
        showFallback(
            title: "Uninstall Command Line Tool",
            message: "To remove the 'mdp' command, copy and run this in Terminal.",
            command: "sudo rm -f '\(installPath)'"
        )
    }

    // MARK: - Approach 1: NSWorkspace authorization (sandbox-friendly)

    private static func installViaWorkspaceAuthorization(source: URL) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var succeeded = false

        NSWorkspace.shared.requestAuthorization(to: .createSymbolicLink) { auth, error in
            defer { semaphore.signal() }
            guard let auth else { return }

            let fm = FileManager(authorization: auth)
            do {
                // Ensure /usr/local/bin exists
                if !FileManager.default.fileExists(atPath: installDirURL.path) {
                    try fm.createDirectory(at: installDirURL, withIntermediateDirectories: true)
                }
                // Remove existing symlink if present
                if FileManager.default.fileExists(atPath: installPath) {
                    try fm.removeItem(at: installURL)
                }
                try fm.createSymbolicLink(at: installURL, withDestinationURL: source)
                succeeded = true
            } catch {
                // Fall through to next approach
            }
        }

        semaphore.wait()

        if succeeded {
            showSuccessAlert()
        }
        return succeeded
    }

    private static func uninstallViaWorkspaceAuthorization() -> Bool {
        guard FileManager.default.fileExists(atPath: installPath) else { return false }

        let semaphore = DispatchSemaphore(value: 0)
        var succeeded = false

        NSWorkspace.shared.requestAuthorization(to: .createSymbolicLink) { auth, error in
            defer { semaphore.signal() }
            guard let auth else { return }

            let fm = FileManager(authorization: auth)
            do {
                try fm.removeItem(at: installURL)
                succeeded = true
            } catch {
                // Fall through to next approach
            }
        }

        semaphore.wait()

        if succeeded {
            showAlert(
                title: "Command Line Tool Removed",
                message: "The 'mdp' command has been removed from /usr/local/bin.",
                style: .informational
            )
        }
        return succeeded
    }

    // MARK: - Approach 2: osascript with admin privileges

    private enum AdminResult {
        case success, cancelled, failed
    }

    private static func runWithAdminPrivileges(_ command: String) -> AdminResult {
        let script = "do shell script \"\(command)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failed
        }

        if process.terminationStatus == 0 {
            return .success
        }

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8) ?? ""

        if errorMessage.contains("-128") || errorMessage.contains("User canceled") {
            return .cancelled
        }

        return .failed
    }

    // MARK: - Approach 3: Fallback with copyable command

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
