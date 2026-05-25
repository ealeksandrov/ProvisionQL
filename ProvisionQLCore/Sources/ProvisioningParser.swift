//
//  ProvisioningParser.swift
//  Core
//
//  Created by Evgeny Aleksandrov

import Foundation
import Security

public enum ProvisioningParser {
    public static func parse(_ url: URL) throws -> ProvisioningInfo {
        let fileData = try Data(contentsOf: url)
        return try parse(fileData)
    }

    public static func parse(_ data: Data) throws -> ProvisioningInfo {
        let decodedCMS = try decodeCMS(data)
        let profile = try PropertyListDecoder().decode(RawProfile.self, from: decodedCMS.plistData)

        return try ProvisioningInfo(from: profile, signerStatus: decodedCMS.signerStatus)
    }

    public static func fetchBadgeInfo(from url: URL) throws -> BadgeInfo {
        let info = try parse(url)
        return BadgeInfo(from: info)
    }
}

private extension ProvisioningParser {
    static func decodeCMS(_ fileData: Data) throws -> (plistData: Data, signerStatus: ProvisioningInfo.SignerStatus) {
        var decoder: CMSDecoder?
        guard CMSDecoderCreate(&decoder) == errSecSuccess,
              let cmsDecoder = decoder
        else {
            throw ParsingError.cmsDecodingFailed
        }

        let updateStatus = fileData.withUnsafeBytes { buffer -> OSStatus in
            guard let baseAddress = buffer.baseAddress else {
                return errSecParam
            }

            return CMSDecoderUpdateMessage(cmsDecoder, baseAddress, fileData.count)
        }

        guard updateStatus == errSecSuccess,
              CMSDecoderFinalizeMessage(cmsDecoder) == errSecSuccess
        else {
            throw ParsingError.cmsDecodingFailed
        }

        var decodedData: CFData?
        guard CMSDecoderCopyContent(cmsDecoder, &decodedData) == errSecSuccess,
              let plistData = decodedData as Data?
        else {
            throw ParsingError.plistExtractionFailed
        }

        return (plistData, signerStatus(for: cmsDecoder))
    }

    static func signerStatus(for cmsDecoder: CMSDecoder) -> ProvisioningInfo.SignerStatus {
        var signerCount = 0
        guard CMSDecoderGetNumSigners(cmsDecoder, &signerCount) == errSecSuccess else {
            return .unknown
        }

        guard signerCount > 0 else {
            return .unsigned
        }

        let policy = SecPolicyCreateBasicX509()
        var bestStatus = ProvisioningInfo.SignerStatus.unknown

        for signerIndex in 0 ..< signerCount {
            var cmsSignerStatus = CMSSignerStatus.unsigned

            guard CMSDecoderCopySignerStatus(
                cmsDecoder,
                signerIndex,
                policy,
                true,
                &cmsSignerStatus,
                nil,
                nil
            ) == errSecSuccess else {
                continue
            }

            switch cmsSignerStatus {
            case .valid:
                if signerIsAppleWWDR(cmsDecoder, signerIndex: signerIndex) {
                    return .signedByAppleWWDR
                }
                bestStatus = .signed
            case .unsigned:
                bestStatus = .unsigned
            case .invalidSignature:
                return .invalidSignature
            case .invalidCert:
                return .invalidCertificate
            case .needsDetachedContent:
                bestStatus = .needsDetachedContent
            case .invalidIndex:
                continue
            default:
                continue
            }
        }

        return bestStatus
    }

    static func signerIsAppleWWDR(_ cmsDecoder: CMSDecoder, signerIndex: Int) -> Bool {
        var signerCertificate: SecCertificate?
        guard CMSDecoderCopySignerCert(cmsDecoder, signerIndex, &signerCertificate) == errSecSuccess,
              let signerCertificate
        else {
            return false
        }

        let summary = SecCertificateCopySubjectSummary(signerCertificate) as String? ?? ""
        return summary.localizedCaseInsensitiveContains("Apple Worldwide Developer Relations")
    }
}
