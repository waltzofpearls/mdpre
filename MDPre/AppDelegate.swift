//
//  AppDelegate.swift
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
import SwiftUI

extension UserDefaults {
    @objc dynamic var themeMode: String {
        string(forKey: "themeMode") ?? ThemeMode.system.rawValue
    }
}

extension NSToolbarItem.Identifier {
    static let tableOfContents = NSToolbarItem.Identifier("tableOfContents")
    static let viewMode = NSToolbarItem.Identifier("viewMode")
    static let appearance = NSToolbarItem.Identifier("appearance")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var folderWindows: [String: NSWindow] = [:]
    private var folderViewModels: [String: FolderViewModel] = [:]
    private var themeModeObserver: NSKeyValueObservation?

    /// Stops AppKit from creating an untitled document, so the open panel is shown
    /// instead, both on launch and when the dock icon is clicked with no windows open.
    ///
    /// The launch presentation comes from the DocumentGroup's default `.automatic`
    /// behavior, which shows the panel only when no other scene has presented. A
    /// restored window or a document opened from Finder appears on its own.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        var fileURLs: [URL] = []

        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
               isDir.boolValue {
                openFolderWindow(for: url)
            } else {
                fileURLs.append(url)
            }
        }

        for fileURL in fileURLs {
            NSDocumentController.shared.openDocument(
                withContentsOf: fileURL,
                display: true
            ) { _, _, _ in }
        }
    }

    func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to preview markdown files"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.openFolderWindow(for: url)
        }
    }

    private func openFolderWindow(for url: URL) {
        let path = url.standardizedFileURL.path

        // Reuse existing window for the same folder
        if let existing = folderWindows[path], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let viewModel = FolderViewModel(folderURL: url)

        // Sidebar pane
        let sidebarVC = NSHostingController(rootView: SidebarView(viewModel: viewModel))
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 400

        // Detail pane
        let detailVC = NSHostingController(rootView: FolderContentView(viewModel: viewModel))
        let detailItem = NSSplitViewItem(viewController: detailVC)
        detailItem.minimumThickness = 400

        // Split view controller
        let splitVC = NSSplitViewController()
        splitVC.addSplitViewItem(sidebarItem)
        splitVC.addSplitViewItem(detailItem)

        // Window — size to 80% of screen, capped at reasonable bounds
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let width = min(max(visibleFrame.width * 0.8, 900), 1600)
        let height = min(max(visibleFrame.height * 0.8, 600), 1100)

        let window = FolderWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.onSave = { [weak viewModel] in viewModel?.saveCurrentFile() }
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 700, height: 500)
        window.toolbarStyle = .unified
        window.titlebarAppearsTransparent = false
        window.titlebarSeparatorStyle = .automatic

        // Wire up viewModel.window BEFORE contentViewController —
        // setting contentViewController may trigger SwiftUI onAppear,
        // which needs viewModel.window to update the title.
        viewModel.window = window
        window.contentViewController = splitVC

        // Re-apply size — contentViewController may have resized the window
        // to fit the split view's preferred content size.
        window.setContentSize(NSSize(width: width, height: height))

        // Set title from selected file (belt and suspenders with onAppear)
        viewModel.updateWindowTitle()

        // Toolbar — set delegate before assigning to window
        let toolbar = NSToolbar(identifier: "FolderToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar

        if themeModeObserver == nil {
            themeModeObserver = UserDefaults.standard.observe(\.themeMode, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.updateThemeButtons()
                }
            }
        }

        // Set initial sidebar width
        splitVC.splitView.setPosition(260, ofDividerAt: 0)

        // Persist folder access for images via security-scoped bookmark
        FolderAccessManager.shared.saveBookmark(for: url)

        window.delegate = self
        folderWindows[path] = window
        folderViewModels[path] = viewModel

        // Restore saved frame if it exists, otherwise center
        let autosaveName = "FolderWindow-v2-\(path.hashValue)"
        if !window.setFrameUsingName(autosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(autosaveName)
        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - NSToolbarDelegate

extension AppDelegate: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .viewMode,
            .flexibleSpace,
            .tableOfContents,
            .appearance,
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .viewMode:
            let item = NSToolbarItem(itemIdentifier: .viewMode)
            let images = [
                toolbarSymbolImage("eye", "Preview"),
                toolbarSymbolImage("square.and.pencil", "Edit"),
                toolbarSymbolImage("rectangle.split.2x1", "Split"),
            ]
            let labels = ["Preview", "Edit", "Split"]
            let control = NSSegmentedControl(images: images, trackingMode: .selectOne, target: self, action: #selector(viewModeChanged(_:)))
            control.segmentCount = 3
            for i in 0..<3 {
                control.setImage(images[i], forSegment: i)
                control.setLabel(labels[i], forSegment: i)
            }
            control.segmentStyle = .automatic
            control.controlSize = .small
            control.selectedSegment = 0
            item.view = control
            item.label = "View Mode"
            return item
        case .tableOfContents:
            let item = NSToolbarItem(itemIdentifier: .tableOfContents)
            let button = NSButton(
                image: NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "Table of Contents")!,
                target: self,
                action: #selector(showTableOfContents(_:))
            )
            button.bezelStyle = .toolbar
            item.view = button
            item.label = "Table of Contents"
            item.toolTip = "Table of Contents"
            return item
        case .appearance:
            let mode = currentThemeMode
            let item = NSToolbarItem(itemIdentifier: .appearance)
            let button = NSButton(
                image: NSImage(systemSymbolName: mode.iconName, accessibilityDescription: "Appearance")!,
                target: self,
                action: #selector(showThemeMenu(_:))
            )
            button.bezelStyle = .toolbar
            item.view = button
            item.label = "Appearance"
            item.toolTip = "Appearance"
            return item
        default:
            return nil
        }
    }

    private func toolbarSymbolImage(_ name: String, _ description: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)!
            .withSymbolConfiguration(config)!
        var rect = image.alignmentRect
        rect.origin.y -= 1.5
        rect.size.height += 1.5
        image.alignmentRect = rect
        return image
    }

    @objc private func viewModeChanged(_ sender: NSSegmentedControl) {
        guard let window = sender.window,
              let path = folderWindows.first(where: { $0.value === window })?.key,
              let viewModel = folderViewModels[path] else { return }
        let modes = ViewMode.allCases
        if sender.selectedSegment < modes.count {
            viewModel.viewMode = modes[sender.selectedSegment]
        }
        if let tocItem = window.toolbar?.items.first(where: { $0.itemIdentifier == .tableOfContents }) {
            tocItem.isEnabled = viewModel.viewMode == .preview
        }
    }

    @objc private func showTableOfContents(_ sender: NSButton) {
        guard let webView = TableOfContents.findWebView(in: sender.window) else { return }
        TableOfContents.showMenu(from: webView, relativeTo: sender)
    }

    private var currentThemeMode: ThemeMode {
        ThemeMode(rawValue: UserDefaults.standard.string(forKey: "themeMode") ?? "") ?? .system
    }

    @objc private func showThemeMenu(_ sender: NSButton) {
        let current = currentThemeMode
        let menu = NSMenu()
        for mode in ThemeMode.allCases {
            let item = NSMenuItem(
                title: mode.menuTitle,
                action: #selector(themeMenuItemClicked(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == current ? .on : .off
            item.image = NSImage(systemSymbolName: mode.iconName, accessibilityDescription: mode.menuTitle)
            menu.addItem(item)
        }
        let point = NSPoint(x: sender.bounds.minX, y: sender.bounds.maxY)
        menu.popUp(positioning: nil, at: point, in: sender)
    }

    @objc private func themeMenuItemClicked(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = ThemeMode(rawValue: rawValue) else { return }
        UserDefaults.standard.set(mode.rawValue, forKey: "themeMode")
        updateThemeButtons()
    }

    private func updateThemeButtons() {
        let mode = currentThemeMode
        let image = NSImage(systemSymbolName: mode.iconName, accessibilityDescription: "Appearance")
        for (_, window) in folderWindows {
            if let item = window.toolbar?.items.first(where: { $0.itemIdentifier == .appearance }),
               let button = item.view as? NSButton {
                button.image = image
            }
        }
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender.isDocumentEdited,
              let path = folderWindows.first(where: { $0.value === sender })?.key,
              let viewModel = folderViewModels[path],
              let fileURL = viewModel.selectedFile else { return true }

        let response = FolderContentView.showUnsavedChangesAlert(filename: fileURL.lastPathComponent)
        switch response {
        case .alertFirstButtonReturn:
            viewModel.saveCurrentFile()
            return true
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let closedPaths = folderWindows.filter { $0.value === window }.map(\.key)
        for path in closedPaths {
            folderWindows.removeValue(forKey: path)
            folderViewModels.removeValue(forKey: path)
        }
    }
}
