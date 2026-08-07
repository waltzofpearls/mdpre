//
//  main.swift
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

if args.contains("--version") || args.contains("-v") {
    printVersion()
    exit(0)
}

openFiles(Array(args))

// MARK: - Functions

func printUsage() {
    let usage = """
    Usage: mdp [options] <file.md|folder> ...

    Open markdown files in Markdown Preview.

    Options:
      --install       Install mdp to /usr/local/bin
      -h, --help      Show this help message
      -v, --version   Show the version

    Examples:
      mdp README.md
      mdp docs/
      mdp file1.md file2.md
    """
    print(usage)
}

/// The version of the app bundle this command ships inside.
func printVersion() {
    let appURL = findApp()
    let info = NSDictionary(contentsOf: appURL.appendingPathComponent("Contents/Info.plist"))
    let short = info?["CFBundleShortVersionString"] as? String ?? "unknown"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    print("Markdown Preview \(short) (\(build))")
}

func openFiles(_ paths: [String]) {
    let fileManager = FileManager.default
    var fileURLs: [URL] = []

    for path in paths {
        let expanded = path.hasPrefix("~") ? (path as NSString).expandingTildeInPath : path
        let absolute = expanded.hasPrefix("/") ? expanded : (ProcessInfo.processInfo.environment["PWD"] ?? fileManager.currentDirectoryPath) + "/" + expanded
        let url = URL(fileURLWithPath: absolute).standardizedFileURL
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
    // Handing over a file URL requires access to it. The sandboxed build has none,
    // and attempting it anyway makes LaunchServices show a system error dialog, so
    // decide up front: unreadable here means send the path as a string and let the
    // app, which can ask the user for access, open it.
    guard urls.allSatisfy({ FileManager.default.isReadableFile(atPath: $0.path) }) else {
        openViaURLScheme(urls)
        return
    }

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
        }
        semaphore.signal()
    }
    semaphore.wait()
}

func openViaURLScheme(_ urls: [URL]) {
    for url in urls {
        var components = URLComponents()
        components.scheme = "mdpre"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "path", value: url.path)]
        guard let schemeURL = components.url else { continue }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        let semaphore = DispatchSemaphore(value: 0)
        NSWorkspace.shared.open(schemeURL, configuration: config) { _, error in
            if let error {
                fputs("mdp: Failed to open: \(error.localizedDescription)\n", stderr)
            }
            semaphore.signal()
        }
        semaphore.wait()
    }
}

func findApp() -> URL {
    // Prefer the bundle this command was installed from. argv[0] is just "mdp" when
    // run from PATH, so ask for the real executable path, then resolve the install
    // symlink to reach the bundle it points into.
    let execURL = (Bundle.main.executableURL
        ?? URL(fileURLWithPath: CommandLine.arguments[0])).resolvingSymlinksInPath()
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

