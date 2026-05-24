//
//  AppArchiveTests.swift
//  CoreTests
//
//  Created by Evgeny Aleksandrov

import AppKit
import Foundation
@testable import ProvisionQLCore
import Testing
import ZIPFoundation

// MARK: - Tags

extension Tag {
    @Tag static var appInfo: Self
    @Tag static var archiveParser: Self
}

// MARK: - Test Suites

@Suite("App Archive Tests")
struct AppArchiveTests {
    @Suite("AppInfo Tests", .tags(.appInfo, .models))
    struct AppInfoTests {
        @Test("AppInfo initialization with all parameters")
        func appInfoInitialization() throws {
            let mockIcon = NSImage(size: NSSize(width: 64, height: 64))
            let mockProfile = try createMockProvisioningInfo()

            let appInfo = AppInfo(
                name: "Test App",
                bundleIdentifier: "com.test.app",
                version: "1.0.0",
                buildNumber: "100",
                icon: mockIcon,
                embeddedProvisioningProfile: mockProfile,
                deviceFamily: ["iPhone", "iPad"],
                minimumOSVersion: "15.0",
                sdkVersion: "18.0"
            )

            #expect(appInfo.name == "Test App")
            #expect(appInfo.bundleIdentifier == "com.test.app")
            #expect(appInfo.version == "1.0.0")
            #expect(appInfo.buildNumber == "100")
            #expect(appInfo.icon != nil)
            #expect(appInfo.embeddedProvisioningProfile?.name == mockProfile.name)
            #expect(appInfo.deviceFamily == ["iPhone", "iPad"])
            #expect(appInfo.minimumOSVersion == "15.0")
            #expect(appInfo.sdkVersion == "18.0")
            #expect(appInfo.diagnostics.isEmpty)
        }

        @Test("AppInfo display version formatting", arguments: [
            ("1.0.0", "100", "1.0.0 (100)"),
            ("2.1", "2.1", "2.1"),
            ("1.0", "1", "1.0 (1)"),
            ("", "1", " (1)")
        ])
        func displayVersionFormatting(version: String, buildNumber: String, expected: String) {
            let appInfo = AppInfo(
                name: "Test",
                bundleIdentifier: "com.test",
                version: version,
                buildNumber: buildNumber
            )

            #expect(appInfo.displayVersion == expected)
        }

        @Test("AppInfo embedded profile detection")
        func embeddedProfileDetection() throws {
            let withProfile = try AppInfo(
                name: "Test",
                bundleIdentifier: "com.test",
                version: "1.0",
                buildNumber: "1",
                embeddedProvisioningProfile: createMockProvisioningInfo()
            )

            let withoutProfile = AppInfo(
                name: "Test",
                bundleIdentifier: "com.test",
                version: "1.0",
                buildNumber: "1"
            )

            #expect(withProfile.hasEmbeddedProfile == true)
            #expect(withoutProfile.hasEmbeddedProfile == false)
        }
    }

    @Suite("AppArchiveParser Mock Tests", .tags(.archiveParser))
    struct AppArchiveParserMockTests {
        @Test("Parser error handling for invalid files")
        func parserErrorHandling() {
            let tempURL = createTempFile(withExtension: "ipa", content: Data([0x00, 0x01, 0x02]))
            defer { try? FileManager.default.removeItem(at: tempURL) }

            #expect(throws: Error.self) {
                _ = try AppArchiveParser.parse(tempURL)
            }
        }

        @Test("Parser handles missing Info.plist")
        func parserMissingInfoPlist() throws {
            // Create a mock ZIP archive without Info.plist
            let tempURL = createTempZipArchive(withFiles: [
                "Payload/TestApp.app/SomeFile.txt": Data("test".utf8)
            ], extension: "ipa")
            defer { try? FileManager.default.removeItem(at: tempURL) }

            #expect(throws: ParsingError.self) {
                _ = try AppArchiveParser.parse(tempURL)
            }
        }

        @Test("Parser handles IPA archives without directory entries")
        func parserHandlesIPAsWithoutDirectoryEntries() throws {
            let tempURL = createTempZipArchive(
                withFiles: [
                    "Payload/TestApp.app/Info.plist": createMockInfoPlistData()
                ],
                extension: "ipa",
                includeDirectories: false
            )
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let appInfo = try AppArchiveParser.parse(tempURL)

            #expect(appInfo.name == "Test App Display")
            #expect(appInfo.bundleIdentifier == "com.test.app")
            #expect(appInfo.diagnostics.isEmpty)
        }

        @Test("Parser reports malformed embedded provisioning profile")
        func parserReportsMalformedEmbeddedProvisioningProfile() throws {
            let tempURL = createTempZipArchive(
                withFiles: [
                    "Payload/TestApp.app/Info.plist": createMockInfoPlistData(),
                    "Payload/TestApp.app/embedded.mobileprovision": Data("not cms".utf8)
                ],
                extension: "ipa"
            )
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let appInfo = try AppArchiveParser.parse(tempURL)
            let diagnostic = try #require(appInfo.diagnostics.first)

            #expect(appInfo.embeddedProvisioningProfile == nil)
            #expect(appInfo.diagnostics.count == 1)
            #expect(diagnostic.severity == .warning)
            #expect(diagnostic.code == .malformedEmbeddedProvisioningProfile)
            #expect(diagnostic.message.contains("Embedded provisioning profile could not be parsed"))
            #expect(diagnostic.message.contains("Failed to decode CMS data"))
        }

        @Test("Parser handles invalid app bundle structure")
        func parserInvalidBundleStructure() throws {
            // Create a ZIP without proper app bundle structure
            let tempURL = createTempZipArchive(withFiles: [
                "RandomFile.txt": Data("test".utf8)
            ], extension: "ipa")
            defer { try? FileManager.default.removeItem(at: tempURL) }

            #expect(throws: ParsingError.invalidAppBundle) {
                _ = try AppArchiveParser.parse(tempURL)
            }
        }

        @Test("Device family and SDK info extraction")
        func deviceFamilyAndSDKExtraction() throws {
            // Test IPA file with device family info
            let ipaInfoPlist = createMockInfoPlistData()
            let ipaFiles = ["Payload/TestApp.app/Info.plist": ipaInfoPlist]
            let ipaURL = createTempZipArchive(withFiles: ipaFiles, extension: "ipa")
            defer { try? FileManager.default.removeItem(at: ipaURL) }

            let ipaInfo = try AppArchiveParser.parse(ipaURL)
            #expect(ipaInfo.deviceFamily.contains("iPhone"))
            #expect(ipaInfo.deviceFamily.contains("iPad"))
            #expect(ipaInfo.minimumOSVersion == "15.0")
            #expect(ipaInfo.sdkVersion == "iphoneos18.0")

            // Test xcarchive file (should be a directory structure, not a ZIP)
            let xcarchiveInfoPlist = createMockInfoPlistData()
            let xcarchiveURL = createTempXCArchiveDirectory(withInfoPlist: xcarchiveInfoPlist)
            defer { try? FileManager.default.removeItem(at: xcarchiveURL) }

            let xcarchiveInfo = try AppArchiveParser.parse(xcarchiveURL)
            #expect(xcarchiveInfo.deviceFamily == ipaInfo.deviceFamily)
        }
    }
}

