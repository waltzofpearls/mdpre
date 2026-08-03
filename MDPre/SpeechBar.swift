//
//  SpeechBar.swift
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
import AVFoundation
import SwiftUI

/// Transport controls, shown only while the document is being spoken.
struct SpeechBar: View {
    @State private var speech = SpeechController.shared
    @State private var speed = Double(SpeechController.shared.speedIndex)
    @State private var scrub: Double = 0
    @State private var isScrubbing = false

    private var voiceLabels: [String: String] {
        SpeechController.labels(for: speech.voiceChoices)
    }

    private var voiceSelection: Binding<String?> {
        Binding(
            get: { speech.isAutomatic ? nil : speech.currentVoiceIdentifier },
            set: { speech.setVoice(identifier: $0) }
        )
    }

    private var speedLabel: String {
        let index = min(max(Int(speed), 0), SpeechController.speeds.count - 1)
        return SpeechController.speeds[index].label
    }

    var body: some View {
        // Wide gaps between groups, tight gaps inside them, so each label reads as
        // belonging to the control beside it.
        HStack(spacing: 18) {
            // Grouped so the button treatment does not also enlarge the sliders.
            // accessoryBar is the counterpart to the toolbar bezel the main toolbar
            // buttons use, giving a hover highlight and a real hit area.
            HStack(spacing: 2) {
                Button {
                    speech.skipBackward()
                } label: {
                    Image(systemName: "backward.fill")
                }
                .help("Previous Block")

                Button {
                    speech.isPaused ? speech.resume() : speech.pause()
                } label: {
                    Image(systemName: speech.isPaused ? "play.fill" : "pause.fill")
                }
                .help(speech.isPaused ? "Resume" : "Pause")

                Button {
                    speech.skipForward()
                } label: {
                    Image(systemName: "forward.fill")
                }
                .help("Next Block")

                Button {
                    speech.stop()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .help("Stop Speaking")
            }
            .buttonStyle(.accessoryBar)
            .controlSize(.large)

            HStack(spacing: 8) {
                // Seeks on release. Seeking live would requeue the document on every
                // pixel of the drag.
                Slider(value: $scrub, in: 0...1) { editing in
                    isScrubbing = editing
                    if !editing { speech.seek(to: scrub) }
                }
                .frame(maxWidth: .infinity)
                .onChange(of: speech.progress) { _, newValue in
                    if !isScrubbing { scrub = newValue }
                }

                Text(speech.progressText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .help(speech.progressDescription)
            }

            HStack(spacing: 8) {
                // Snaps to the measured steps, and applies when the drag ends since
                // every change requeues the document.
                Slider(
                    value: $speed,
                    in: 0...Double(SpeechController.speeds.count - 1),
                    step: 1
                ) { editing in
                    if !editing { speech.setSpeed(index: Int(speed)) }
                }
                .frame(width: 110)

                // Fixed width so the slider does not shift as the label changes.
                Text(speedLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)
            }
            .help("Playback speed")

            // Inline picker so the current voice gets a checkmark. Automatic names
            // what it resolved to, since "Automatic" alone leaves that unanswered.
            Menu {
                Picker(speech.languageName, selection: voiceSelection) {
                    Text("Automatic (\(speech.automaticVoiceName))").tag(String?.none)
                    ForEach(speech.voiceChoices, id: \.identifier) { choice in
                        Text(voiceLabels[choice.identifier] ?? choice.name)
                            .tag(Optional(choice.identifier))
                    }
                }
                .pickerStyle(.inline)
                Divider()
                Button("Download More Voices...") { SpeechController.openVoiceSettings() }
            } label: {
                Text(speech.voiceName)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Voice")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}
