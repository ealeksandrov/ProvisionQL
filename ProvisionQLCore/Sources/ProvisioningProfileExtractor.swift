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
        do {
            let provisioningInfo = try ProvisioningParser.parse(profileData)
            return .success(provisioningInfo)
        } catch {
            return .failure(error)
        }
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
