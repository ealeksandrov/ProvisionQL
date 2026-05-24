//
//  CertificateInfo.swift
//  Core
//
//  Created by Evgeny Aleksandrov

import Foundation
import Security

public struct CertificateInfo: Sendable, Codable, Hashable {
    public let subject: String
    public let expirationDate: Date?
}

extension CertificateInfo {
    static func from(data: Data) -> CertificateInfo? {
        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
            return nil
        }

        let subject = SecCertificateCopySubjectSummary(certificate) as String? ?? "Unknown"

        // Try to get expiration date
        var expirationDate: Date?
        var error: Unmanaged<CFError>?
        if let values = SecCertificateCopyValues(
            certificate,
            [kSecOIDX509V1ValidityNotAfter] as CFArray,
            &error
        ) as? [CFString: Any],
            let validityDict = values[kSecOIDX509V1ValidityNotAfter] as? [CFString: Any],
            let dateValue = validityDict[kSecPropertyKeyValue]
        {
            if let dateValue = dateValue as? Date {
                expirationDate = dateValue
            } else if let timeInterval = dateValue as? NSNumber {
                expirationDate = Date(timeIntervalSinceReferenceDate: timeInterval.doubleValue)
            }
        }

        return CertificateInfo(
            subject: subject,
            expirationDate: expirationDate
        )
    }
}
