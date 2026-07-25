//
//  EditorToolbar.swift
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
import WebKit

struct EditorToolbar: View {
    var webView: WKWebView?

    var body: some View {
        HStack(spacing: 2) {
            button("bold", "Bold") { js("formatBold()") }
            button("italic", "Italic") { js("formatItalic()") }
            button("strikethrough", "Strikethrough") { js("formatStrikethrough()") }
            button("chevron.left.forwardslash.chevron.right", "Inline Code") { js("formatCode()") }
            button("curlybraces", "Code Block") { js("formatCodeBlock()") }

            toolbarDivider

            HeadingMenuButton { level in js("formatHeading(\(level))") }
                .frame(width: 24, height: 20)
            button("list.bullet", "Unordered List") { js("formatUnorderedList()") }
            button("list.number", "Ordered List") { js("formatOrderedList()") }
            button("text.quote", "Blockquote") { js("formatBlockquote()") }

            toolbarDivider

            button("link", "Link") { js("formatLink()") }
            button("photo", "Image") { js("formatImage()") }
            button("tablecells", "Table") { js("formatTable()") }
            button("minus", "Horizontal Rule") { js("formatHorizontalRule()") }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private func button(_ icon: String, _ tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 24, height: 20)
        }
        .buttonStyle(.borderless)
        .help(tooltip)
    }

    private var toolbarDivider: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 4)
    }

    private func js(_ code: String) {
        webView?.evaluateJavaScript(code)
    }
}

struct HeadingMenuButton: NSViewRepresentable {
    var onSelect: (Int) -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.image = NSImage(systemSymbolName: "number", accessibilityDescription: "Heading")
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.target = context.coordinator
        button.action = #selector(Coordinator.clicked(_:))
        button.toolTip = "Heading"
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.onSelect = onSelect
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    class Coordinator: NSObject {
        var onSelect: (Int) -> Void

        init(onSelect: @escaping (Int) -> Void) {
            self.onSelect = onSelect
        }

        @objc func clicked(_ sender: NSButton) {
            let menu = NSMenu()
            for level in 1...6 {
                let item = NSMenuItem(
                    title: "Heading \(level)",
                    action: #selector(headingSelected(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = level
                menu.addItem(item)
            }
            let point = NSPoint(x: 0, y: sender.bounds.maxY + 4)
            menu.popUp(positioning: nil, at: point, in: sender)
        }

        @objc func headingSelected(_ sender: NSMenuItem) {
            onSelect(sender.tag)
        }
    }
}
