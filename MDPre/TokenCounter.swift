//
//  TokenCounter.swift
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

class TokenCounter {
    static let shared = TokenCounter()

    private var vocabulary: [Data: Int] = [:]
    private var regex: NSRegularExpression?
    private var isLoaded = false

    private init() {
        loadVocabulary()
    }

    func countTokens(in text: String) -> Int {
        guard isLoaded, let regex, !text.isEmpty else { return 0 }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: fullRange)

        var count = 0
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let chunk = text[range]
            let piece = Array(chunk.utf8)

            if piece.count == 1 {
                count += 1
            } else if let _ = vocabulary[Data(piece)] {
                count += 1
            } else {
                count += bytePairEncode(piece).count
            }
        }
        return count
    }

    // MARK: - Vocabulary Loading

    private func loadVocabulary() {
        guard let url = Bundle.main.url(forResource: "o200k_base", withExtension: "tiktoken"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        for line in content.split(separator: "\n") {
            let parts = line.split(separator: " ")
            guard parts.count == 2,
                  let data = Data(base64Encoded: String(parts[0])),
                  let rank = Int(parts[1]) else { continue }
            vocabulary[data] = rank
        }

        let pattern = #"[^\r\n\p{L}\p{N}]?[\p{Lu}\p{Lt}\p{Lm}\p{Lo}\p{M}]*[\p{Ll}\p{Lm}\p{Lo}\p{M}]+(?i:'s|'t|'re|'ve|'m|'ll|'d)?|[^\r\n\p{L}\p{N}]?[\p{Lu}\p{Lt}\p{Lm}\p{Lo}\p{M}]+[\p{Ll}\p{Lm}\p{Lo}\p{M}]*(?i:'s|'t|'re|'ve|'m|'ll|'d)?|\p{N}{1,3}| ?[^\s\p{L}\p{N}]++[\r\n]*|\s*[\r\n]|\s+(?!\S)|\s+"#
        regex = try? NSRegularExpression(pattern: pattern)
        isLoaded = !vocabulary.isEmpty && regex != nil
    }

    // MARK: - BPE Algorithm

    /// Port of tiktoken's byte_pair_encode for pieces < 100 bytes.
    private func bytePairEncode(_ piece: [UInt8]) -> [Int] {
        let merged = bytePairMerge(piece)
        var tokens: [Int] = []
        for i in 0..<(merged.count - 1) {
            let start = merged[i].0
            let end = merged[i + 1].0
            tokens.append(vocabulary[Data(piece[start..<end])]!)
        }
        return tokens
    }

    /// Port of tiktoken's _byte_pair_merge.
    private func bytePairMerge(_ piece: [UInt8]) -> [(Int, Int)] {
        var parts: [(Int, Int)] = [] // (position, rank of merging with next)
        parts.reserveCapacity(piece.count + 1)

        var minRank = (Int.max, Int.max) // (rank, index)
        for i in 0..<(piece.count - 1) {
            let rank = getRank(piece, start: i, end: i + 2)
            if rank < minRank.0 {
                minRank = (rank, i)
            }
            parts.append((i, rank))
        }
        parts.append((piece.count - 1, Int.max))
        parts.append((piece.count, Int.max))

        while minRank.0 != Int.max {
            let i = minRank.1

            if i > 0 {
                parts[i - 1].1 = getRankFromParts(piece, parts: parts, index: i - 1)
            }
            parts[i].1 = getRankFromParts(piece, parts: parts, index: i)
            parts.remove(at: i + 1)

            minRank = (Int.max, Int.max)
            for (idx, part) in parts[..<(parts.count - 1)].enumerated() {
                if part.1 < minRank.0 {
                    minRank = (part.1, idx)
                }
            }
        }
        return parts
    }

    private func getRank(_ piece: [UInt8], start: Int, end: Int) -> Int {
        guard end <= piece.count else { return Int.max }
        return vocabulary[Data(piece[start..<end])] ?? Int.max
    }

    private func getRankFromParts(_ piece: [UInt8], parts: [(Int, Int)], index: Int) -> Int {
        guard index + 3 < parts.count else { return Int.max }
        let start = parts[index].0
        let end = parts[index + 3].0
        return vocabulary[Data(piece[start..<end])] ?? Int.max
    }
}
