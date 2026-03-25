//
//  FolderViewModel.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import AppKit

@Observable
class FolderViewModel {
    var folderURL: URL
    var files: [URL] = []
    var selectedFile: URL?
    var selectedFileContent: String = ""

    @ObservationIgnored weak var window: NSWindow?
    private var directoryMonitor: DispatchSourceFileSystemObject?

    init(folderURL: URL) {
        self.folderURL = folderURL
        loadFiles()
        startMonitoring()
    }

    deinit {
        directoryMonitor?.cancel()
    }

    func loadFiles() {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var markdownFiles: [URL] = []
        for case let fileURL as URL in enumerator {
            if Self.isMarkdown(fileURL) {
                markdownFiles.append(fileURL)
            }
        }
        files = markdownFiles.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        if selectedFile == nil || !files.contains(where: { $0 == selectedFile }) {
            selectedFile = files.first
        }
        if let selected = selectedFile {
            loadContent(for: selected)
        }
    }

    func loadContent(for url: URL) {
        selectedFileContent = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private func startMonitoring() {
        let fd = open(folderURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.loadFiles()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        directoryMonitor = source
    }

    func updateWindowTitle() {
        guard let selectedFile else {
            window?.title = folderURL.lastPathComponent
            window?.subtitle = ""
            return
        }
        window?.title = selectedFile.lastPathComponent

        let filePath = selectedFile.deletingLastPathComponent().path
        let folderPath = folderURL.path
        guard filePath != folderPath else {
            window?.subtitle = ""
            return
        }
        let prefix = folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
        guard filePath.hasPrefix(prefix) else {
            window?.subtitle = ""
            return
        }
        window?.subtitle = String(filePath.dropFirst(prefix.count))
    }

    static func isMarkdown(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "md" || ext == "markdown" || ext == "mdown" || ext == "mkd"
    }
}
