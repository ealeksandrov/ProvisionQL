//
//  ProvisioningInfo.swift
//  Core
//
//  Created by Evgeny Aleksandrov

import Foundation

public struct ProvisioningInfo: Sendable, Codable, Hashable {
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

        let daysUntilExpiration = Calendar.current.dateComponents([.day], from: now, to: expirationDate).day ?? 0
        if daysUntilExpiration < 30 {
            return .expiring
        }

        return .valid
    }
}

extension ProvisioningInfo {
    init(from profile: RawProfile) {
        uuid = profile.UUID ?? "Unknown UUID"
        name = profile.Name ?? "Unknown"
        teamName = profile.TeamName ?? "Unknown Team"
        teamID = profile.TeamIdentifier?.first ?? "Unknown"
        appID = profile.AppIDName ?? "Unknown App"
        expirationDate = profile.ExpirationDate ?? Date.distantFuture
        creationDate = profile.CreationDate ?? Date.distantPast
        devices = profile.ProvisionedDevices

        // Process certificates
        var certificateInfos: [CertificateInfo] = []
        if let certData = profile.DeveloperCertificates {
            for data in certData {
                if let certInfo = CertificateInfo.from(data: data) {
                    certificateInfos.append(certInfo)
                }
            }
        }
        certificates = certificateInfos

        entitlements = profile.Entitlements ?? [:]

        // Determine profile type
        let hasDevices = profile.ProvisionedDevices != nil
        let getTaskAllow: Bool = {
            if case .bool(let value) = profile.Entitlements?["get-task-allow"] {
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
        platform = platforms.isEmpty ? [.iOS] : platforms
    }
}
