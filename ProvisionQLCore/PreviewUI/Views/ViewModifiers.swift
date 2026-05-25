//
//  ViewModifiers.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import SwiftUI

struct SectionBackgroundModifier: ViewModifier {
    let verticalPadding: CGFloat
    let horizontalPadding: CGFloat
    let cornerRadius: CGFloat

    init(
        verticalPadding: CGFloat = UIConstants.Padding.standard,
        horizontalPadding: CGFloat = UIConstants.Padding.large,
        cornerRadius: CGFloat = UIConstants.CornerRadius.standard
    ) {
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(cornerRadius)
    }
}

struct CodeTextModifier: ViewModifier {
    let size: Font.TextStyle

    init(size: Font.TextStyle = .body) {
        self.size = size
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size, design: .monospaced))
            .textSelection(.enabled)
    }
}

extension View {
    func sectionBackground(
        verticalPadding: CGFloat = UIConstants.Padding.standard,
        horizontalPadding: CGFloat = UIConstants.Padding.large,
        cornerRadius: CGFloat = UIConstants.CornerRadius.standard
    ) -> some View {
        modifier(SectionBackgroundModifier(
            verticalPadding: verticalPadding,
            horizontalPadding: horizontalPadding,
            cornerRadius: cornerRadius
        ))
    }

    func codeText(_ size: Font.TextStyle = .body) -> some View {
        modifier(CodeTextModifier(size: size))
    }
}

enum UIConstants {
    enum Padding {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let standard: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 6
        static let standard: CGFloat = 8
        static let large: CGFloat = 12
    }

    enum Size {
        static let iconSize: CGFloat = 64
        static let minLabelWidth: CGFloat = 100
    }

    enum Width {
        static let dateColumn: CGFloat = 150
    }

    enum Window {
        static let minWidth: CGFloat = 600
        static let minHeight: CGFloat = 400
    }

    enum Color {
        static let validGreen = SwiftUI.Color(red: 0.0, green: 0.6, blue: 0.0)
    }
}
