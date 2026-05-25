//
//  RawProfile.swift
//  Core
//
//  Created by Evgeny Aleksandrov

import Foundation

struct RawProfile: Codable {
    let UUID: String?
    let Name: String?
    let TeamName: String?
    let TeamIdentifier: [String]?
    let AppIDName: String?
    let Entitlements: [String: PlistValue]?
    let ExpirationDate: Date?
    let CreationDate: Date?
    let DeveloperCertificates: [Data]?
    let ProvisionedDevices: [String]?
    let ProvisionsAllDevices: Bool?
    let Platform: [String]?
    let ProfileType: String?

    init(
        UUID: String?,
        Name: String?,
        TeamName: String?,
        TeamIdentifier: [String]?,
        AppIDName: String?,
        Entitlements: [String: PlistValue]?,
        ExpirationDate: Date?,
        CreationDate: Date?,
        DeveloperCertificates: [Data]?,
        ProvisionedDevices: [String]?,
        ProvisionsAllDevices: Bool?,
        Platform: [String]?,
        ProfileType: String? = nil
    ) {
        self.UUID = UUID
        self.Name = Name
        self.TeamName = TeamName
        self.TeamIdentifier = TeamIdentifier
        self.AppIDName = AppIDName
        self.Entitlements = Entitlements
        self.ExpirationDate = ExpirationDate
        self.CreationDate = CreationDate
        self.DeveloperCertificates = DeveloperCertificates
        self.ProvisionedDevices = ProvisionedDevices
        self.ProvisionsAllDevices = ProvisionsAllDevices
        self.Platform = Platform
        self.ProfileType = ProfileType
    }
}
