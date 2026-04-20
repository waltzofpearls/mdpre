//
//  FolderWindow.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-04-19.
//

import AppKit

class FolderWindow: NSWindow {
    var onFind: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "f" {
            onFind?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
