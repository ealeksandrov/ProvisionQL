//
//  ProvisioningProfileExtractor.swift
//  ProvisionQLCore
//
//  Created by Evgeny Aleksandrov

import Foundation
import ZIPFoundation

/// Utilities for extracting embedded provisioning profiles
enum ProvisioningProfileExtractor {
    private static let embeddedProvisioningProfilePaths = [
        "Contents/embedded.provisionprofile",
        "embedded.mobileprovision",
        "embedded.provisionprofile"
    ]

    // MARK: - Archive Extraction

    /// Extracts an embedded provisioning profile from an archive
    /// - Parameters:
    ///   - archive: The ZIP archive
    ///   - appBundlePath: The path to the app bundle within the archive
    /// - Returns: The extraction result
    static func extractFromArchive(_ archive: Archive, appBundlePath: String) -> EmbeddedProvisioningProfileExtraction {
        for relativePath in embeddedProvisioningProfilePaths {
            let profilePath = archivePath(appBundlePath: appBundlePath, relativePath: relativePath)
            if let profileData = try? ArchiveUtilities.extractFile(from: archive, path: profilePath) {
                return parseProfileData(profileData)
            }
        }

        return .missing
    }

    // MARK: - Directory Extraction

    /// Extracts an embedded provisioning profile from a directory
    /// - Parameter directoryURL: The URL to the app bundle directory
    /// - Returns: The extraction result
    static func extractFromDirectory(_ directoryURL: URL) -> EmbeddedProvisioningProfileExtraction {
        for relativePath in embeddedProvisioningProfilePaths {
            let profileURL = directoryURL.appendingPathComponent(relativePath)

            guard FileManager.default.fileExists(atPath: profileURL.path) else {
                continue
            }

            do {
                let provisioningInfo = try ProvisioningParser.parse(profileURL)
                return .success(provisioningInfo)
            } catch {
                return .failure(error)
            }
        }

        return .missing
    }

    // MARK: - Helper Methods

    private static func parseProfileData(_ profileData: Data) -> EmbeddedProvisioningProfileExtraction {
        let tempURL = createTemporaryURL()

        do {
            try profileData.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let provisioningInfo = try ProvisioningParser.parse(tempURL)
            return .success(provisioningInfo)
        } catch {
            return .failure(error)
        }
    }

    private static func archivePath(appBundlePath: String, relativePath: String) -> String {
        if appBundlePath.hasSuffix("/") {
            return appBundlePath + relativePath
        }

        return appBundlePath + "/" + relativePath
    }

    /// Creates a temporary URL for storing provisioning profile data
    private static func createTemporaryURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mobileprovision")
    }
}

struct EmbeddedProvisioningProfileExtraction {
    let profile: ProvisioningInfo?
    let diagnostics: [AppDiagnostic]

    static let missing = Self(profile: nil, diagnostics: [])

    static func success(_ profile: ProvisioningInfo) -> Self {
        Self(profile: profile, diagnostics: [])
    }

    static func failure(_ error: Error) -> Self {
        Self(
            profile: nil,
            diagnostics: [
                AppDiagnostic(
                    severity: .warning,
                    code: .malformedEmbeddedProvisioningProfile,
                    message: "Embedded provisioning profile could not be parsed: \(error.localizedDescription)"
                )
            ]
        )
    }
}
