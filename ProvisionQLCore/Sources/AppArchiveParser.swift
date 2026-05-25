//
//  AppArchiveParser.swift
//  Core
//
//  Created by Evgeny Aleksandrov

import Foundation
import ZIPFoundation

public enum AppArchiveParser {
    public static func parse(_ url: URL) throws -> AppInfo {
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "ipa":
            return try parseIPA(url)
        case "xcarchive":
            return try parseXCArchive(url)
        case "appex":
            return try parseAppExtension(url)
        default:
            throw ParsingError.unsupportedFileType
        }
    }
}

private extension AppArchiveParser {
    static func parseIPA(_ url: URL) throws -> AppInfo {
        let archive = try Archive(url: url, accessMode: .read)

        // Find the app bundle path within the archive
        let appBundlePath = try ArchiveUtilities.findAppBundlePath(in: archive, archiveType: .ipa)

        // Extract Info.plist
        let infoPlistPath = appBundlePath + "Info.plist"
        let infoPlistData = try ArchiveUtilities.extractFile(from: archive, path: infoPlistPath)
        let plist = try PlistParser.parse(data: infoPlistData)

        // Parse app information
        let appInfo = PlistParser.extractAppInfo(from: plist)

        // Extract app icon using the dedicated IconExtractor
        let icon = try? IconExtractor.extractIcon(from: url)

        // Extract embedded provisioning profile
        let embeddedProfile = ProvisioningProfileExtractor.extractFromArchive(archive, appBundlePath: appBundlePath)

        // Extract app entitlements
        let entitlements = extractAppEntitlements(from: archive, appBundlePath: appBundlePath)

        return AppInfo(
            name: appInfo.name,
            bundleIdentifier: appInfo.bundleIdentifier,
            version: appInfo.version,
            buildNumber: appInfo.buildNumber,
            icon: icon,
            embeddedProvisioningProfile: embeddedProfile.profile,
            entitlements: entitlements,
            deviceFamily: appInfo.deviceFamily,
            minimumOSVersion: appInfo.minimumOSVersion,
            sdkVersion: appInfo.sdkVersion,
            diagnostics: embeddedProfile.diagnostics
        )
    }

    static func parseXCArchive(_ url: URL) throws -> AppInfo {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw ParsingError.invalidArchiveFormat
        }

        let appBundleURL = try findAppBundleInXCArchive(at: url)
        let infoPlistURL = try infoPlistURL(for: appBundleURL)
        let plist = try PlistParser.parse(url: infoPlistURL)

        let appInfo = PlistParser.extractAppInfo(from: plist)

        let icon = try? IconExtractor.extractIcon(from: url)

        let embeddedProfile = ProvisioningProfileExtractor.extractFromDirectory(appBundleURL)

        // Extract app entitlements
        let entitlements = EntitlementsExtractor.extractEntitlements(from: appBundleURL)

