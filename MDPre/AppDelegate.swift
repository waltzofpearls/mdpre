//
//  AppDelegate.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-03-22.
//

import AppKit
import SwiftUI

extension NSToolbarItem.Identifier {
    static let tableOfContents = NSToolbarItem.Identifier("tableOfContents")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var folderWindows: [String: NSWindow] = [:]

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
        window.onFind = { viewModel.showFindBar.toggle() }
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

        // Set initial sidebar width
        splitVC.splitView.setPosition(260, ofDividerAt: 0)

        // Persist folder access for images via security-scoped bookmark
        FolderAccessManager.shared.saveBookmark(for: url)

        window.delegate = self
        folderWindows[path] = window

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
            .flexibleSpace,
            .tableOfContents,
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
        default:
            return nil
        }
    }

    @objc private func showTableOfContents(_ sender: NSButton) {
        guard let webView = TableOfContents.findWebView(in: sender.window) else { return }
        TableOfContents.showMenu(from: webView, relativeTo: sender)
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        folderWindows = folderWindows.filter { $0.value !== window }
    }
}
