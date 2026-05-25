//
//  ProvisioningProfileExtractor.swift
//  ProvisionQLCore
//
//  Created by Evgeny Aleksandrov

import Foundation

/// Utilities for extracting embedded provisioning profiles
enum ProvisioningProfileExtractor {
    static let embeddedProvisioningProfilePaths = [
        "Contents/embedded.provisionprofile",
        "embedded.mobileprovision",
        "embedded.provisionprofile"
    ]

    // MARK: - Helper Methods

    static func extract(from profileData: Data) -> EmbeddedProvisioningProfileExtraction {
        parseProfileData(profileData)
    }

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
