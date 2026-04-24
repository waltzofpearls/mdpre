//
//  CostPopoverView.swift
//  MDPre
//
//  Created by waltzofpearls on 2026-04-23.
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
