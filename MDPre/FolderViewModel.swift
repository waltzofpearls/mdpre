//
//  FolderViewModel.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import AppKit
import CoreServices

@Observable
class FolderViewModel {
    var folderURL: URL
    var files: [URL] = []
    var selectedFile: URL?
    var selectedFileContent: String = ""
    var showFindBar = false
    var viewMode: ViewMode = .preview

    @ObservationIgnored weak var window: NSWindow?
    private var eventStream: FSEventStreamRef?
    @ObservationIgnored private var fileWatcher: FileWatcher?

    init(folderURL: URL) {
        self.folderURL = folderURL
        loadFiles()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
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

        // FSEvents fires for any change in the directory tree, including file
        // content saves. Only proceed when files are actually added or removed.
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

    // MARK: - Directory monitoring (FSEvents)

    /// Monitor the entire folder tree for file additions/removals using FSEvents.
    /// The 0.2s latency coalesces rapid events (e.g. atomic saves that
    /// rename-then-create) so loadFiles() sees the final state.
    private func startMonitoring() {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var context = FSEventStreamContext(
            version: 0, info: selfPtr,
            retain: nil, release: nil, copyDescription: nil
        )
        guard let stream = FSEventStreamCreate(
            nil,
            { _, info, _, _, _, _ in
                guard let info else { return }
                Unmanaged<FolderViewModel>.fromOpaque(info)
                    .takeUnretainedValue()
                    .loadFiles()
            },
            &context,
            [folderURL.path as CFString] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            UInt32(kFSEventStreamCreateFlagUseCFTypes)
        ) else { return }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        eventStream = stream
    }

    private func stopMonitoring() {
        guard let stream = eventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
    }

    // MARK: - File watching (selected file content)

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
