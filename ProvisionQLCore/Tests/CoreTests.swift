//
//  CoreTests.swift
//  CoreTests
//
//  Created by Evgeny Aleksandrov

import Foundation
@testable import ProvisionQLCore
import Testing

// MARK: - Tags

extension Tag {
    @Tag static var badgeInfo: Self
    @Tag static var provisioningInfo: Self
    @Tag static var parser: Self
    @Tag static var models: Self
    @Tag static var expiration: Self
}

// MARK: - Test Suites

@Suite("Core Framework Tests")
struct CoreTests {
    @Suite("BadgeInfo Tests", .tags(.badgeInfo, .models))
    struct BadgeInfoTests {
        @Test("BadgeInfo initialization with parameters")
        func badgeInfoInitialization() {
            let badgeInfo = BadgeInfo(
                deviceCount: 5,
                expirationStatus: .valid,
                profileType: .development
            )

            #expect(badgeInfo.deviceCount == 5)
            #expect(badgeInfo.expirationStatus == .valid)
            #expect(badgeInfo.profileType == .development)
        }

        @Test("BadgeInfo creation from ProvisioningInfo")
        func badgeInfoFromProvisioningInfo() {
            let mockProfile = RawProfile(
                UUID: "12345678-1234-1234-1234-123456789ABC",
                Name: "Test Profile",
                TeamName: "Test Team",
                TeamIdentifier: ["ABC123"],
                AppIDName: "Test App",
                Entitlements: ["get-task-allow": .bool(true)],
                ExpirationDate: Date().addingTimeInterval(86400 * 60), // 60 days from now
                CreationDate: Date(),
                DeveloperCertificates: nil,
                ProvisionedDevices: ["device1", "device2", "device3"],
                ProvisionsAllDevices: false,
                Platform: ["iOS"]
            )

            let provisioningInfo = ProvisioningInfo(from: mockProfile)
            let badgeInfo = BadgeInfo(from: provisioningInfo)

            #expect(badgeInfo.deviceCount == 3)
            #expect(badgeInfo.expirationStatus == .valid)
            #expect(badgeInfo.profileType == .development)
        }

        @Test("BadgeInfo with zero devices")
        func badgeInfoZeroDevices() {
            let mockProfile = RawProfile(
                UUID: "87654321-4321-4321-4321-ABCDEF123456",
                Name: "App Store Profile",
                TeamName: "Test Team",
                TeamIdentifier: ["ABC123"],
                AppIDName: "Test App",
                Entitlements: [:],
                ExpirationDate: Date().addingTimeInterval(86400 * 60),
                CreationDate: Date(),
                DeveloperCertificates: nil,
                ProvisionedDevices: nil,
                ProvisionsAllDevices: false,
                Platform: ["iOS"]
            )

            let provisioningInfo = ProvisioningInfo(from: mockProfile)
            let badgeInfo = BadgeInfo(from: provisioningInfo)

            #expect(badgeInfo.deviceCount == 0)
            #expect(badgeInfo.profileType == .appStore)
        }
    }

    @Suite("ProvisioningInfo Tests", .tags(.provisioningInfo, .models))
    struct ProvisioningInfoTests {
        @Test("ProvisioningInfo initialization from RawProfile")
        func provisioningInfoInitialization() {
            let expirationDate = Date().addingTimeInterval(86400 * 45) // 45 days from now
            let creationDate = Date().addingTimeInterval(-86400 * 30) // 30 days ago

            let mockProfile = RawProfile(
                UUID: "ABCDEF12-3456-7890-ABCD-EF1234567890",
                Name: "Test Development Profile",
                TeamName: "Test Team LLC",
                TeamIdentifier: ["ABCD123456"],
                AppIDName: "My Test App",
                Entitlements: [
                    "get-task-allow": .bool(true),
                    "application-identifier": .string("ABCD123456.com.test.app")
                ],
                ExpirationDate: expirationDate,
                CreationDate: creationDate,
                DeveloperCertificates: nil,
                ProvisionedDevices: ["device1", "device2"],
                ProvisionsAllDevices: false,
                Platform: ["iOS"]
            )

            let provisioningInfo = ProvisioningInfo(from: mockProfile)

            #expect(provisioningInfo.name == "Test Development Profile")
            #expect(provisioningInfo.teamName == "Test Team LLC")
            #expect(provisioningInfo.teamID == "ABCD123456")
            #expect(provisioningInfo.appID == "My Test App")
            #expect(provisioningInfo.expirationDate == expirationDate)
            #expect(provisioningInfo.creationDate == creationDate)
            #expect(provisioningInfo.devices?.count == 2)
            #expect(provisioningInfo.profileType == .development)
            #expect(provisioningInfo.platform == [.iOS])
        }

