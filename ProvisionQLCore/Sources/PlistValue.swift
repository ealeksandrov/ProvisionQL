//
//  PlistValue.swift
//  Core
//
//  Created by Evgeny Aleksandrov

import Foundation

@frozen
public enum PlistValue: Sendable, Codable, Hashable {
    case string(String)
    case bool(Bool)
    case integer(Int64)
    case double(Double)
    case date(Date)
    case data(Data)
    case array([PlistValue])
    case dictionary([String: PlistValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Keep this representation untagged so it can decode directly from property lists. JSON is ambiguous for
        // Date/Data values, which encode as scalars and can decode as .double or .string with the default strategies.
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }

        if let intValue = try? container.decode(Int64.self) {
            self = .integer(intValue)
            return
        }

        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }

        if let dateValue = try? container.decode(Date.self) {
            self = .date(dateValue)
            return
        }

        if let dataValue = try? container.decode(Data.self) {
            self = .data(dataValue)
            return
        }

        if let arrayValue = try? container.decode([PlistValue].self) {
            self = .array(arrayValue)
            return
        }

        if let dictValue = try? container.decode([String: PlistValue].self) {
            self = .dictionary(dictValue)
            return
        }

        throw DecodingError.typeMismatch(
            PlistValue.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported entitlement value type"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .date(let value):
            try container.encode(value)
        case .data(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        }
    }
}

extension PlistValue {
    static func from(value: Any) -> PlistValue? {
        switch value {
        case let plistValue as PlistValue:
            return plistValue
        case let stringValue as String:
            return .string(stringValue)
        case let boolValue as Bool:
            return .bool(boolValue)
        case let intValue as Int64:
            return .integer(intValue)
        case let intValue as Int:
            return .integer(Int64(intValue))
        case let doubleValue as Double:
            return .double(doubleValue)
        case let numberValue as NSNumber:
            return from(number: numberValue)
        case let dateValue as Date:
            return .date(dateValue)
        case let dataValue as Data:
            return .data(dataValue)
        case let arrayValue as [PlistValue]:
            return .array(arrayValue)
        case let dictValue as [String: PlistValue]:
            return .dictionary(dictValue)
        case let mixedArray as [Any]:
            var array: [PlistValue] = []
            array.reserveCapacity(mixedArray.count)

            for item in mixedArray {
                guard let value = PlistValue.from(value: item) else {
                    return nil
                }
                array.append(value)
            }

            return .array(array)
        case let mixedDict as [String: Any]:
            var dictionary: [String: PlistValue] = [:]

            for (key, item) in mixedDict {
                guard let value = PlistValue.from(value: item) else {
                    return nil
                }
                dictionary[key] = value
            }

            return .dictionary(dictionary)
        default:
            return nil
        }
    }

    private static func from(number: NSNumber) -> PlistValue {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return .bool(number.boolValue)
        }

        switch String(cString: number.objCType) {
        case "f", "d":
            return .double(number.doubleValue)
        default:
            return .integer(number.int64Value)
        }
    }
}
