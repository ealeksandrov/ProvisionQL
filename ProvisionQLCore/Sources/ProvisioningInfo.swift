//
//  ProvisioningInfo.swift
//  Core
//
//  Created by Evgeny Aleksandrov

import Foundation

public struct ProvisioningInfo: Sendable, Codable, Hashable {
    private static let expiringThreshold: TimeInterval = 30 * 86400

    public let uuid: String
    public let name: String
    public let teamName: String
    public let teamID: String
    public let appID: String
    public let expirationDate: Date
    public let creationDate: Date
    public let devices: [String]?
    public let certificates: [CertificateInfo]
    public let entitlements: [String: PlistValue]
    public let profileType: ProfileType
    public let platform: [Platform]
    public let diagnostics: [ProvisioningDiagnostic]

    @frozen
    public enum ProfileType: String, Codable, Sendable {
        case development = "Development"
        case adHoc = "Distribution (Ad Hoc)"
        case appStore = "Distribution (App Store)"
        case enterprise = "Enterprise"
    }

    @frozen
    public enum Platform: RawRepresentable, Codable, Sendable, Hashable {
        case iOS
        case macOS
        case tvOS
        case watchOS
        case visionOS
        case unknown(String)

        public var rawValue: String {
            switch self {
            case .iOS:
                "iOS"
            case .macOS:
                "macOS"
            case .tvOS:
                "tvOS"
            case .watchOS:
                "watchOS"
            case .visionOS:
                "visionOS"
            case .unknown(let platform):
                platform
            }
        }

        public init?(rawValue: String) {
            self = switch rawValue {
            case "iOS":
                .iOS
            case "macOS", "OSX":
                .macOS
            case "tvOS":
                .tvOS
            case "watchOS":
                .watchOS
            case "visionOS":
                .visionOS
            default:
                .unknown(rawValue)
            }
        }
    }

    public var expirationStatus: ExpirationStatus {
        let now = Date()
        if expirationDate < now {
            return .expired
        }

        let secondsUntilExpiration = expirationDate.timeIntervalSince(now)
        if secondsUntilExpiration < Self.expiringThreshold {
            return .expiring
        }

        return .valid
    }
}

extension ProvisioningInfo {
    init(from profile: RawProfile) throws {
        let missingFields = Self.missingRequiredFields(in: profile)
        guard
            missingFields.isEmpty,
            let uuid = Self.nonEmpty(profile.UUID),
            let name = Self.nonEmpty(profile.Name),
            let teamName = Self.nonEmpty(profile.TeamName),
            let teamID = Self.firstNonEmpty(profile.TeamIdentifier),
            let appID = Self.nonEmpty(profile.AppIDName),
            let entitlements = profile.Entitlements,
            let expirationDate = profile.ExpirationDate,
            let creationDate = profile.CreationDate
        else {
            throw ProvisioningProfileValidationError(missingFields: missingFields)
        }

        self.uuid = uuid
        self.name = name
        self.teamName = teamName
        self.teamID = teamID
        self.appID = appID
        self.expirationDate = expirationDate
        self.creationDate = creationDate
        devices = profile.ProvisionedDevices
        self.entitlements = entitlements

        var diagnostics: [ProvisioningDiagnostic] = []

        // Process certificates
        var certificateInfos: [CertificateInfo] = []
        if let certData = profile.DeveloperCertificates {
            for data in certData {
                if let certInfo = CertificateInfo.from(data: data) {
                    certificateInfos.append(certInfo)
                } else {
                    diagnostics.append(.init(
                        severity: .warning,
                        code: .invalidDeveloperCertificate,
                        message: "A developer certificate could not be decoded and was skipped."
                    ))
                }
            }
        }
        certificates = certificateInfos

        // Determine profile type
        let hasDevices = profile.ProvisionedDevices != nil
        let getTaskAllow: Bool = {
            if case .bool(let value) = entitlements["get-task-allow"] {
                return value
            }
            return false
        }()
        let isEnterprise = profile.ProvisionsAllDevices ?? false

        if hasDevices {
            if getTaskAllow {
                profileType = .development
            } else {
                profileType = .adHoc
            }
        } else {
            if isEnterprise {
                profileType = .enterprise
            } else {
                profileType = .appStore
            }
        }

        // Determine platform
        let platforms = profile.Platform?.compactMap { platformString in
            Platform(rawValue: platformString)
        } ?? []
        if platforms.isEmpty {
            diagnostics.append(.init(
                severity: .warning,
                code: .missingPlatform,
                message: "Platform is missing; defaulting to iOS."
            ))
            platform = [.iOS]
        } else {
            platform = platforms
        }

        self.diagnostics = diagnostics
    }

    private static func missingRequiredFields(in profile: RawProfile) -> [String] {
        var fields: [String] = []

        if nonEmpty(profile.UUID) == nil {
            fields.append("UUID")
        }
        if nonEmpty(profile.Name) == nil {
            fields.append("Name")
        }
        if nonEmpty(profile.TeamName) == nil {
            fields.append("TeamName")
        }
        if firstNonEmpty(profile.TeamIdentifier) == nil {
            fields.append("TeamIdentifier")
        }
        if nonEmpty(profile.AppIDName) == nil {
            fields.append("AppIDName")
        }
        if profile.Entitlements == nil {
            fields.append("Entitlements")
        }
        if profile.ExpirationDate == nil {
            fields.append("ExpirationDate")
        }
        if profile.CreationDate == nil {
            fields.append("CreationDate")
        }

        return fields
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard
            let value,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return value
    }

    private static func firstNonEmpty(_ values: [String]?) -> String? {
        values?.compactMap(nonEmpty).first
    }
}
