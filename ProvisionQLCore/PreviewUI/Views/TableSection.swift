//
//  TableSection.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import SwiftUI

protocol FilteredElement {
    func matching(_ filter: String) -> Bool
}

struct TableSection<Content: View, RowContent: View, Element: FilteredElement>: View {
    let header: Content
    let data: [Element]
    let rowContent: (Element) -> RowContent

    @State private var displayedData: [Element]
    @State private var filter = ""

    private let filterEnabled: Bool

    init(
        data: [Element],
        filterEnabled: Bool = false,
        @ViewBuilder header: () -> Content,
        @ViewBuilder rowContent: @escaping (Element) -> RowContent
    ) {
        self.header = header()
        self.data = data
        self.rowContent = rowContent
        self.filterEnabled = filterEnabled
        self.displayedData = data
    }

    var body: some View {
        if !data.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if filterEnabled {
                    TextField("Filter", text: self.$filter).padding(.bottom)
                }

                header
                    .padding(.horizontal, UIConstants.Padding.standard)
                    .padding(.vertical, UIConstants.Padding.medium)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: UIConstants.CornerRadius.medium,
                        topTrailingRadius: UIConstants.CornerRadius.medium
                    ))

                ForEach(displayedData.indices, id: \.self) { index in
                    TableRow(content: rowContent(displayedData[index]), isLast: index == displayedData.count - 1)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            ).onChange(of: self.filter) { _, newValue in
                self.updateSearch(filter: newValue)
            }
        }
    }

    // MARK: - Search
    private func updateSearch(filter: String) {
        if filter.isEmpty {
            self.displayedData = data
        } else {
            self.displayedData = data.filter { $0.matching(filter) }
        }
    }
}

struct TableRow<Content: View>: View {
    let content: Content
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, UIConstants.Padding.standard)
                .padding(.vertical, UIConstants.Padding.medium)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

            if !isLast {
                Divider()
                    .background(Color(nsColor: .separatorColor))
            }
        }
        .clipShape(UnevenRoundedRectangle(
            bottomLeadingRadius: isLast ? UIConstants.CornerRadius.medium : 0,
            bottomTrailingRadius: isLast ? UIConstants.CornerRadius.medium : 0
        ))
    }
}
