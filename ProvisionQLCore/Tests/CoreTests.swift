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
    @Tag static var certificateInfo: Self
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
        func badgeInfoFromProvisioningInfo() throws {
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

            let provisioningInfo = try ProvisioningInfo(from: mockProfile)
            let badgeInfo = BadgeInfo(from: provisioningInfo)

            #expect(badgeInfo.deviceCount == 3)
            #expect(badgeInfo.expirationStatus == .valid)
            #expect(badgeInfo.profileType == .development)
        }

        @Test("BadgeInfo with zero devices")
        func badgeInfoZeroDevices() throws {
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

            let provisioningInfo = try ProvisioningInfo(from: mockProfile)
            let badgeInfo = BadgeInfo(from: provisioningInfo)

            #expect(badgeInfo.deviceCount == 0)
            #expect(badgeInfo.profileType == .appStore)
        }
    }

    @Suite("CertificateInfo Tests", .tags(.certificateInfo, .models))
    struct CertificateInfoTests {
        @Test("Certificate expiration date is read from X.509 validity")
        func certificateExpirationDate() throws {
            let fixtureURL = try #require(Bundle.module.url(
                forResource: "DeveloperCertificate",
                withExtension: "cer"
            ))
            let certificateData = try Data(contentsOf: fixtureURL)
            let certificateInfo = try #require(CertificateInfo.from(data: certificateData))

            var expectedExpirationDateComponents = DateComponents()
            expectedExpirationDateComponents.calendar = Calendar(identifier: .gregorian)
            expectedExpirationDateComponents.timeZone = TimeZone(secondsFromGMT: 0)
            expectedExpirationDateComponents.year = 2126
            expectedExpirationDateComponents.month = 5
            expectedExpirationDateComponents.day = 24
            let expectedExpirationDate = try #require(expectedExpirationDateComponents.date)

            #expect(certificateInfo.subject == "ProvisionQL Fixture Developer Certificate")
            #expect(certificateInfo.expirationDate == expectedExpirationDate)
        }
    }

    @Suite("ProvisioningInfo Tests", .tags(.provisioningInfo, .models))
    struct ProvisioningInfoTests {
        @Test("ProvisioningInfo initialization from RawProfile")
        func provisioningInfoInitialization() throws {
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

            let provisioningInfo = try ProvisioningInfo(from: mockProfile)

            #expect(provisioningInfo.name == "Test Development Profile")
            #expect(provisioningInfo.teamName == "Test Team LLC")
            #expect(provisioningInfo.teamID == "ABCD123456")
            #expect(provisioningInfo.appID == "My Test App")
            #expect(provisioningInfo.expirationDate == expirationDate)
            #expect(provisioningInfo.creationDate == creationDate)
            #expect(provisioningInfo.devices?.count == 2)
            #expect(provisioningInfo.profileType == .development)
            #expect(provisioningInfo.signerStatus == .unknown)
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
        ) throws {
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

            let provisioningInfo = try ProvisioningInfo(from: mockProfile)
            #expect(provisioningInfo.profileType == expected)
        }

        @Test("Explicit profile type is preferred over device heuristic", arguments: [
            (profileType: "IOS_APP_DEVELOPMENT", expected: ProvisioningInfo.ProfileType.development),
            (profileType: "IOS_APP_ADHOC", expected: ProvisioningInfo.ProfileType.adHoc),
            (profileType: "IOS_APP_STORE", expected: ProvisioningInfo.ProfileType.appStore),
            (profileType: "IOS_APP_INHOUSE", expected: ProvisioningInfo.ProfileType.enterprise),
            (profileType: "MAC_APP_DEVELOPMENT", expected: ProvisioningInfo.ProfileType.development),
            (profileType: "MAC_APP_STORE", expected: ProvisioningInfo.ProfileType.appStore),
            (profileType: "MAC_APP_DIRECT", expected: ProvisioningInfo.ProfileType.directDistribution),
            (profileType: "MAC_CATALYST_APP_DIRECT", expected: ProvisioningInfo.ProfileType.directDistribution),
            (profileType: "DEVELOPER_ID", expected: ProvisioningInfo.ProfileType.developerID),
            (profileType: "DIRECT_DISTRIBUTION", expected: ProvisioningInfo.ProfileType.directDistribution)
        ])
        func explicitProfileTypeIsPreferredOverDeviceHeuristic(
            profileType: String,
            expected: ProvisioningInfo.ProfileType
        ) throws {
            let mockProfile = RawProfile(
                UUID: "FEDCBA09-8765-4321-FEDC-BA0987654321",
                Name: "Test Profile",
                TeamName: "Test Team",
                TeamIdentifier: ["ABC123"],
                AppIDName: "Test App",
                Entitlements: [:],
                ExpirationDate: Date().addingTimeInterval(86400),
                CreationDate: Date(),
                DeveloperCertificates: nil,
                ProvisionedDevices: nil,
                ProvisionsAllDevices: false,
                Platform: ["macOS"],
                ProfileType: profileType
            )

            let provisioningInfo = try ProvisioningInfo(from: mockProfile)
            #expect(provisioningInfo.profileType == expected)
        }

        @Test("Signer status is stored on provisioning info")
        func signerStatusIsStoredOnProvisioningInfo() throws {
            let mockProfile = RawProfile(
                UUID: "FEDCBA09-8765-4321-FEDC-BA0987654321",
                Name: "Test Profile",
                TeamName: "Test Team",
                TeamIdentifier: ["ABC123"],
                AppIDName: "Test App",
                Entitlements: [:],
                ExpirationDate: Date().addingTimeInterval(86400),
                CreationDate: Date(),
                DeveloperCertificates: nil,
                ProvisionedDevices: nil,
                ProvisionsAllDevices: false,
                Platform: ["iOS"]
            )

            let provisioningInfo = try ProvisioningInfo(from: mockProfile, signerStatus: .signedByAppleWWDR)
            #expect(provisioningInfo.signerStatus == .signedByAppleWWDR)
        }

        @Test("Platform detection", arguments: [
            (platformStrings: ["iOS"], expected: [ProvisioningInfo.Platform.iOS]),
            (platformStrings: ["macOS"], expected: [ProvisioningInfo.Platform.macOS]),
            (platformStrings: ["OSX"], expected: [ProvisioningInfo.Platform.macOS]),
            (platformStrings: ["tvOS"], expected: [ProvisioningInfo.Platform.tvOS]),
            (platformStrings: ["watchOS"], expected: [ProvisioningInfo.Platform.watchOS]),
            (platformStrings: ["visionOS"], expected: [ProvisioningInfo.Platform.visionOS]),
            (
                platformStrings: ["iOS", "macOS"],
                expected: [ProvisioningInfo.Platform.iOS, ProvisioningInfo.Platform.macOS]
            ),
            (platformStrings: ["unknown"], expected: [ProvisioningInfo.Platform.unknown("unknown")]),
            (platformStrings: nil, expected: [ProvisioningInfo.Platform.iOS])
        ])
        func platformDetection(platformStrings: [String]?, expected: [ProvisioningInfo.Platform]) throws {
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

            let provisioningInfo = try ProvisioningInfo(from: mockProfile)
            #expect(provisioningInfo.platform == expected)
        }

        @Test("Platform Codable preserves raw values", arguments: [
            (platform: ProvisioningInfo.Platform.iOS, encodedString: "\"iOS\""),
            (platform: ProvisioningInfo.Platform.macOS, encodedString: "\"macOS\""),
            (platform: ProvisioningInfo.Platform.unknown("XROS"), encodedString: "\"XROS\"")
        ])
        func platformCodable(platform: ProvisioningInfo.Platform, encodedString: String) throws {
            let data = try JSONEncoder().encode(platform)
            let jsonString = String(decoding: data, as: UTF8.self)
            #expect(jsonString == encodedString)

            let decodedPlatform = try JSONDecoder().decode(ProvisioningInfo.Platform.self, from: data)
            #expect(decodedPlatform == platform)
        }

        @Test("Expiration status calculation", arguments: [
            (daysFromNow: -1, expected: ExpirationStatus.expired), // Yesterday
            (daysFromNow: 15, expected: ExpirationStatus.expiring), // 15 days from now
            (daysFromNow: 60, expected: ExpirationStatus.valid) // 60 days from now
        ])
        func expirationStatusCalculation(daysFromNow: Int, expected: ExpirationStatus) throws {
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

            let provisioningInfo = try ProvisioningInfo(from: mockProfile)
            #expect(provisioningInfo.expirationStatus == expected)
        }

        @Test("Expiration status uses fixed duration threshold", arguments: [
            (secondsFromNow: TimeInterval(30 * 86400 - 60), expected: ExpirationStatus.expiring),
            (secondsFromNow: TimeInterval(30 * 86400 + 60), expected: ExpirationStatus.valid)
        ])
        func expirationStatusUsesFixedDurationThreshold(
            secondsFromNow: TimeInterval,
            expected: ExpirationStatus
        ) throws {
            let mockProfile = RawProfile(
                UUID: "99999999-8888-7777-6666-555555555555",
                Name: "Test Profile",
                TeamName: "Test Team",
                TeamIdentifier: ["ABC123"],
                AppIDName: "Test App",
                Entitlements: [:],
                ExpirationDate: Date().addingTimeInterval(secondsFromNow),
                CreationDate: Date(),
                DeveloperCertificates: nil,
                ProvisionedDevices: ["device1"],
                ProvisionsAllDevices: false,
                Platform: ["iOS"]
            )

            let provisioningInfo = try ProvisioningInfo(from: mockProfile)
            #expect(provisioningInfo.expirationStatus == expected)
        }

        @Test("Missing required fields throws validation error")
        func missingRequiredFieldsThrowsValidationError() {
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

            do {
                _ = try ProvisioningInfo(from: mockProfile)
                Issue.record("Expected malformed provisioning profile to throw")
            } catch let error as ProvisioningProfileValidationError {
                #expect(error.missingFields == [
                    "UUID",
                    "Name",
                    "TeamName",
                    "TeamIdentifier",
                    "AppIDName",
                    "Entitlements",
                    "ExpirationDate",
                    "CreationDate"
                ])
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        @Test("Missing platform is reported as a diagnostic")
        func missingPlatformIsReportedAsDiagnostic() throws {
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
                Platform: nil
            )

            let provisioningInfo = try ProvisioningInfo(from: mockProfile)

            #expect(provisioningInfo.platform == [.iOS])
            #expect(provisioningInfo.diagnostics == [
                ProvisioningDiagnostic(
                    severity: .warning,
                    code: .missingPlatform,
                    message: "Platform is missing; defaulting to iOS."
                )
            ])
        }

        @Test("Invalid developer certificate is reported as a diagnostic")
        func invalidDeveloperCertificateIsReportedAsDiagnostic() throws {
            let mockProfile = RawProfile(
                UUID: "11111111-2222-3333-4444-555555555555",
                Name: "Test Profile",
                TeamName: "Test Team",
                TeamIdentifier: ["ABC123"],
                AppIDName: "Test App",
                Entitlements: [:],
                ExpirationDate: Date().addingTimeInterval(86400),
                CreationDate: Date(),
                DeveloperCertificates: [Data([0x00, 0x01, 0x02])],
                ProvisionedDevices: ["device1"],
                ProvisionsAllDevices: false,
                Platform: ["iOS"]
            )

            let provisioningInfo = try ProvisioningInfo(from: mockProfile)

            #expect(provisioningInfo.certificates.isEmpty)
            #expect(provisioningInfo.diagnostics == [
                ProvisioningDiagnostic(
                    severity: .warning,
                    code: .invalidDeveloperCertificate,
                    message: "A developer certificate could not be decoded and was skipped."
                )
            ])
        }
    }

    @Suite("PlistValue Tests", .tags(.models))
    struct PlistValueTests {
        @Test("PlistValue creation from different types")
        func plistValueCreation() {
            let stringValue = PlistValue.string("test")
            let boolValue = PlistValue.bool(true)
            let integerValue = PlistValue.integer(42)
            let doubleValue = PlistValue.double(3.14)
            let arrayValue = PlistValue.array([.string("one"), .integer(2)])
            let dictValue = PlistValue.dictionary(["key": .string("value")])

            #expect(stringValue == .string("test"))
            #expect(boolValue == .bool(true))
            #expect(integerValue == .integer(42))
            #expect(doubleValue == .double(3.14))
            #expect(arrayValue == .array([.string("one"), .integer(2)]))
            #expect(dictValue == .dictionary(["key": .string("value")]))
        }

        @Test("PlistValue from Any conversion")
        func plistValueFromAny() {
            let testCases: [(Any, PlistValue?)] = [
                ("test string", .string("test string")),
                (true, .bool(true)),
                (42, .integer(42)),
                (3.14, .double(3.14)),
                (["one", "two"], .array([.string("one"), .string("two")])),
                (["key": "value"], .dictionary(["key": .string("value")])),
                ([1, 2, 3], .array([.integer(1), .integer(2), .integer(3)])),
                (["key": 42], .dictionary(["key": .integer(42)])),
                (
                    ["parent": ["enabled": true, "items": [1, "two"]] as [String: Any]],
                    .dictionary([
                        "parent": .dictionary([
                            "enabled": .bool(true),
                            "items": .array([.integer(1), .string("two")])
                        ])
                    ])
                )
            ]

            for (value, expected) in testCases {
                let result = PlistValue.from(value: value)
                #expect(result == expected)
            }
        }

        @Test("PlistValue property list Codable conformance")
        func plistValueCodable() throws {
            let testCases: [PlistValue] = [
                .string("test"),
                .bool(true),
                .integer(42),
                .double(3.14),
                .data(Data([0x01, 0x02, 0x03])),
                .date(Date(timeIntervalSinceReferenceDate: 123)),
                .array([.string("one"), .integer(2)]),
                .dictionary(["key": .array([.bool(true), .string("value")])])
            ]

            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary

            for original in testCases {
                let data = try encoder.encode(["value": original])
                let decoded = try PropertyListDecoder().decode([String: PlistValue].self, from: data)
                #expect(decoded["value"] == original)
            }
        }

        @Test("PlistValue preserves recursive property list values")
        func plistValuePropertyListCodable() throws {
            let original = PlistValue.dictionary([
                "application-identifier": .string("ABCDE12345.com.example.app"),
                "config": .dictionary([
                    "enabled": .bool(true),
                    "numbers": .array([.integer(1), .double(2.5)]),
                    "payload": .data(Data([0x01, 0x02, 0x03])),
                    "timestamp": .date(Date(timeIntervalSinceReferenceDate: 123))
                ])
            ])

            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data = try encoder.encode(original)
            let decoded = try PropertyListDecoder().decode(PlistValue.self, from: data)

            #expect(decoded == original)
        }
    }

    @Suite("Mach-O Entitlements Tests")
    struct MachOEntitlementsTests {
        @Test("Extracts embedded entitlements from code signature")
        func extractsEmbeddedEntitlements() throws {
            let executableData = try createMachOExecutableData(entitlements: [
                "application-identifier": "ABCDE12345.com.example.app",
                "get-task-allow": true
            ])
            let executableURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: executableURL) }

            try executableData.write(to: executableURL)

            let entitlements = EntitlementsExtractor.extractEntitlements(fromCodeAt: executableURL)

            #expect(entitlements["application-identifier"] == .string("ABCDE12345.com.example.app"))
            #expect(entitlements["get-task-allow"] == .bool(true))
        }

        @Test("Rejects fat headers with impossible architecture counts")
        func rejectsImpossibleFatArchitectureCount() {
            var data = Data()
            data.appendBigEndianUInt32(0xCAFE_BABE)
            data.appendBigEndianUInt32(UInt32.max)

            #expect(MachOEntitlementsReader.extractEntitlements(from: data) == nil)
        }

        @Test("Rejects short code signature load commands")
        func rejectsShortCodeSignatureLoadCommand() {
            var data = createMachOHeader(loadCommandCount: 1, loadCommandsSize: 12)
            data.appendLittleEndianUInt32(0x1D)
            data.appendLittleEndianUInt32(12)
            data.appendLittleEndianUInt32(0)

            #expect(MachOEntitlementsReader.extractEntitlements(from: data) == nil)
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
                Entitlements: [
                    "bool": .bool(true),
                    "nested": .dictionary([
                        "number": .integer(42),
                        "strings": .array([.string("one"), .string("two")])
                    ]),
                    "string": .string("value")
                ],
                ExpirationDate: Date(),
                CreationDate: Date(),
                DeveloperCertificates: [Data([0x01, 0x02, 0x03])],
                ProvisionedDevices: ["device"],
                ProvisionsAllDevices: true,
                Platform: ["iOS", "macOS"],
                ProfileType: "MAC_APP_DIRECT"
            )

            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data = try encoder.encode(originalProfile)

            let decodedProfile = try PropertyListDecoder().decode(RawProfile.self, from: data)

            #expect(decodedProfile.UUID == originalProfile.UUID)
            #expect(decodedProfile.Name == originalProfile.Name)
            #expect(decodedProfile.TeamName == originalProfile.TeamName)
            #expect(decodedProfile.TeamIdentifier == originalProfile.TeamIdentifier)
            #expect(decodedProfile.AppIDName == originalProfile.AppIDName)
            #expect(decodedProfile.ProvisionedDevices == originalProfile.ProvisionedDevices)
            #expect(decodedProfile.ProvisionsAllDevices == originalProfile.ProvisionsAllDevices)
            #expect(decodedProfile.Platform == originalProfile.Platform)
            #expect(decodedProfile.ProfileType == originalProfile.ProfileType)
        }
    }
}

