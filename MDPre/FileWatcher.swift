//
//  FileWatcher.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import Foundation

final class FileWatcher {
    private let url: URL
    private let onChange: (String) -> Void

    private var fileSource: DispatchSourceFileSystemObject?
    private var dirSource: DispatchSourceFileSystemObject?
    private var debounceTimer: DispatchSourceTimer?
    private var lastModDate: Date?

    init(url: URL, onChange: @escaping (String) -> Void) {
        self.url = url
        self.onChange = onChange
        self.lastModDate = Self.modificationDate(of: url)
        installFileMonitor()
        installDirectoryMonitor()
    }

    deinit {
        stopWatching()
    }

    func stopWatching() {
        debounceTimer?.cancel()
        debounceTimer = nil
        fileSource?.cancel()
        fileSource = nil
        dirSource?.cancel()
        dirSource = nil
    }

    // MARK: - Monitors

    private func installFileMonitor() {
        fileSource?.cancel()
        fileSource = nil

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.handleEvent()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileSource = source
    }

    private func installDirectoryMonitor() {
        let dirPath = url.deletingLastPathComponent().path
        let fd = open(dirPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.handleEvent()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        dirSource = source
    }

    // MARK: - Event handling

    private func handleEvent() {
        let currentModDate = Self.modificationDate(of: url)

        guard currentModDate != lastModDate else { return }
        lastModDate = currentModDate

        scheduleDebounce()
    }

    private func scheduleDebounce() {
        debounceTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(200))
        timer.setEventHandler { [weak self] in
            self?.readAndNotify()
        }
        timer.resume()
        debounceTimer = timer
    }

    private func readAndNotify() {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        onChange(content)
        installFileMonitor()
    }

    // MARK: - Helpers

    private static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
