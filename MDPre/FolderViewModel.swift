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
    private var directoryDebounce: DispatchSourceTimer?
    @ObservationIgnored private var fileWatcher: FileWatcher?

    init(folderURL: URL) {
        self.folderURL = folderURL
        loadFiles()
        startMonitoring()
    }

    deinit {
        directoryDebounce?.cancel()
        directoryMonitor?.cancel()
        fileWatcher?.stopWatching()
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
        let sorted = markdownFiles.sorted(by: fileSortOrder)

        // The directory monitor fires on any .write event including file content
        // saves. Only proceed when files are actually added or removed.
        // FileWatcher handles content updates for the selected file.
        guard sorted != files else { return }

        let previousSelection = selectedFile
        files = sorted

        if selectedFile == nil || !files.contains(where: { $0 == selectedFile }) {
            selectedFile = files.first
        }
        if selectedFile != previousSelection, let selected = selectedFile {
            loadContent(for: selected)
        }
    }

    /// Sort by directory depth (top-level first), then alphabetically by
    /// relative path within the same depth. This groups files by directory
    /// and keeps the ordering stable and predictable.
    private func fileSortOrder(_ a: URL, _ b: URL) -> Bool {
        let relA = relativePath(for: a)
        let relB = relativePath(for: b)
        let depthA = relA.components(separatedBy: "/").count
        let depthB = relB.components(separatedBy: "/").count
        if depthA != depthB { return depthA < depthB }
        return relA.localizedStandardCompare(relB) == .orderedAscending
    }

    private func relativePath(for url: URL) -> String {
        let filePath = url.path
        let base = folderURL.path
        let prefix = base.hasSuffix("/") ? base : base + "/"
        if filePath.hasPrefix(prefix) {
            return String(filePath.dropFirst(prefix.count))
        }
        return url.lastPathComponent
    }

    func loadContent(for url: URL) {
        selectedFileContent = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        startFileWatching()
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
            self?.scheduleLoadFiles()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        directoryMonitor = source
    }

    /// Debounce directory events to let atomic saves finish.
    /// Editors like vim rename-then-create in rapid succession; without a delay,
    /// loadFiles() can see the intermediate state where the file is missing.
    private func scheduleLoadFiles() {
        directoryDebounce?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(200))
        timer.setEventHandler { [weak self] in
            self?.loadFiles()
        }
        timer.resume()
        directoryDebounce = timer
    }

    private func startFileWatching() {
        fileWatcher?.stopWatching()
        fileWatcher = nil
        guard let selectedFile else { return }
        fileWatcher = FileWatcher(url: selectedFile) { [weak self] newContent in
            self?.selectedFileContent = newContent
        }
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
            window?.subtitle = "./"
            return
        }
        let prefix = folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
        guard filePath.hasPrefix(prefix) else {
            window?.subtitle = "./"
            return
        }
        window?.subtitle = "./" + String(filePath.dropFirst(prefix.count)) + "/"
    }

    static func isMarkdown(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "md" || ext == "markdown" || ext == "mdown" || ext == "mkd"
    }
}
