//
//  ArchiveUtilities.swift
//  ProvisionQLCore
//
//  Created by Evgeny Aleksandrov

import Foundation
import ZIPFoundation

/// Utilities for working with ZIP archives
enum ArchiveUtilities {
    // MARK: - Archive Entry Extraction

    /// Extracts data from a specific file in the archive
    /// - Parameters:
    ///   - archive: The ZIP archive
    ///   - path: The path to the file within the archive
    /// - Returns: The extracted data
    /// - Throws: ParsingError if the file cannot be found or extracted
    static func extractFile(from archive: Archive, path: String) throws -> Data {
        guard let entry = archive[path] else {
            throw ParsingError.archiveExtractionFailed
        }

        return try extractData(from: entry, in: archive)
    }

    /// Extracts data from a specific file in the archive with case-insensitive search
    /// - Parameters:
    ///   - archive: The ZIP archive
    ///   - path: The path to the file within the archive
    /// - Returns: The extracted data if found, nil otherwise
    /// - Throws: Error if extraction fails
    static func extractFileOptional(from archive: Archive, path: String) throws -> Data? {
        // Try exact match first
        if let entry = archive[path] {
            return try extractData(from: entry, in: archive)
        }

        // Try case-insensitive search
        for entry in archive {
            if entry.path.lowercased() == path.lowercased() {
                return try extractData(from: entry, in: archive)
            }
        }

        return nil
    }

    /// Extracts data from an archive entry
    /// - Parameters:
    ///   - entry: The archive entry
    ///   - archive: The archive containing the entry
    /// - Returns: The extracted data
    /// - Throws: Error if extraction fails
    private static func extractData(from entry: Entry, in archive: Archive) throws -> Data {
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }

    // MARK: - App Bundle Path Finding

    /// Finds the app bundle path in an archive
    /// - Parameters:
    ///   - archive: The ZIP archive
    ///   - archiveType: The type of archive (IPA or XCArchive)
    /// - Returns: The app bundle path
    /// - Throws: ParsingError if no app bundle is found
    static func findAppBundlePath(in archive: Archive, archiveType: ArchiveType) throws -> String {
        switch archiveType {
        case .ipa:
            // Look for Payload/*.app/
            for entry in archive {
                if entry.path.hasPrefix("Payload/"), entry.path.hasSuffix(".app/") {
                    return entry.path
                }
            }

            // Some IPA creators omit directory entries and only include files under Payload/*.app/.
            if let appBundlePath = findAppBundlePathFlexible(in: archive) {
                return appBundlePath + "/"
            }
        case .xcarchive:
            // Look for Products/Applications/*.app/
            for entry in archive {
                if entry.path.hasPrefix("Products/Applications/"), entry.path.hasSuffix(".app/") {
                    return entry.path
                }
            }
        }

        throw ParsingError.invalidAppBundle
    }

    /// Finds the app bundle path in an IPA archive with more flexible matching
    /// - Parameter archive: The ZIP archive
    /// - Returns: The app bundle path if found, nil otherwise
    static func findAppBundlePathFlexible(in archive: Archive) -> String? {
        for entry in archive {
            let path = entry.path
            if path.hasPrefix("Payload/"), path.hasSuffix(".app/") {
                return String(path.dropLast()) // Remove trailing slash
            }
            if path.hasPrefix("Payload/"), path.contains(".app/") {
                let components = path.components(separatedBy: "/")
                if let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) {
                    return components[0 ... appIndex].joined(separator: "/")
                }
            }
        }
        return nil
    }

    // MARK: - ArchiveType

    enum ArchiveType {
        case ipa
        case xcarchive
    }
}
