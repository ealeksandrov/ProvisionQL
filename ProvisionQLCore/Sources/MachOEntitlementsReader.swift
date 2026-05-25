import Foundation

enum MachOEntitlementsReader {
    static func extractEntitlements(from executableURL: URL) -> [String: PlistValue]? {
        guard let data = try? Data(contentsOf: executableURL, options: .mappedIfSafe) else {
            return nil
        }

        return extractEntitlements(from: data)
    }

    static func extractEntitlements(from data: Data) -> [String: PlistValue]? {
        guard !data.isEmpty else {
            return nil
        }

        if let slices = fatSlices(in: data) {
            for slice in slices {
                if let entitlements = extractEntitlements(from: data, slice: slice) {
                    return entitlements
                }
            }

            return nil
        }

        return extractEntitlements(from: data, slice: 0 ..< data.count)
    }
}

private extension MachOEntitlementsReader {
    static let fatMagic: UInt32 = 0xCAFE_BABE
    static let fatMagic64: UInt32 = 0xCAFE_BABF
    static let machMagic: UInt32 = 0xFEED_FACE
    static let machMagic64: UInt32 = 0xFEED_FACF
    static let machCigam: UInt32 = 0xCEFA_EDFE
    static let machCigam64: UInt32 = 0xCFFA_EDFE
    static let lcCodeSignature: UInt32 = 0x1D

    static let csMagicEmbeddedSignature: UInt32 = 0xFADE_0CC0
    static let csMagicEmbeddedEntitlements: UInt32 = 0xFADE_7171
    static let csSlotEntitlements: UInt32 = 5

    enum Endianness {
        case little
        case big
    }

    static func fatSlices(in data: Data) -> [Range<Int>]? {
        guard let magic = data.uint32(at: 0, endianness: .big) else {
            return nil
        }

        let isFat64: Bool
        switch magic {
        case fatMagic:
            isFat64 = false
        case fatMagic64:
            isFat64 = true
        default:
            return nil
        }

        guard let architectureCount = data.uint32(at: 4, endianness: .big) else {
            return nil
        }

        let entrySize = isFat64 ? 32 : 20
        var slices: [Range<Int>] = []

        for index in 0 ..< Int(architectureCount) {
            let entryOffset = 8 + index * entrySize
            let offset: UInt64?
            let size: UInt64?

            if isFat64 {
                offset = data.uint64(at: entryOffset + 8, endianness: .big)
                size = data.uint64(at: entryOffset + 16, endianness: .big)
            } else {
                offset = data.uint32(at: entryOffset + 8, endianness: .big).map(UInt64.init)
                size = data.uint32(at: entryOffset + 12, endianness: .big).map(UInt64.init)
            }

            guard let offset, let size else {
                continue
            }

            guard offset <= UInt64(data.count),
                  size <= UInt64(data.count) - offset
            else {
                continue
            }

            let lowerBound = Int(offset)
            let upperBound = Int(offset + size)
            slices.append(lowerBound ..< upperBound)
        }

        return slices
    }

    static func extractEntitlements(from data: Data, slice: Range<Int>) -> [String: PlistValue]? {
        guard
            let (endianness, is64Bit) = machHeader(in: data, slice: slice),
            let loadCommandCount = data.uint32(at: slice.lowerBound + 16, endianness: endianness)
        else {
            return nil
        }

        let headerSize = is64Bit ? 32 : 28
        var commandOffset = slice.lowerBound + headerSize

        for _ in 0 ..< Int(loadCommandCount) {
            guard
                let command = data.uint32(at: commandOffset, endianness: endianness),
                let commandSize = data.uint32(at: commandOffset + 4, endianness: endianness),
                commandSize >= 8
            else {
                return nil
            }

            if command == lcCodeSignature,
               let signatureOffset = data.uint32(at: commandOffset + 8, endianness: endianness),
               let signatureSize = data.uint32(at: commandOffset + 12, endianness: endianness)
            {
                let lowerBound = slice.lowerBound + Int(signatureOffset)
                let upperBound = lowerBound + Int(signatureSize)
                guard lowerBound >= slice.lowerBound, upperBound <= slice.upperBound else {
                    return nil
                }

                return extractEntitlements(fromCodeSignature: data, range: lowerBound ..< upperBound)
            }

            commandOffset += Int(commandSize)
            guard commandOffset <= slice.upperBound else {
                return nil
            }
        }

        return nil
    }