// MARK: - Test Helpers

private func createMockProvisioningInfo() throws -> ProvisioningInfo {
    let mockProfile = RawProfile(
        UUID: "12345678-1234-1234-1234-123456789ABC",
        Name: "Test Profile",
        TeamName: "Test Team",
        TeamIdentifier: ["ABC123"],
        AppIDName: "Test App",
        Entitlements: ["get-task-allow": .bool(true)],
        ExpirationDate: Date().addingTimeInterval(86400 * 60),
        CreationDate: Date(),
        DeveloperCertificates: nil,
        ProvisionedDevices: ["device1", "device2"],
        ProvisionsAllDevices: false,
        Platform: ["iOS"]
    )

    return try ProvisioningInfo(from: mockProfile)
}

private func createMockInfoPlistData() -> Data {
    let plist: [String: Any] = [
        "CFBundleName": "Test App",
        "CFBundleDisplayName": "Test App Display",
        "CFBundleIdentifier": "com.test.app",
        "CFBundleShortVersionString": "1.0.0",
        "CFBundleVersion": "100",
        "CFBundleIcons": [
            "CFBundlePrimaryIcon": [
                "CFBundleIconFiles": ["AppIcon60x60"]
            ]
        ],
        "UIDeviceFamily": [1, 2], // iPhone and iPad
        "LSRequiresIPhoneOS": true,
        "MinimumOSVersion": "15.0",
        "DTSDKName": "iphoneos18.0",
        "DTPlatformVersion": "18.0",
        "CFBundleSupportedPlatforms": ["iPhoneOS"]
    ]

    return try! PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
}

private func createTempFile(withExtension ext: String, content: Data) -> URL {
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(ext)

    try! content.write(to: tempURL)
    return tempURL
}

private func createTempZipArchive(withFiles files: [String: Data], extension ext: String) -> URL {
    createTempZipArchive(withFiles: files, extension: ext, includeDirectories: true)
}

private func createTempZipArchive(
    withFiles files: [String: Data],
    extension ext: String,
    includeDirectories: Bool
) -> URL {
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(ext)

    let archive = try! Archive(url: tempURL, accessMode: .create)

    if includeDirectories {
        // Create directory structure first
        var directories = Set<String>()
        for path in files.keys {
            let components = path.split(separator: "/")
            for i in 1 ..< components.count {
                let dirPath = components.prefix(i).joined(separator: "/") + "/"
                directories.insert(dirPath)
            }
        }

        // Add directories
        for dir in directories.sorted() {
            try! archive.addEntry(with: dir, type: .directory, uncompressedSize: Int64(0)) { (_: Int64, _: Int) in
                Data()
            }
        }
    }

    // Add files
    for (path, data) in files {
        try! archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count)) { (
            position: Int64,
            size: Int
        ) in
            let start = Int(position)
            let end = min(start + size, data.count)
            return data.subdata(in: start ..< end)
        }
    }

    return tempURL
}

private func createTempXCArchiveDirectory(withInfoPlist infoPlistData: Data) -> URL {
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("xcarchive")

    // Create the xcarchive directory structure
    let productsPath = tempURL.appendingPathComponent("Products/Applications")
    let appBundlePath = productsPath.appendingPathComponent("TestApp.app")
    let infoPlistPath = appBundlePath.appendingPathComponent("Info.plist")

    try! FileManager.default.createDirectory(at: appBundlePath, withIntermediateDirectories: true)
    try! infoPlistData.write(to: infoPlistPath)

    return tempURL
}
