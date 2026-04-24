//
//  StatusBarView.swift
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

struct StatusBarView: View {
    let stats: DocumentStats
    @State private var showCostPopover = false
    @State private var isCostHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            HStack(spacing: 6) {
                Text(formatNumber(stats.words))
                    .foregroundStyle(.secondary)
                + Text(" words")
                    .foregroundStyle(.tertiary)

                separator

                Text(formatNumber(stats.characters))
                    .foregroundStyle(.secondary)
                + Text(" chars")
                    .foregroundStyle(.tertiary)

                separator

                Text(formatNumber(stats.tokens))
                    .foregroundStyle(.secondary)
                + Text(" tokens")
                    .foregroundStyle(.tertiary)

                separator

                Button {
                    showCostPopover.toggle()
                } label: {
                    HStack(spacing: 2) {
                        Text(formatCost(stats.defaultCost))
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(isCostHovered ? .primary : .secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(isCostHovered ? Color.primary.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isCostHovered = hovering
                }
                .popover(isPresented: $showCostPopover) {
                    CostPopoverView(tokens: stats.tokens)
                }
            }
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 30)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var separator: some View {
        Text(" \u{00b7} ")
            .foregroundStyle(.quaternary)
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
            return cost == 0 ? "$0.00" : String(format: "$%.4f", cost)
        }
        return String(format: "$%.3f", cost)
    }
}
