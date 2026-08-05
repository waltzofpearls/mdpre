//
//  SpeechToolbarButton.swift
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

import SwiftUI
import WebKit

struct SpeechToolbarButton: View {
    @State private var speech = SpeechController.shared

    var body: some View {
        Button {
            if speech.isSpeaking {
                speech.stop()
            } else if let webView = previewWebView() {
                speech.start(in: webView)
            }
        } label: {
            Image(systemName: speech.isSpeaking ? "stop.fill" : "play.fill")
        }
        .help(speech.isSpeaking ? "Stop Speaking" : "Speak Document")
        .alert("No Voice Installed", isPresented: hasUnsupportedLanguage) {
            Button("Download Voices...") { SpeechController.openVoiceSettings() }
            Button("OK", role: .cancel) { }
        } message: {
            Text("There is no installed voice for \(speech.unsupportedLanguage ?? "this language").")
        }
    }

    private var hasUnsupportedLanguage: Binding<Bool> {
        Binding(
            get: { speech.unsupportedLanguage != nil },
            set: { if !$0 { speech.unsupportedLanguage = nil } }
        )
    }

    /// The preview is the first web view in the window. In split mode the editor
    /// is a second one, and it has no rendered DOM to read from.
    private func previewWebView() -> WKWebView? {
        guard let contentView = NSApp.keyWindow?.contentView else { return nil }
        return collectWebViews(in: contentView).first
    }

    private func collectWebViews(in view: NSView) -> [WKWebView] {
        var results: [WKWebView] = []
        if let webView = view as? WKWebView { results.append(webView) }
        for subview in view.subviews {
            results.append(contentsOf: collectWebViews(in: subview))
        }
        return results
    }
}

/// Hosted in the folder window's AppKit toolbar. An `NSToolbarItem` cannot disable
/// a hosted view, so the enabled state is taken from the folder's view mode here.
struct FolderSpeechToolbarButton: View {
    let viewModel: FolderViewModel

    var body: some View {
        SpeechToolbarButton()
            // Hosted outside a SwiftUI toolbar, so the style has to be stated. The
            // default draws a filled background the AppKit neighbours do not have.
            .buttonStyle(.accessoryBar)
            .disabled(viewModel.viewMode != .preview)
    }
}