        return AppInfo(
            name: appInfo.name,
            bundleIdentifier: appInfo.bundleIdentifier,
            version: appInfo.version,
            buildNumber: appInfo.buildNumber,
            icon: icon,
            embeddedProvisioningProfile: embeddedProfile.profile,
            entitlements: entitlements,
            deviceFamily: appInfo.deviceFamily,
            minimumOSVersion: appInfo.minimumOSVersion,
            sdkVersion: appInfo.sdkVersion,
            diagnostics: embeddedProfile.diagnostics
        )
    }

    static func parseAppExtension(_ url: URL) throws -> AppInfo {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw ParsingError.invalidArchiveFormat
        }

        let infoPlistURL = try infoPlistURL(for: url)
        let plist = try PlistParser.parse(url: infoPlistURL)

        let appInfo = PlistParser.extractAppInfo(from: plist)

        let icon = try? IconExtractor.extractIcon(from: url)

        let embeddedProfile = ProvisioningProfileExtractor.extractFromDirectory(url)

        // Extract extension type from NSExtension dictionary
        var extensionType: String?
        var extensionPointIdentifier: String?
        if let nsExtension = plist["NSExtension"] as? [String: Any],
           let identifier = nsExtension["NSExtensionPointIdentifier"] as? String
        {
            extensionPointIdentifier = identifier
            extensionType = parseExtensionType(from: identifier)
        }

        // For app extensions, append the extension type to the name
        let displayName = if let extensionType {
            "\(appInfo.name) (\(extensionType))"
        } else {
            appInfo.name
        }

        // Extract app entitlements
        let entitlements = EntitlementsExtractor.extractEntitlements(from: url)

        return AppInfo(
            name: displayName,
            bundleIdentifier: appInfo.bundleIdentifier,
            version: appInfo.version,
            buildNumber: appInfo.buildNumber,
            icon: icon,
            embeddedProvisioningProfile: embeddedProfile.profile,
            entitlements: entitlements,
            deviceFamily: appInfo.deviceFamily,
            minimumOSVersion: appInfo.minimumOSVersion,
            sdkVersion: appInfo.sdkVersion,
            extensionPointIdentifier: extensionPointIdentifier,
            diagnostics: embeddedProfile.diagnostics
        )
    }

    static func parseExtensionType(from identifier: String) -> String {
        switch identifier {
        case "com.apple.intents-service":
            "Siri Intents"
        case "com.apple.intents-ui-service":
            "Siri Intents UI"
        case "com.apple.usernotifications.content-extension":
            "Notification Content"
        case "com.apple.usernotifications.service":
            "Notification Service"
        case "com.apple.share-services":
            "Share Extension"
        case "com.apple.widget-extension":
            "Today Widget"
        case "com.apple.widgetkit-extension":
            "Widget"
        case "com.apple.keyboard-service":
            "Keyboard"
        case "com.apple.photo-editing":
            "Photo Editing"
        case "com.apple.broadcast-services":
            "Broadcast"
        case "com.apple.callkit.call-directory":
            "Call Directory"
        case "com.apple.authentication-services-account-authentication-modification-ui":
            "Account Auth"
        case "com.apple.authentication-services-credential-provider-ui":
            "Credential Provider"
        case "com.apple.classkit.context-provider":
            "ClassKit"
        case "com.apple.fileprovider-ui":
            "File Provider UI"
        case "com.apple.fileprovider-nonui":
            "File Provider"
        case "com.apple.message-payload-provider":
            "Messages"
        case "com.apple.networkextension.packet-tunnel":
            "Packet Tunnel"
        case "com.apple.Safari.content-blocker":
            "Content Blocker"
        case "com.apple.Safari.web-extension":
            "Safari Extension"
        default:
            "App Extension"
        }
    }

    static func findAppBundleInXCArchive(at archiveURL: URL) throws -> URL {
        let productsPath = archiveURL.appendingPathComponent("Products", isDirectory: true)

        if let applicationPath = applicationPathInXCArchive(at: archiveURL) {
            let normalizedPath = applicationPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let candidates = [
                productsPath.appendingPathComponent(normalizedPath, isDirectory: true),
                archiveURL.appendingPathComponent(normalizedPath, isDirectory: true)
            ]

            for candidate in candidates where isAppBundle(candidate) {
                return candidate
            }
        }

        let applicationsPath = productsPath.appendingPathComponent("Applications", isDirectory: true)
        let appBundles = try FileManager.default.contentsOfDirectory(
            at: applicationsPath,
            includingPropertiesForKeys: nil
        )
        .filter(isAppBundle)
        .sorted { lhs, rhs in
            lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }

        guard let appBundleURL = appBundles.first else {
            throw ParsingError.invalidAppBundle
        }

        return appBundleURL
    }

    static func applicationPathInXCArchive(at archiveURL: URL) -> String? {
        let infoPlistURL = archiveURL.appendingPathComponent("Info.plist")
        guard
            let plist = try? PlistParser.parse(url: infoPlistURL),
            let applicationProperties = plist["ApplicationProperties"] as? [String: Any],
            let applicationPath = applicationProperties["ApplicationPath"] as? String,
            !applicationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return applicationPath
    }

    static func infoPlistURL(for bundleURL: URL) throws -> URL {
        let candidates = [
            bundleURL.appendingPathComponent("Contents/Info.plist"),
            bundleURL.appendingPathComponent("Info.plist")
        ]

        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        throw ParsingError.missingInfoPlist
    }

    static func isAppBundle(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return url.pathExtension == "app"
            && FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    static func extractAppEntitlements(from archive: Archive, appBundlePath: String) -> [String: PlistValue] {
        // First, try to find the executable name from Info.plist
        let infoPlistPath = appBundlePath + "Info.plist"
        guard let infoPlistData = try? ArchiveUtilities.extractFile(from: archive, path: infoPlistPath),
              let plist = try? PlistParser.parse(data: infoPlistData),
              let executableName = PlistParser.extractExecutableName(from: plist)
        else {
            return [:]
        }

        // Extract the executable
        let executablePath = appBundlePath + executableName
        guard let executableData = try? ArchiveUtilities.extractFile(from: archive, path: executablePath) else {
            return [:]
        }

        // Use the EntitlementsExtractor with temporary directory
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDirectory) }

            return EntitlementsExtractor.extractEntitlementsFromArchive(
                executableData: executableData,
                temporaryDirectory: tempDirectory
            )
        } catch {
            return [:]
        }
    }
}
