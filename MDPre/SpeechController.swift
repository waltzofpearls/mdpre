//
//  SpeechController.swift
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
import NaturalLanguage
import WebKit

/// Speaks the rendered preview aloud.
///
/// Text comes from the rendered DOM, never the markdown source, so heading
/// markers, emphasis characters and raw URLs are not read out. Each block
/// element is queued as its own utterance, which keeps long documents
/// responsive and gives skip controls somewhere to land.
@Observable
final class SpeechController: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechController()

    private(set) var isSpeaking = false
    private(set) var isPaused = false
    private(set) var currentIndex = 0
    private(set) var language = "en-US"
    /// Set when a document's language has no installed voice, so the UI can say so.
    var unsupportedLanguage: String?
    /// Absolute position in the document, in characters, for the scrubber.
    private(set) var spokenCharacters = 0

    struct Speed {
        let rate: Float
        let label: String
    }

    /// Rate is not a multiplier and the curve is nonlinear, so these were measured
    /// by timing rendered speech. Odd count on purpose: Normal sits at the centre.
    static let speeds: [Speed] = [
        Speed(rate: 0.15, label: "0.7x"),
        Speed(rate: 0.29, label: "0.8x"),
        Speed(rate: 0.36, label: "0.9x"),
        Speed(rate: 0.50, label: "Normal"),
        Speed(rate: 0.54, label: "1.25x"),
        Speed(rate: 0.59, label: "1.5x"),
        Speed(rate: 0.66, label: "2x"),
    ]

    private(set) var rate: Float

    private let synthesizer = AVSpeechSynthesizer()
    private weak var webView: WKWebView?
    /// Held in queue order so a range callback can identify the block being spoken.
    /// After a skip the queue starts partway through, hence `queueBase`.
    private var utterances: [AVSpeechUtterance] = []
    private var queueBase = 0
    /// Set when a change was made while paused, to be applied on resume.
    private var needsRequeue = false
    private var chunks: [String] = []
    private var voice: AVSpeechSynthesisVoice?
    /// Chosen voice per language, keyed by two letter code. Absent means automatic.
    private var voiceOverrides: [String: String]

    private static let voiceOverridesKey = "speechVoiceOverrides"
    private static let noveltyPrefix = "com.apple.speech.synthesis.voice."
    private static let siriPrefix = "com.apple.ttsbundle.siri_"
    /// Cumulative UTF-16 offset where each chunk starts, so progress is weighted by
    /// length rather than block count.
    private var characterOffsets: [Int] = []
    private var totalCharacters = 0

    private static let rateKey = "speechRate"

    override init() {
        let saved = UserDefaults.standard.object(forKey: Self.rateKey) as? Float
        rate = saved ?? AVSpeechUtteranceDefaultSpeechRate
        voiceOverrides = UserDefaults.standard
            .dictionary(forKey: Self.voiceOverridesKey) as? [String: String] ?? [:]
        super.init()
        synthesizer.delegate = self
    }

    private var languageKey: String { String(language.prefix(2)) }

    var isAutomatic: Bool { voiceOverrides[languageKey] == nil }
    var voiceName: String { voice?.name ?? "" }
    var currentVoiceIdentifier: String? { voice?.identifier }
    var voiceChoices: [AVSpeechSynthesisVoice] { Self.voices(for: language) }
    var automaticVoiceName: String { Self.voices(for: language).first?.name ?? "" }
    var languageName: String { Locale.current.localizedString(forIdentifier: language) ?? language }

    func setVoice(identifier: String?) {
        if let identifier {
            voiceOverrides[languageKey] = identifier
        } else {
            voiceOverrides.removeValue(forKey: languageKey)
        }
        UserDefaults.standard.set(voiceOverrides, forKey: Self.voiceOverridesKey)
        voice = resolveVoice()
        guard isSpeaking else { return }
        if isPaused { needsRequeue = true } else { speak(from: currentIndex) }
    }

    private func resolveVoice() -> AVSpeechSynthesisVoice? {
        if let identifier = voiceOverrides[languageKey],
           let chosen = AVSpeechSynthesisVoice(identifier: identifier) {
            return chosen
        }
        return Self.voices(for: language).first
    }

    /// Menu labels keyed by identifier. Names are not unique, since the eloquence
    /// voices exist in both en-GB and en-US, so only the ambiguous ones get a region.
    static func labels(for voices: [AVSpeechSynthesisVoice]) -> [String: String] {
        var counts: [String: Int] = [:]
        for voice in voices { counts[voice.name, default: 0] += 1 }

        var labels: [String: String] = [:]
        for voice in voices {
            var label = voice.name
            if (counts[voice.name] ?? 0) > 1,
               let region = Locale(identifier: voice.language).region?.identifier {
                label += " (\(region))"
            }
            switch voice.quality {
            case .enhanced: label += " (Enhanced)"
            case .premium: label += " (Premium)"
            default: break
            }
            labels[voice.identifier] = label
        }
        return labels
    }

    static func openVoiceSettings() {
        let settings = "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?SpokenContent"
        guard let url = URL(string: settings) else { return }
        NSWorkspace.shared.open(url)
    }

    var progressText: String {
        chunks.isEmpty ? "" : "\(min(currentIndex + 1, chunks.count)) / \(chunks.count)"
    }

    /// Spelled out for the tooltip, since "8 / 27" does not say what the unit is.
    var progressDescription: String {
        chunks.isEmpty ? "" : "Block \(min(currentIndex + 1, chunks.count)) of \(chunks.count)"
    }

    var progress: Double {
        totalCharacters > 0 ? Double(spokenCharacters) / Double(totalCharacters) : 0
    }

    func start(in webView: WKWebView) {
        stop()
        self.webView = webView
        webView.evaluateJavaScript("extractSpeechChunks()") { [weak self] result, _ in
            guard let self,
                  let json = result as? String,
                  let data = json.data(using: .utf8),
                  let chunks = try? JSONDecoder().decode([String].self, from: data),
                  !chunks.isEmpty
            else { return }

            // The document's language, not the system's. Someone on a German Mac
            // reading an English file needs an English voice.
            let language = Self.detectLanguage(in: chunks)
            self.language = language
            guard let voice = self.resolveVoice() else {
                self.unsupportedLanguage = self.languageName
                return
            }

            self.chunks = chunks
            self.voice = voice
            self.indexCharacters()
            self.speak(from: 0)
        }
    }

    private func indexCharacters() {
        characterOffsets.removeAll(keepingCapacity: true)
        var running = 0
        for chunk in chunks {
            characterOffsets.append(running)
            running += chunk.utf16.count
        }
        totalCharacters = running
    }

    /// Seeks to the block containing `fraction` of the document. The synthesizer
    /// cannot seek inside an utterance, so this lands on a block boundary.
    func seek(to fraction: Double) {
        guard isSpeaking, totalCharacters > 0 else { return }
        let target = Int(Double(totalCharacters) * min(max(fraction, 0), 1))
        let index = characterOffsets.lastIndex { $0 <= target } ?? 0
        move(to: index)
    }

    /// Queues from `index` to the end. Requeuing is the only way to change pace or
    /// position, since an utterance keeps the rate it was created with and the
    /// synthesizer cannot seek.
    private func speak(from index: Int) {
        synthesizer.stopSpeaking(at: .immediate)
        utterances.removeAll()
        guard let voice, chunks.indices.contains(index) else { return }
        for chunk in chunks[index...] {
            let utterance = AVSpeechUtterance(string: chunk)
            utterance.voice = voice
            utterance.rate = rate
            utterances.append(utterance)
            synthesizer.speak(utterance)
        }
        queueBase = index
        currentIndex = index
        spokenCharacters = characterOffsets.indices.contains(index) ? characterOffsets[index] : 0
        needsRequeue = false
        isSpeaking = true
        isPaused = false
    }

    /// Moves to a block. While paused the queue is left alone and the change is
    /// applied on resume, since requeuing starts speaking immediately.
    private func move(to index: Int) {
        guard chunks.indices.contains(index) else { return }
        guard isPaused else { return speak(from: index) }
        needsRequeue = true
        currentIndex = index
        spokenCharacters = characterOffsets[index]
        // Zero length, so the block is marked without a word inside it.
        webView?.evaluateJavaScript("highlightSpeech(\(index), 0, 0)")
    }

    func skipForward() {
        guard isSpeaking else { return }
        currentIndex + 1 < chunks.count ? move(to: currentIndex + 1) : stop()
    }

    func skipBackward() {
        guard isSpeaking else { return }
        move(to: max(currentIndex - 1, 0))
    }

    /// Nearest match, so a rate persisted by an earlier build still resolves.
    var speedIndex: Int {
        Self.speeds.enumerated()
            .min { abs($0.element.rate - rate) < abs($1.element.rate - rate) }?.offset ?? 3
    }

    func setSpeed(index: Int) {
        guard Self.speeds.indices.contains(index) else { return }
        setRate(Self.speeds[index].rate)
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        UserDefaults.standard.set(newRate, forKey: Self.rateKey)
        guard isSpeaking else { return }
        if isPaused { needsRequeue = true } else { speak(from: currentIndex) }
    }

    /// The dominant language of the document, falling back to the system language
    /// when detection is not confident enough to trust.
    private static func detectLanguage(in chunks: [String]) -> String {
        let fallback = Locale.preferredLanguages.first ?? "en-US"
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(chunks.prefix(20).joined(separator: " "))
        guard let dominant = recognizer.dominantLanguage,
              let confidence = recognizer.languageHypotheses(withMaximum: 1)[dominant],
              confidence > 0.6
        else { return fallback }
        // Detection yields a bare language, so keep the system region when it agrees.
        return fallback.hasPrefix(dominant.rawValue) ? fallback : dominant.rawValue
    }

    /// Eligible voices for a language, best first.
    ///
    /// Ranked by quality, then exact locale, then the Siri family. The identifier
    /// tiebreak is only for stability. Novelty voices are never eligible.
    static func voices(for language: String) -> [AVSpeechSynthesisVoice] {
        func rank(_ voice: AVSpeechSynthesisVoice) -> (Int, Int, Int, String) {
            (voice.quality.rawValue,
             voice.language == language ? 1 : 0,
             voice.identifier.hasPrefix(siriPrefix) ? 1 : 0,
             voice.identifier)
        }
        let prefix = String(language.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { !$0.identifier.hasPrefix(noveltyPrefix) && $0.language.hasPrefix(prefix) }
            .sorted { rank($0) > rank($1) }
    }

    func pause() {
        guard isSpeaking, !isPaused else { return }
        // The synthesizer's own isPaused only flips some time later, so drive the
        // UI from our state and never read it back.
        _ = synthesizer.pauseSpeaking(at: .word)
        isPaused = true
    }

    func resume() {
        guard isPaused else { return }
        // A change made while paused was deferred, so the queue is rebuilt now.
        guard !needsRequeue else { return speak(from: currentIndex) }
        _ = synthesizer.continueSpeaking()
        isPaused = false
    }

    /// Stops when the window showing the spoken preview goes away.
    func stopIfSpeaking(in window: NSWindow?) {
        guard let window, webView?.window === window else { return }
        stop()
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        utterances.removeAll()
        chunks.removeAll()
        needsRequeue = false
        characterOffsets.removeAll()
        totalCharacters = 0
        spokenCharacters = 0
        queueBase = 0
        currentIndex = 0
        webView?.evaluateJavaScript("clearSpeechHighlight()")
        isSpeaking = false
        isPaused = false
    }

    // MARK: - AVSpeechSynthesizerDelegate

    /// Character ranges are UTF-16 offsets into the chunk, which is exactly how
    /// JavaScript indexes strings, so they cross the bridge untranslated.
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        // Identify by address rather than capturing the utterance, which is not
        // Sendable. The queue holds a strong reference, so no address is recycled
        // while a lookup can still happen.
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard let position = self.utterances.firstIndex(where: { ObjectIdentifier($0) == id }),
                  let webView = self.webView
            else { return }
            let index = self.queueBase + position
            self.currentIndex = index
            // Offset inside the block, so the bar fills continuously instead of
            // jumping once per paragraph.
            if self.characterOffsets.indices.contains(index) {
                self.spokenCharacters = self.characterOffsets[index] + characterRange.location
            }
            _ = try? await webView.evaluateJavaScript(
                "highlightSpeech(\(index), \(characterRange.location), \(characterRange.length))"
            )
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        // isSpeaking reads false in this callback even while later chunks are still
        // queued, so it cannot decide when playback is over. Position in the queue can.
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard let last = self.utterances.last, ObjectIdentifier(last) == id else { return }
            _ = try? await self.webView?.evaluateJavaScript("clearSpeechHighlight()")
            self.utterances.removeAll()
            self.isSpeaking = false
            self.isPaused = false
        }
    }
}
