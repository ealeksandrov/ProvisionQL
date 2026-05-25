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

        var decoder: CMSDecoder?
        guard CMSDecoderCreate(&decoder) == errSecSuccess,
              let cmsDecoder = decoder
        else {
            throw ParsingError.cmsDecodingFailed
        }

        guard CMSDecoderUpdateMessage(cmsDecoder, Array(fileData), fileData.count) == errSecSuccess,
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

        let profile = try PropertyListDecoder().decode(RawProfile.self, from: plistData)

        return try ProvisioningInfo(from: profile)
    }

    public static func fetchBadgeInfo(from url: URL) throws -> BadgeInfo {
        let info = try parse(url)
        return BadgeInfo(from: info)
    }
}