    static func machHeader(in data: Data, slice: Range<Int>) -> (Endianness, Bool)? {
        guard let littleEndianMagic = data.uint32(at: slice.lowerBound, endianness: .little) else {
            return nil
        }

        switch littleEndianMagic {
        case machMagic:
            return (.little, false)
        case machMagic64:
            return (.little, true)
        case machCigam:
            return (.big, false)
        case machCigam64:
            return (.big, true)
        default:
            return nil
        }
    }

    static func extractEntitlements(fromCodeSignature data: Data, range: Range<Int>) -> [String: PlistValue]? {
        guard let magic = data.uint32(at: range.lowerBound, endianness: .big) else {
            return nil
        }

        if magic == csMagicEmbeddedEntitlements {
            return parseEntitlementsBlob(in: data, at: range.lowerBound, limit: range.upperBound)
        }

        guard magic == csMagicEmbeddedSignature,
              let count = data.uint32(at: range.lowerBound + 8, endianness: .big)
        else {
            return nil
        }

        for index in 0 ..< Int(count) {
            let entryOffset = range.lowerBound + 12 + index * 8
            guard
                let type = data.uint32(at: entryOffset, endianness: .big),
                let blobOffset = data.uint32(at: entryOffset + 4, endianness: .big)
            else {
                continue
            }

            let absoluteBlobOffset = range.lowerBound + Int(blobOffset)
            guard absoluteBlobOffset < range.upperBound else {
                continue
            }

            if type == csSlotEntitlements,
               let entitlements = parseEntitlementsBlob(in: data, at: absoluteBlobOffset, limit: range.upperBound)
            {
                return entitlements
            }
        }

        return nil
    }

    static func parseEntitlementsBlob(in data: Data, at offset: Int, limit: Int) -> [String: PlistValue]? {
        guard
            data.uint32(at: offset, endianness: .big) == csMagicEmbeddedEntitlements,
            let length = data.uint32(at: offset + 4, endianness: .big)
        else {
            return nil
        }

        let plistStart = offset + 8
        let plistEnd = offset + Int(length)
        guard plistStart <= plistEnd, plistEnd <= limit else {
            return nil
        }

        let plistData = data.subdata(in: plistStart ..< plistEnd)
        guard
            let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
            let dictionary = plist as? [String: Any],
            let value = PlistValue.from(value: dictionary),
            case .dictionary(let entitlements) = value
        else {
            return nil
        }

        return entitlements
    }
}

private extension Data {
    var bounds: Range<Int> {
        startIndex ..< endIndex
    }

    func uint32(at offset: Int, endianness: MachOEntitlementsReader.Endianness) -> UInt32? {
        guard bounds.contains(offset), offset + 4 <= count else {
            return nil
        }

        let value = self[offset ..< offset + 4].reduce(UInt32(0)) { partialResult, byte in
            partialResult << 8 | UInt32(byte)
        }

        return switch endianness {
        case .big:
            value
        case .little:
            value.byteSwapped
        }
    }

    func uint64(at offset: Int, endianness: MachOEntitlementsReader.Endianness) -> UInt64? {
        guard bounds.contains(offset), offset + 8 <= count else {
            return nil
        }

        let value = self[offset ..< offset + 8].reduce(UInt64(0)) { partialResult, byte in
            partialResult << 8 | UInt64(byte)
        }

        return switch endianness {
        case .big:
            value
        case .little:
            value.byteSwapped
        }
    }
}
