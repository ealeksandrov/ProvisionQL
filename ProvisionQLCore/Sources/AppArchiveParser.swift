//
//  AppArchiveParser.swift
//  Core
//
//  Created by Evgeny Aleksandrov

import Foundation

public enum AppArchiveParser {
    public static func parse(_ url: URL) throws -> AppInfo {
        try parseWithResources(url).appInfo
    }

    public static func parseWithResources(_ url: URL) throws -> AppArchiveParseResult {
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "ipa", "tipa":
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
    static func parseIPA(_ url: URL) throws -> AppArchiveParseResult {
        let source = try IPAAppBundleSource(url: url)
        return try parseApp(from: source)
    }

    static func parseXCArchive(_ url: URL) throws -> AppArchiveParseResult {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw ParsingError.invalidArchiveFormat
        }

        let appBundleURL = try DirectoryAppBundleSource.findAppBundleInXCArchive(at: url)
        let source = try DirectoryAppBundleSource(bundleURL: appBundleURL)
        return try parseApp(from: source)
    }

    static func parseAppExtension(_ url: URL) throws -> AppArchiveParseResult {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw ParsingError.invalidArchiveFormat
        }

        let source = try DirectoryAppBundleSource(bundleURL: url)
        return try parseApp(from: source, isAppExtension: true)
    }

    static func parseApp(from source: AppBundleSource, isAppExtension: Bool = false) throws -> AppArchiveParseResult {
        let plist = try source.infoPlist()

        let parsedAppInfo = PlistParser.extractAppInfo(from: plist)

        let iconSource = try? IconExtractor.extractIconSource(from: source)
        let embeddedProfile = source.embeddedProvisioningProfile()

        var extensionType: String?
        var extensionPointIdentifier: String?
        if isAppExtension,
           let nsExtension = plist["NSExtension"] as? [String: Any],
           let identifier = nsExtension["NSExtensionPointIdentifier"] as? String
        {
            extensionPointIdentifier = identifier
            extensionType = parseExtensionType(from: identifier)
        }

        let displayName = if isAppExtension, let extensionType {
            "\(parsedAppInfo.name) (\(extensionType))"
        } else {
            parsedAppInfo.name
        }

        let entitlements = source.extractEntitlements(infoPlist: plist)

        let appInfo = AppInfo(
            name: displayName,
            bundleIdentifier: parsedAppInfo.bundleIdentifier,
            version: parsedAppInfo.version,
            buildNumber: parsedAppInfo.buildNumber,
            embeddedProvisioningProfile: embeddedProfile.profile,
            entitlements: entitlements,
            deviceFamily: parsedAppInfo.deviceFamily,
            minimumOSVersion: parsedAppInfo.minimumOSVersion,
            sdkVersion: parsedAppInfo.sdkVersion,
            extensionPointIdentifier: extensionPointIdentifier,
            diagnostics: embeddedProfile.diagnostics
        )

        return AppArchiveParseResult(appInfo: appInfo, iconSource: iconSource)
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
}
