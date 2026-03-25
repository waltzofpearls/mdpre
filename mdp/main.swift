//
//  main.swift
//  mdp
//
//  Created by waltzofpearls on 2026-03-22.
//

import Foundation
import AppKit

let args = CommandLine.arguments.dropFirst()

if args.isEmpty || args.contains("--help") || args.contains("-h") {
    printUsage()
    exit(args.isEmpty ? 1 : 0)
}

if args.contains("--install") {
    installCLI()
    exit(0)
}

openFiles(Array(args))

// MARK: - Functions

func printUsage() {
    let usage = """
    Usage: mdp [options] <file.md|folder> ...

    Open markdown files in Markdown Preview.

    Options:
      --install    Install mdp to /usr/local/bin
      -h, --help   Show this help message

    Examples:
      mdp README.md
      mdp docs/
      mdp file1.md file2.md
    """
    print(usage)
}

func openFiles(_ paths: [String]) {
    let fileManager = FileManager.default
    var fileURLs: [URL] = []

    for path in paths {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDir: ObjCBool = false

        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else {
            fputs("mdp: \(path): No such file or directory\n", stderr)
            continue
        }

        if isDir.boolValue {
            // Open folder as a single sidebar window
            openWithApp([url])
        } else {
            fileURLs.append(url)
        }
    }

    if !fileURLs.isEmpty {
        openWithApp(fileURLs)
    }
}

func openWithApp(_ urls: [URL]) {
    let appURL = findApp()
    let config = NSWorkspace.OpenConfiguration()
    config.activates = true

    let semaphore = DispatchSemaphore(value: 0)
    NSWorkspace.shared.open(
        urls,
        withApplicationAt: appURL,
        configuration: config
    ) { _, error in
        if let error {
            fputs("mdp: Failed to open: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
        semaphore.signal()
    }
    semaphore.wait()
}

func findApp() -> URL {
    // If running from inside the app bundle, use that app
    let execURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    let execDir = execURL.deletingLastPathComponent()

    // Check if we're inside an .app bundle (Contents/MacOS/mdp)
    if execDir.lastPathComponent == "MacOS",
       execDir.deletingLastPathComponent().lastPathComponent == "Contents" {
        let appURL = execDir
            .deletingLastPathComponent()  // Contents
            .deletingLastPathComponent()  // The.app
        return appURL
    }

    // Otherwise, look for the app in standard locations
    let appName = "Markdown Preview.app"
    let searchPaths = [
        "/Applications/\(appName)",
        "\(NSHomeDirectory())/Applications/\(appName)",
    ]

    for path in searchPaths {
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
    }

    fputs("mdp: Markdown Preview.app not found. Install it in /Applications.\n", stderr)
    exit(1)
}

func installCLI() {
    let execPath = CommandLine.arguments[0]
    let linkPath = "/usr/local/bin/mdp"

    let fileManager = FileManager.default

    // Remove existing symlink or file
    if fileManager.fileExists(atPath: linkPath) {
        do {
            try fileManager.removeItem(atPath: linkPath)
        } catch {
            fputs("mdp: Cannot remove existing \(linkPath): \(error.localizedDescription)\n", stderr)
            fputs("mdp: Try running with sudo\n", stderr)
            exit(1)
        }
    }

    // Create /usr/local/bin if it doesn't exist
    let binDir = "/usr/local/bin"
    if !fileManager.fileExists(atPath: binDir) {
        do {
            try fileManager.createDirectory(atPath: binDir, withIntermediateDirectories: true)
        } catch {
            fputs("mdp: Cannot create \(binDir): \(error.localizedDescription)\n", stderr)
            fputs("mdp: Try running with sudo\n", stderr)
            exit(1)
        }
    }

    do {
        try fileManager.createSymbolicLink(atPath: linkPath, withDestinationPath: execPath)
        print("Installed: \(linkPath) -> \(execPath)")
    } catch {
        fputs("mdp: Cannot create symlink: \(error.localizedDescription)\n", stderr)
        fputs("mdp: Try running with sudo\n", stderr)
        exit(1)
    }
}

