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
        case developerID = "Developer ID"
        case directDistribution = "Direct Distribution"
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

        profileType = Self.profileType(for: profile, entitlements: entitlements)

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

    private static func profileType(for profile: RawProfile, entitlements: [String: PlistValue]) -> ProfileType {
        if let explicitType = ProfileType(profile.ProfileType) {
            return explicitType
        }

        let hasDevices = profile.ProvisionedDevices != nil
        let getTaskAllow: Bool = {
            if case .bool(let value) = entitlements["get-task-allow"] {
                return value
            }
            return false
        }()
        let isEnterprise = profile.ProvisionsAllDevices ?? false

        if hasDevices {
            return getTaskAllow ? .development : .adHoc
        } else {
            return isEnterprise ? .enterprise : .appStore
        }
    }
}

private extension ProvisioningInfo.ProfileType {
    init?(_ profileType: String?) {
        guard let profileType else {
            return nil
        }

        switch profileType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "IOS_APP_DEVELOPMENT", "MAC_APP_DEVELOPMENT", "TVOS_APP_DEVELOPMENT",
             "MAC_CATALYST_APP_DEVELOPMENT":
            self = .development
        case "IOS_APP_ADHOC", "TVOS_APP_ADHOC":
            self = .adHoc
        case "IOS_APP_STORE", "MAC_APP_STORE", "TVOS_APP_STORE", "MAC_CATALYST_APP_STORE":
            self = .appStore
        case "IOS_APP_INHOUSE", "TVOS_APP_INHOUSE":
            self = .enterprise
        case "DEVELOPER_ID", "MAC_APP_DEVELOPER_ID":
            self = .developerID
        case "MAC_APP_DIRECT", "MAC_CATALYST_APP_DIRECT", "DIRECT_DISTRIBUTION", "MAC_APP_DIRECT_DISTRIBUTION":
            self = .directDistribution
        default:
            return nil
        }
    }
}
