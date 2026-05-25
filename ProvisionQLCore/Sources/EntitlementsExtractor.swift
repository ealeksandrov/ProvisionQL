//
//  EntitlementsExtractor.swift
//  Core
//
//  Created by Evgeny Aleksandrov

import Foundation
import Security

public enum EntitlementsExtractor {
    public static func extractEntitlements(from appBundleURL: URL) -> [String: PlistValue] {
        extractEntitlementsUsingSecCode(from: appBundleURL) ?? [:]
    }

    static func extractEntitlementsFromArchive(
        executableData: Data,
        temporaryDirectory: URL
    ) -> [String: PlistValue] {
        // Write executable to temporary file
        let tempExecutableURL = temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            try executableData.write(to: tempExecutableURL)
            defer { try? FileManager.default.removeItem(at: tempExecutableURL) }

            // Make it executable
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: tempExecutableURL.path
            )

            return extractEntitlementsUsingSecCode(from: tempExecutableURL) ?? [:]
        } catch {
            return [:]
        }
    }
}

private extension EntitlementsExtractor {
    static func extractEntitlementsUsingSecCode(from codeURL: URL) -> [String: PlistValue]? {
        var staticCode: SecStaticCode?
        var status = SecStaticCodeCreateWithPath(codeURL as CFURL, [], &staticCode)

        guard status == errSecSuccess, let staticCode else {
            return nil
        }

        var signature: CFDictionary?
        status = SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &signature)

        guard status == errSecSuccess, let signature else {
            return nil
        }

        let signatureDict = signature as NSDictionary

        // Extract entitlements from the signing information
        guard let entitlementsData = signatureDict[kSecCodeInfoEntitlementsDict as String] as? [String: Any] else {
            return nil
        }

        guard let entitlementsValue = PlistValue.from(value: entitlementsData) else {
            return nil
        }

        guard case .dictionary(let entitlements) = entitlementsValue else {
            return nil
        }

        return entitlements
    }
}
