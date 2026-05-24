//
//  ProvisioningProfileExtractor.swift
//  ProvisionQLCore
//
//  Created by Evgeny Aleksandrov

import Foundation
import ZIPFoundation

/// Utilities for extracting embedded provisioning profiles
enum ProvisioningProfileExtractor {
    private static let embeddedProvisioningProfileName = "embedded.mobileprovision"

    // MARK: - Archive Extraction

    /// Extracts an embedded provisioning profile from an archive
    /// - Parameters:
    ///   - archive: The ZIP archive
    ///   - appBundlePath: The path to the app bundle within the archive
    /// - Returns: The extraction result
    static func extractFromArchive(_ archive: Archive, appBundlePath: String) -> EmbeddedProvisioningProfileExtraction {
        let profilePath = appBundlePath + embeddedProvisioningProfileName

        guard let profileData = try? ArchiveUtilities.extractFile(from: archive, path: profilePath) else {
            return .missing
        }

        // Create a temporary file to parse the provisioning profile
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

    // MARK: - Directory Extraction

    /// Extracts an embedded provisioning profile from a directory
    /// - Parameter directoryURL: The URL to the app bundle directory
    /// - Returns: The extraction result
    static func extractFromDirectory(_ directoryURL: URL) -> EmbeddedProvisioningProfileExtraction {
        let profileURL = directoryURL.appendingPathComponent(embeddedProvisioningProfileName)

        guard FileManager.default.fileExists(atPath: profileURL.path) else {
            return .missing
        }

        do {
            let provisioningInfo = try ProvisioningParser.parse(profileURL)
            return .success(provisioningInfo)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Helper Methods

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
