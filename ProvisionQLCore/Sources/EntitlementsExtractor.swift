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

    static func extractEntitlements(fromCodeAt codeURL: URL) -> [String: PlistValue] {
        extractEntitlementsUsingSecCode(from: codeURL) ?? [:]
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