        @Test("Profile type detection", arguments: [
            (
                hasDevices: true,
                getTaskAllow: true,
                isEnterprise: false,
                expected: ProvisioningInfo.ProfileType.development
            ),
            (hasDevices: true, getTaskAllow: false, isEnterprise: false, expected: ProvisioningInfo.ProfileType.adHoc),
            (
                hasDevices: false,
                getTaskAllow: false,
                isEnterprise: true,
                expected: ProvisioningInfo.ProfileType.enterprise
            ),
            (
                hasDevices: false,
                getTaskAllow: false,
                isEnterprise: false,
                expected: ProvisioningInfo.ProfileType.appStore
            )
        ])
        func profileTypeDetection(
            hasDevices: Bool,
            getTaskAllow: Bool,
            isEnterprise: Bool,
            expected: ProvisioningInfo.ProfileType
        ) {
            let mockProfile = RawProfile(
                UUID: "FEDCBA09-8765-4321-FEDC-BA0987654321",
                Name: "Test Profile",
                TeamName: "Test Team",
                TeamIdentifier: ["ABC123"],
                AppIDName: "Test App",
                Entitlements: getTaskAllow ? ["get-task-allow": .bool(true)] : [:],
                ExpirationDate: Date().addingTimeInterval(86400),
                CreationDate: Date(),
                DeveloperCertificates: nil,
                ProvisionedDevices: hasDevices ? ["device1"] : nil,
                ProvisionsAllDevices: isEnterprise,
                Platform: ["iOS"]
            )

            let provisioningInfo = ProvisioningInfo(from: mockProfile)
            #expect(provisioningInfo.profileType == expected)
        }

        @Test("Platform detection", arguments: [
            (platformStrings: ["iOS"], expected: [ProvisioningInfo.Platform.iOS]),
            (platformStrings: ["macOS"], expected: [ProvisioningInfo.Platform.macOS]),
            (platformStrings: ["OSX"], expected: [ProvisioningInfo.Platform.iOS]),
            (platformStrings: ["tvOS"], expected: [ProvisioningInfo.Platform.tvOS]),
            (platformStrings: ["watchOS"], expected: [ProvisioningInfo.Platform.watchOS]),
            (platformStrings: ["visionOS"], expected: [ProvisioningInfo.Platform.visionOS]),
            (
                platformStrings: ["iOS", "macOS"],
                expected: [ProvisioningInfo.Platform.iOS, ProvisioningInfo.Platform.macOS]
            ),
            (platformStrings: ["unknown"], expected: [ProvisioningInfo.Platform.iOS]),
            (platformStrings: nil, expected: [ProvisioningInfo.Platform.iOS])
        ])
        func platformDetection(platformStrings: [String]?, expected: [ProvisioningInfo.Platform]) {
            let mockProfile = RawProfile(
                UUID: "11111111-2222-3333-4444-555555555555",
                Name: "Test Profile",
                TeamName: "Test Team",
                TeamIdentifier: ["ABC123"],
                AppIDName: "Test App",
                Entitlements: [:],
                ExpirationDate: Date().addingTimeInterval(86400),
                CreationDate: Date(),
                DeveloperCertificates: nil,
                ProvisionedDevices: ["device1"],
                ProvisionsAllDevices: false,
                Platform: platformStrings
            )

            let provisioningInfo = ProvisioningInfo(from: mockProfile)
            #expect(provisioningInfo.platform == expected)
        }

        @Test("Expiration status calculation", arguments: [
            (daysFromNow: -1, expected: ExpirationStatus.expired), // Yesterday
            (daysFromNow: 15, expected: ExpirationStatus.expiring), // 15 days from now
            (daysFromNow: 60, expected: ExpirationStatus.valid) // 60 days from now
        ])
        func expirationStatusCalculation(daysFromNow: Int, expected: ExpirationStatus) {
            let expirationDate = Date().addingTimeInterval(TimeInterval(daysFromNow * 86400))

            let mockProfile = RawProfile(
                UUID: "99999999-8888-7777-6666-555555555555",
                Name: "Test Profile",
                TeamName: "Test Team",
                TeamIdentifier: ["ABC123"],
                AppIDName: "Test App",
                Entitlements: [:],
                ExpirationDate: expirationDate,
                CreationDate: Date(),
                DeveloperCertificates: nil,
                ProvisionedDevices: ["device1"],
                ProvisionsAllDevices: false,
                Platform: ["iOS"]
            )

            let provisioningInfo = ProvisioningInfo(from: mockProfile)
            #expect(provisioningInfo.expirationStatus == expected)
        }

