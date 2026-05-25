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
}