private func createMachOHeader(loadCommandCount: UInt32, loadCommandsSize: UInt32) -> Data {
    var executable = Data()
    executable.appendLittleEndianUInt32(0xFEED_FACF)
    executable.appendLittleEndianUInt32(0x0100_000C)
    executable.appendLittleEndianUInt32(0)
    executable.appendLittleEndianUInt32(2)
    executable.appendLittleEndianUInt32(loadCommandCount)
    executable.appendLittleEndianUInt32(loadCommandsSize)
    executable.appendLittleEndianUInt32(0)
    executable.appendLittleEndianUInt32(0)
    return executable
}

private func createMachOExecutableData(entitlements: [String: Any]) throws -> Data {
    let plistData = try PropertyListSerialization.data(
        fromPropertyList: entitlements,
        format: .xml,
        options: 0
    )

    var entitlementsBlob = Data()
    entitlementsBlob.appendBigEndianUInt32(0xFADE_7171)
    entitlementsBlob.appendBigEndianUInt32(UInt32(8 + plistData.count))
    entitlementsBlob.append(plistData)

    var codeSignature = Data()
    codeSignature.appendBigEndianUInt32(0xFADE_0CC0)
    codeSignature.appendBigEndianUInt32(UInt32(20 + entitlementsBlob.count))
    codeSignature.appendBigEndianUInt32(1)
    codeSignature.appendBigEndianUInt32(5)
    codeSignature.appendBigEndianUInt32(20)
    codeSignature.append(entitlementsBlob)

    let codeSignatureOffset: UInt32 = 48

    var executable = createMachOHeader(loadCommandCount: 1, loadCommandsSize: 16)
    executable.appendLittleEndianUInt32(0x1D)
    executable.appendLittleEndianUInt32(16)
    executable.appendLittleEndianUInt32(codeSignatureOffset)
    executable.appendLittleEndianUInt32(UInt32(codeSignature.count))
    executable.append(codeSignature)

    return executable
}

private extension Data {
    mutating func appendLittleEndianUInt32(_ value: UInt32) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { buffer in
            append(contentsOf: buffer)
        }
    }

    mutating func appendBigEndianUInt32(_ value: UInt32) {
        var bigEndianValue = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndianValue) { buffer in
            append(contentsOf: buffer)
        }
    }
}
