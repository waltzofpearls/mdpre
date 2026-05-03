//
//  DocumentStats.swift
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

import Foundation

struct DocumentStats {
    let words: Int
    let characters: Int
    let tokens: Int

    /// Default cost using Claude Sonnet 4.6 ($3.00/MTok)
    var defaultCost: Double {
        Double(tokens) / 1_000_000 * ModelPricing.defaultModel.inputPricePerMTok
    }

    static let empty = DocumentStats(words: 0, characters: 0, tokens: 0)

    static func compute(from text: String) -> DocumentStats {
        guard !text.isEmpty else { return .empty }

        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        let characters = text.count
        let tokens = TokenCounter.shared.countTokens(in: text)

        return DocumentStats(words: words, characters: characters, tokens: tokens)
    }
}

struct ModelPrice: Identifiable {
    let id = UUID()
    let name: String
    let inputPricePerMTok: Double
    let footnote: String?

    func cost(for tokens: Int) -> Double {
        Double(tokens) / 1_000_000 * inputPricePerMTok
    }
}

enum ModelPricing {
    static let defaultModel = ModelPrice(name: "Claude Sonnet 4.6", inputPricePerMTok: 3.00, footnote: nil)

    static let models: [ModelPrice] = [
        ModelPrice(name: "GPT-5.4", inputPricePerMTok: 2.50, footnote: nil),
        ModelPrice(name: "GPT-4.1-mini", inputPricePerMTok: 0.40, footnote: nil),
        ModelPrice(name: "GPT-4.1-nano", inputPricePerMTok: 0.10, footnote: nil),
        ModelPrice(name: "Claude Opus 4.7", inputPricePerMTok: 5.00,
                   footnote: "Uses a different tokenizer — actual cost may be up to 35% higher"),
        ModelPrice(name: "Claude Sonnet 4.6", inputPricePerMTok: 3.00, footnote: nil),
        ModelPrice(name: "Claude Haiku 4.5", inputPricePerMTok: 1.00, footnote: nil),
    ]

    static let pricingDate = "May 2026"
}