        @Test("Default values for missing fields")
        func defaultValues() {
            let mockProfile = RawProfile(
                UUID: nil,
                Name: nil,
                TeamName: nil,
                TeamIdentifier: nil,
                AppIDName: nil,
                Entitlements: nil,
                ExpirationDate: nil,
                CreationDate: nil,
                DeveloperCertificates: nil,
                ProvisionedDevices: nil,
                ProvisionsAllDevices: nil,
                Platform: nil
            )

            let provisioningInfo = ProvisioningInfo(from: mockProfile)

            #expect(provisioningInfo.name == "Unknown")
            #expect(provisioningInfo.teamName == "Unknown Team")
            #expect(provisioningInfo.teamID == "Unknown")
            #expect(provisioningInfo.appID == "Unknown App")
            #expect(provisioningInfo.expirationDate == Date.distantFuture)
            #expect(provisioningInfo.creationDate == Date.distantPast)
            #expect(provisioningInfo.devices == nil)
            #expect(provisioningInfo.certificates.isEmpty)
            #expect(provisioningInfo.entitlements.isEmpty)
            #expect(provisioningInfo.platform == [.iOS])
        }
    }

    @Suite("EntitlementValue Tests", .tags(.models))
    struct EntitlementValueTests {
        @Test("EntitlementValue creation from different types")
        func entitlementValueCreation() {
            // Test direct creation
            let stringValue = EntitlementValue.string("test")
            let boolValue = EntitlementValue.bool(true)
            let arrayValue = EntitlementValue.array(["one", "two"])
            let dictValue = EntitlementValue.dictionary(["key": "value"])

            #expect(stringValue == .string("test"))
            #expect(boolValue == .bool(true))
            #expect(arrayValue == .array(["one", "two"]))
            #expect(dictValue == .dictionary(["key": "value"]))
        }

        @Test("EntitlementValue from Any conversion")
        func entitlementValueFromAny() {
            let testCases: [(Any, EntitlementValue?)] = [
                ("test string", .string("test string")),
                (true, .bool(true)),
                (42, .string("42")),
                (3.14, .string("3.14")),
                (["one", "two"], .array(["one", "two"])),
                (["key": "value"], .dictionary(["key": "value"])),
                ([1, 2, 3], .array(["1", "2", "3"])),
                (["key": 42], .dictionary(["key": "42"]))
            ]

            for (value, expected) in testCases {
                let result = EntitlementValue.from(value: value)
                #expect(result == expected)
            }
        }

        @Test("EntitlementValue Codable conformance")
        func entitlementValueCodable() throws {
            let testCases: [EntitlementValue] = [
                .string("test"),
                .bool(true),
                .array(["one", "two"]),
                .dictionary(["key": "value"])
            ]

            for original in testCases {
                let data = try JSONEncoder().encode(original)
                let decoded = try JSONDecoder().decode(EntitlementValue.self, from: data)
                #expect(decoded == original)
            }
        }
    }

    @Suite("RawProfile Tests", .tags(.models))
    struct RawProfileTests {
        @Test("RawProfile Codable conformance")
        func rawProfileCodable() throws {
            let originalProfile = RawProfile(
                UUID: "12345",
                Name: "Test",
                TeamName: "Team",
                TeamIdentifier: ["ID"],
                AppIDName: "App",
                Entitlements: ["bool": .bool(true), "string": .string("value")],
                ExpirationDate: Date(),
                CreationDate: Date(),
                DeveloperCertificates: [Data([0x01, 0x02, 0x03])],
                ProvisionedDevices: ["device"],
                ProvisionsAllDevices: true,
                Platform: ["iOS", "macOS"]
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(originalProfile)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decodedProfile = try decoder.decode(RawProfile.self, from: data)

            #expect(decodedProfile.UUID == originalProfile.UUID)
            #expect(decodedProfile.Name == originalProfile.Name)
            #expect(decodedProfile.TeamName == originalProfile.TeamName)
            #expect(decodedProfile.TeamIdentifier == originalProfile.TeamIdentifier)
            #expect(decodedProfile.AppIDName == originalProfile.AppIDName)
            #expect(decodedProfile.ProvisionedDevices == originalProfile.ProvisionedDevices)
            #expect(decodedProfile.ProvisionsAllDevices == originalProfile.ProvisionsAllDevices)
            #expect(decodedProfile.Platform == originalProfile.Platform)
        }
    }
}
