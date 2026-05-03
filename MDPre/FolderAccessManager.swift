//
//  FolderAccessManager.swift
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

class FolderAccessManager {
    static let shared = FolderAccessManager()

    private let bookmarkKey = "FolderBookmarks"
    private var activeAccess: [String: URL] = [:]

    private init() {}

    func startAccessing(directory: URL) -> Bool {
        let key = directory.path

        if activeAccess[key] != nil { return true }

        guard let bookmarks = UserDefaults.standard.dictionary(forKey: bookmarkKey) as? [String: Data],
              let bookmarkData = bookmarks[key] else {
            return false
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return false
        }

        if isStale {
            if let newData = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                var updated = bookmarks
                updated[key] = newData
                UserDefaults.standard.set(updated, forKey: bookmarkKey)
            }
        }

        guard url.startAccessingSecurityScopedResource() else {
            return false
        }

        activeAccess[key] = url
        return true
    }

    func saveBookmark(for directory: URL) {
        guard let bookmarkData = try? directory.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return
        }

        var bookmarks = UserDefaults.standard.dictionary(forKey: bookmarkKey) as? [String: Data] ?? [:]
        bookmarks[directory.path] = bookmarkData
        UserDefaults.standard.set(bookmarks, forKey: bookmarkKey)
    }

    func requestAccess(for directory: URL, completion: @escaping (Bool) -> Void) {
        // Pre-flight alert explaining why we need access
        let alert = NSAlert()
        alert.messageText = "Folder Access Needed"
        alert.informativeText = "This document references local images. To display them, Markdown Preview needs read access to the folder containing the document.\n\nYou\u{2019}ll be asked to confirm the folder in the next step."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Not Now")

        guard alert.runModal() == .alertFirstButtonReturn else {
            completion(false)
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        panel.message = "Confirm the folder below and click Allow to display images."
        panel.prompt = "Allow"

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(false)
                return
            }
            self.saveBookmark(for: url)
            let started = self.startAccessing(directory: url)
            completion(started)
        }
    }

    func stopAllAccess() {
        for (_, url) in activeAccess {
            url.stopAccessingSecurityScopedResource()
        }
        activeAccess.removeAll()
    }
}
