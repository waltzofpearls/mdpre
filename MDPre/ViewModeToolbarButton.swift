//
//  ViewModeToolbarButton.swift
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

struct ViewModeToolbarButton: NSViewRepresentable {
    @Binding var viewMode: ViewMode

    private func symbolImage(_ name: String, _ description: String) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)!
            .withSymbolConfiguration(config)!
        // Shift icon up 1.5px by adding bottom inset to alignment rect
        var rect = image.alignmentRect
        rect.origin.y -= 1.5
        rect.size.height += 1.5
        image.alignmentRect = rect
        return image
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let images = [
            symbolImage("eye", "Preview"),
            symbolImage("chevron.left.forwardslash.chevron.right", "Source"),
            symbolImage("rectangle.split.2x1", "Split"),
        ]
        let labels = ["Preview", "Source", "Split"]

        let control = NSSegmentedControl(images: images, trackingMode: .selectOne, target: context.coordinator, action: #selector(Coordinator.segmentChanged(_:)))
        control.segmentCount = 3
        for i in 0..<3 {
            control.setImage(images[i], forSegment: i)
            control.setLabel(labels[i], forSegment: i)
        }
        control.segmentStyle = .automatic
        control.controlSize = .small
        control.selectedSegment = ViewMode.allCases.firstIndex(of: viewMode) ?? 0
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self

        let index = ViewMode.allCases.firstIndex(of: viewMode) ?? 0
        if control.selectedSegment != index {
            control.selectedSegment = index
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject {
        var parent: ViewModeToolbarButton

        init(parent: ViewModeToolbarButton) {
            self.parent = parent
        }

        @objc func segmentChanged(_ sender: NSSegmentedControl) {
            let modes = ViewMode.allCases
            if sender.selectedSegment < modes.count {
                parent.viewMode = modes[sender.selectedSegment]
            }
        }
    }
}
