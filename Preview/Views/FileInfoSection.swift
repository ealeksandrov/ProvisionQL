//
//  FileInfoSection.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import SwiftUI

struct FileInfo: Hashable {
    let fileName: String
    let fileSize: String
    let modificationDate: String

    init(fileURL: URL) {
        fileName = fileURL.lastPathComponent

        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        fileSize = Self.formattedFileSize(for: fileURL, attributes: attributes)
        modificationDate = Self.formattedModificationDate(from: attributes)
    }
}

struct FileInfoSection: View {
    let fileInfo: FileInfo

    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Padding.small) {
            Text(fileInfo.fileName)
                .codeText()

            Text("\(fileInfo.fileSize), Modified \(fileInfo.modificationDate)")
                .codeText(.subheadline)
                .foregroundColor(.secondary)
        }
        .sectionBackground()
    }
}

private extension FileInfo {
    static func formattedFileSize(for fileURL: URL, attributes: [FileAttributeKey: Any]?) -> String {
        let size: Int64

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
           isDirectory.boolValue
        {
            size = calculateDirectorySize(at: fileURL)
        } else if let fileSize = attributes?[.size] as? NSNumber {
            size = fileSize.int64Value
        } else {
            return "Unknown size"
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    static func formattedModificationDate(from attributes: [FileAttributeKey: Any]?) -> String {
        guard let date = attributes?[.modificationDate] as? Date else {
            return "Unknown date"
        }

        return date.formatted(date: .long, time: .standard)
    }

    static func calculateDirectorySize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0

        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                if let isRegularFile = resourceValues.isRegularFile,
                   isRegularFile,
                   let fileSize = resourceValues.fileSize
                {
                    totalSize += Int64(fileSize)
                }
            } catch {
                // Skip files that can't be accessed
                continue
            }
        }

        return totalSize
    }
}
