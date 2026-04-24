//
//  CostPopoverView.swift
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

struct CostPopoverView: View {
    let tokens: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimated Input Cost")
                .font(.headline)

            Text("\(formatNumber(tokens)) tokens (est.)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                ForEach(ModelPricing.models) { model in
                    GridRow {
                        Text(model.name)
                            .font(.system(size: 12))
                        Text(formatCost(model.cost(for: tokens)))
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    if let footnote = model.footnote {
                        GridRow {
                            Text(footnote)
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                                .gridCellColumns(2)
                        }
                    }
                }
            }

            Divider()

            Text("Prices as of \(ModelPricing.pricingDate) \u{00b7} Token count is approximate for non-OpenAI models")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(width: 280)
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private func formatNumber(_ n: Int) -> String {
        Self.numberFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func formatCost(_ cost: Double) -> String {
        if cost < 0.001 {
            return cost == 0 ? "$0.0000" : String(format: "$%.4f", cost)
        }
        return String(format: "$%.4f", cost)
    }
}
