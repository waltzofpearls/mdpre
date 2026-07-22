//
//  ThemeToolbarButton.swift
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

struct ThemeToolbarButton: NSViewRepresentable {
    @Binding var themeMode: ThemeMode

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(
            image: NSImage(systemSymbolName: themeMode.iconName, accessibilityDescription: "Appearance")!,
            target: context.coordinator,
            action: #selector(Coordinator.clicked(_:))
        )
        button.bezelStyle = .toolbar
        button.toolTip = "Appearance"
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self
        button.image = NSImage(systemSymbolName: themeMode.iconName, accessibilityDescription: "Appearance")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject {
        var parent: ThemeToolbarButton

        init(parent: ThemeToolbarButton) {
            self.parent = parent
        }

        @objc func clicked(_ sender: NSButton) {
            let menu = NSMenu()
            for mode in ThemeMode.allCases {
                let item = NSMenuItem(
                    title: mode.menuTitle,
                    action: #selector(menuItemClicked(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = mode.rawValue
                item.state = mode == parent.themeMode ? .on : .off
                item.image = NSImage(systemSymbolName: mode.iconName, accessibilityDescription: mode.menuTitle)
                menu.addItem(item)
            }
            let point = NSPoint(x: sender.bounds.minX, y: sender.bounds.maxY)
            menu.popUp(positioning: nil, at: point, in: sender)
        }

        @objc func menuItemClicked(_ sender: NSMenuItem) {
            guard let rawValue = sender.representedObject as? String,
                  let mode = ThemeMode(rawValue: rawValue) else { return }
            parent.themeMode = mode
        }
    }
}
