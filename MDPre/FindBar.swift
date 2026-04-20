//
//  FindBar.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-04-19.
//

import AppKit
import SwiftUI
import WebKit

struct FindResult: Decodable {
    let total: Int
    let current: Int
}

struct FindBar: NSViewRepresentable {
    @Binding var isVisible: Bool

    func makeNSView(context: Context) -> FindBarView {
        let view = FindBarView(coordinator: context.coordinator)
        view.isHidden = !isVisible
        if isVisible {
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view.searchField)
            }
        }
        return view
    }

    func updateNSView(_ view: FindBarView, context: Context) {
        let wasHidden = view.isHidden
        view.isHidden = !isVisible
        if isVisible && wasHidden {
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view.searchField)
            }
        }
        if !isVisible && !wasHidden {
            view.searchField.stringValue = ""
            view.matchLabel.stringValue = ""
            context.coordinator.currentQuery = ""
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        let parent: FindBar
        weak var webView: WKWebView?
        var currentQuery = ""

        init(parent: FindBar) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            currentQuery = field.stringValue
            search(query: currentQuery)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                dismiss()
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                    findPrevious()
                } else {
                    findNext()
                }
                return true
            }
            return false
        }

        func search(query: String) {
            guard let webView = findWebView() else { return }
            let escaped = query.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            webView.evaluateJavaScript("findInPage('\(escaped)')") { [weak self] result, _ in
                self?.updateMatchCount(from: result)
            }
        }

        func findNext() {
            guard let webView = findWebView() else { return }
            webView.evaluateJavaScript("findNext()") { [weak self] result, _ in
                self?.updateMatchCount(from: result)
            }
        }

        func findPrevious() {
            guard let webView = findWebView() else { return }
            webView.evaluateJavaScript("findPrevious()") { [weak self] result, _ in
                self?.updateMatchCount(from: result)
            }
        }

        func dismiss() {
            findWebView()?.evaluateJavaScript("clearFind()")
            parent.isVisible = false
        }

        private func findWebView() -> WKWebView? {
            if let webView { return webView }
            guard let view = NSApp.keyWindow else { return nil }
            let found = TableOfContents.findWebView(in: view)
            webView = found
            return found
        }

        private func updateMatchCount(from result: Any?) {
            guard let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let findResult = try? JSONDecoder().decode(FindResult.self, from: data),
                  let view = NSApp.keyWindow?.contentView?.findSubview(ofType: FindBarView.self) else { return }
            if findResult.total > 0 {
                view.matchLabel.stringValue = "\(findResult.current) of \(findResult.total)"
            } else if !currentQuery.isEmpty {
                view.matchLabel.stringValue = "No matches"
            } else {
                view.matchLabel.stringValue = ""
            }
        }
    }
}

class FindBarView: NSView {
    let searchField = NSSearchField()
    let matchLabel = NSTextField(labelWithString: "")
    private let previousButton: NSButton
    private let nextButton: NSButton
    private let closeButton: NSButton
    private weak var coordinator: FindBar.Coordinator?

    init(coordinator: FindBar.Coordinator) {
        self.coordinator = coordinator

        previousButton = NSButton(
            image: NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Previous")!,
            target: nil, action: nil
        )
        nextButton = NSButton(
            image: NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Next")!,
            target: nil, action: nil
        )
        closeButton = NSButton(
            image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")!,
            target: nil, action: nil
        )

        super.init(frame: .zero)

        previousButton.target = self
        previousButton.action = #selector(previousClicked)
        previousButton.bezelStyle = .toolbar

        nextButton.target = self
        nextButton.action = #selector(nextClicked)
        nextButton.bezelStyle = .toolbar

        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        closeButton.bezelStyle = .toolbar

        searchField.delegate = coordinator
        searchField.placeholderString = "Find in document"
        searchField.sendsSearchStringImmediately = true
        searchField.translatesAutoresizingMaskIntoConstraints = false

        matchLabel.font = .systemFont(ofSize: 11)
        matchLabel.textColor = .secondaryLabelColor
        matchLabel.setContentHuggingPriority(.required, for: .horizontal)
        matchLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = NSStackView(views: [searchField, matchLabel, previousButton, nextButton, closeButton])
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func previousClicked() { coordinator?.findPrevious() }
    @objc private func nextClicked() { coordinator?.findNext() }
    @objc private func closeClicked() { coordinator?.dismiss() }
}

struct FindCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Find...") {
                FindBarController.toggleFindBar()
            }
            .keyboardShortcut("f", modifiers: [.command])
        }
    }
}

enum FindBarController {
    static func toggleFindBar() {
        guard let window = NSApp.keyWindow else { return }

        // Folder window — toggle via viewModel
        if let folderWindow = window as? FolderWindow {
            folderWindow.onFind?()
            return
        }

        // Single-file window — post notification for ContentView
        NotificationCenter.default.post(name: .toggleFindBar, object: window)
    }
}

extension Notification.Name {
    static let toggleFindBar = Notification.Name("toggleFindBar")
}

private extension NSView {
    func findSubview<T: NSView>(ofType type: T.Type) -> T? {
        if let match = self as? T { return match }
        for subview in subviews {
            if let found = subview.findSubview(ofType: type) { return found }
        }
        return nil
    }
}
