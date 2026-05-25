import Foundation
import ZIPFoundation

enum AppBundleContainerKind {
    case ipa
    case directory
}

enum AppBundleStyle {
    case iOS
    case macOS
}

protocol AppBundleSource {
    var containerKind: AppBundleContainerKind { get }
    var bundleStyle: AppBundleStyle { get }

    func data(
        at path: String,
        relativeToBundle: Bool,
        caseInsensitive: Bool
    ) throws -> Data?

    func writeFile(
        at path: String,
        relativeToBundle: Bool,
        to destinationURL: URL
    ) throws -> Bool

    func infoPlistData() throws -> Data
    func extractEntitlements(infoPlist: [String: Any]) -> [String: PlistValue]
}

extension AppBundleSource {
    func infoPlist() throws -> [String: Any] {
        try PlistParser.parse(data: infoPlistData())
    }

    func embeddedProvisioningProfile() -> EmbeddedProvisioningProfileExtraction {
        do {
            for relativePath in ProvisioningProfileExtractor.embeddedProvisioningProfilePaths {
                if let profileData = try data(
                    at: relativePath,
                    relativeToBundle: true,
                    caseInsensitive: false
                ) {
                    return ProvisioningProfileExtractor.extract(from: profileData)
                }
            }

            return .missing
        } catch {
            return .failure(error)
        }
    }
}

struct IPAAppBundleSource: AppBundleSource {
    let containerKind = AppBundleContainerKind.ipa
    let bundleStyle = AppBundleStyle.iOS

    private let archive: Archive
    private let appBundlePath: String

    init(url: URL) throws {
        archive = try Archive(url: url, accessMode: .read)
        appBundlePath = try ArchiveUtilities.findAppBundlePath(in: archive, archiveType: .ipa)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func data(
        at path: String,
        relativeToBundle: Bool,
        caseInsensitive: Bool
    ) throws -> Data? {
        let archivePath = archivePath(for: path, relativeToBundle: relativeToBundle)

        if caseInsensitive {
            return try ArchiveUtilities.extractFileOptional(from: archive, path: archivePath)
        }

        return try? ArchiveUtilities.extractFile(from: archive, path: archivePath)
    }

    func writeFile(
        at path: String,
        relativeToBundle: Bool,
        to destinationURL: URL
    ) throws -> Bool {
        try ArchiveUtilities.extractFileOptional(
            from: archive,
            path: archivePath(for: path, relativeToBundle: relativeToBundle),
            to: destinationURL
        )
    }

    func infoPlistData() throws -> Data {
        guard let infoPlistData = try data(
            at: "Info.plist",
            relativeToBundle: true,
            caseInsensitive: false
        ) else {
            throw ParsingError.missingInfoPlist
        }

        return infoPlistData
    }

    func extractEntitlements(infoPlist: [String: Any]) -> [String: PlistValue] {
        guard let executableName = PlistParser.extractExecutableName(from: infoPlist) else {
            return [:]
        }

        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let executableURL = temporaryDirectory.appendingPathComponent(executableName)

        do {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

            guard try writeFile(at: executableName, relativeToBundle: true, to: executableURL) else {
                return [:]
            }

            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: executableURL.path
            )

            return EntitlementsExtractor.extractEntitlements(fromCodeAt: executableURL)
        } catch {
            return [:]
        }
    }

    private func archivePath(for path: String, relativeToBundle: Bool) -> String {
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard relativeToBundle else {
            return normalizedPath
        }

        return appBundlePath + "/" + normalizedPath
    }
}

struct DirectoryAppBundleSource: AppBundleSource {
    let containerKind = AppBundleContainerKind.directory
    let bundleStyle: AppBundleStyle

    private let bundleURL: URL
    private let infoPlistURL: URL

    init(bundleURL: URL) throws {
        self.bundleURL = bundleURL

        let macInfoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        if FileManager.default.fileExists(atPath: macInfoPlistURL.path) {
            bundleStyle = .macOS
            infoPlistURL = macInfoPlistURL
        } else {
            bundleStyle = .iOS
            infoPlistURL = bundleURL.appendingPathComponent("Info.plist")
        }

        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            throw ParsingError.missingInfoPlist
        }
    }

    func data(
        at path: String,
        relativeToBundle: Bool,
        caseInsensitive _: Bool
    ) throws -> Data? {
        let fileURL = url(for: path, relativeToBundle: relativeToBundle)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return try Data(contentsOf: fileURL)
    }

    func writeFile(
        at path: String,
        relativeToBundle: Bool,
        to destinationURL: URL
    ) throws -> Bool {
        let fileURL = url(for: path, relativeToBundle: relativeToBundle)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return false
        }

        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: fileURL, to: destinationURL)
        return true
    }

    func infoPlistData() throws -> Data {
        try Data(contentsOf: infoPlistURL)
    }

    func extractEntitlements(infoPlist _: [String: Any]) -> [String: PlistValue] {
        EntitlementsExtractor.extractEntitlements(from: bundleURL)
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

    private func url(for path: String, relativeToBundle: Bool) -> URL {
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard relativeToBundle else {
            return URL(fileURLWithPath: normalizedPath)
        }

        return bundleURL.appendingPathComponent(normalizedPath)
    }

    private static func applicationPathInXCArchive(at archiveURL: URL) -> String? {
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

    private static func isAppBundle(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return url.pathExtension == "app"
            && FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}
