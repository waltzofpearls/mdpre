import AppKit
import SwiftUI
import WebKit

struct TableOfContentsEntry: Decodable {
    let level: Int
    let text: String
    let id: String
}

enum TableOfContents {
    static func findWebView(in window: NSWindow?) -> WKWebView? {
        guard let contentView = window?.contentView else { return nil }
        return findSubview(ofType: WKWebView.self, in: contentView)
    }

    private static func findSubview<T: NSView>(ofType type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let found = findSubview(ofType: type, in: subview) { return found }
        }
        return nil
    }

    static func getEntries(from webView: WKWebView, completion: @escaping ([TableOfContentsEntry]) -> Void) {
        webView.evaluateJavaScript("getTableOfContents()") { result, _ in
            guard let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let entries = try? JSONDecoder().decode([TableOfContentsEntry].self, from: data) else {
                completion([])
                return
            }
            completion(entries)
        }
    }

    static func scrollToHeading(id: String, in webView: WKWebView) {
        let safeID = id.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("scrollToHeading('\(safeID)')")
    }

    static func showMenu(from webView: WKWebView, relativeTo view: NSView) {
        getEntries(from: webView) { entries in
            let menu = NSMenu(title: "Table of Contents")
            if entries.isEmpty {
                let item = NSMenuItem(title: "No headings", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            } else {
                for entry in entries {
                    let item = NSMenuItem(
                        title: entry.text,
                        action: #selector(TableOfContentsMenuTarget.menuItemClicked(_:)),
                        keyEquivalent: ""
                    )
                    item.target = TableOfContentsMenuTarget.shared
                    item.indentationLevel = entry.level - 1
                    item.representedObject = entry.id
                    menu.addItem(item)
                }
            }
            TableOfContentsMenuTarget.shared.webView = webView
            let point = NSPoint(x: view.bounds.minX, y: view.bounds.maxY)
            menu.popUp(positioning: nil, at: point, in: view)
        }
    }
}

struct TableOfContentsToolbarButton: NSViewRepresentable {
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(
            image: NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "Table of Contents")!,
            target: context.coordinator,
            action: #selector(Coordinator.clicked(_:))
        )
        button.bezelStyle = .toolbar
        button.toolTip = "Table of Contents"
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        @objc func clicked(_ sender: NSButton) {
            guard let webView = TableOfContents.findWebView(in: sender.window) else { return }
            TableOfContents.showMenu(from: webView, relativeTo: sender)
        }
    }
}

class TableOfContentsMenuTarget: NSObject {
    static let shared = TableOfContentsMenuTarget()
    var webView: WKWebView?

    @objc func menuItemClicked(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let webView else { return }
        TableOfContents.scrollToHeading(id: id, in: webView)
    }
}
