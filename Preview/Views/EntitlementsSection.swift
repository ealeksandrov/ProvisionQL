//
//  EntitlementsSection.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import ProvisionQLCore
import SwiftUI

struct EntitlementsSection: View {
    let entitlements: [String: PlistValue]

    private static let iso8601DateFormatter = ISO8601DateFormatter()

    var body: some View {
        Text(formattedEntitlements)
            .codeText()
            .sectionBackground()
    }
}

private extension EntitlementsSection {
    var sortedEntitlements: [(key: String, value: PlistValue)] {
        entitlements.sorted { $0.key < $1.key }
    }

    var formattedEntitlements: String {
        var result = ""

        for (key, value) in sortedEntitlements {
            result += "\(key) = \(formatValue(value))\n"
        }

        return result.trimmingCharacters(in: .newlines)
    }

    func formatValue(_ value: PlistValue, indentationLevel: Int = 0) -> String {
        switch value {
        case .string(let str):
            return str
        case .bool(let bool):
            return bool ? "true" : "false"
        case .integer(let integer):
            return String(integer)
        case .double(let double):
            return String(double)
        case .date(let date):
            return Self.iso8601DateFormatter.string(from: date)
        case .data(let data):
            return "<\(data.count) bytes>"
        case .array(let array):
            if array.isEmpty {
                return "()"
            }

            let nextIndent = indentation(level: indentationLevel + 1)
            var result = "(\n"
            for item in array {
                result += "\(nextIndent)\(formatValue(item, indentationLevel: indentationLevel + 1))\n"
            }
            result += "\(indentation(level: indentationLevel)))"
            return result
        case .dictionary(let dict):
            if dict.isEmpty {
                return "{}"
            }

            let nextIndent = indentation(level: indentationLevel + 1)
            var result = "{\n"
            for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                result += "\(nextIndent)\(key) = \(formatValue(value, indentationLevel: indentationLevel + 1))\n"
            }
            result += "\(indentation(level: indentationLevel))}"
            return result
        }
    }

    func indentation(level: Int) -> String {
        String(repeating: "    ", count: level)
    }
}
