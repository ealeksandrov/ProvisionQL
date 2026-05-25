import ProvisionQLCore
import SwiftUI

extension ExpirationStatus {
    var color: Color {
        switch self {
        case .expired: .red
        case .expiring: .orange
        case .valid: UIConstants.Color.validGreen
        }
    }
}

extension ProvisioningInfo.ProfileType {
    var color: Color {
        switch self {
        case .development: .blue
        case .adHoc: .purple
        case .appStore: UIConstants.Color.validGreen
        case .enterprise: .orange
        case .developerID: .indigo
        case .directDistribution: .indigo
        }
    }
}

extension ProvisioningInfo.SignerStatus {
    var color: Color {
        switch self {
        case .signedByAppleWWDR: UIConstants.Color.validGreen
        case .signed: .indigo
        case .unsigned: .orange
        case .invalidSignature, .invalidCertificate: .red
        case .needsDetachedContent, .unknown: .secondary
        }
    }
}
