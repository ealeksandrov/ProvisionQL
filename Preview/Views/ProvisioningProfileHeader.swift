//
//  ProvisioningProfileHeader.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import ProvisionQLCore
import SwiftUI

struct ProvisioningProfileHeader: View {
    let profile: ProvisioningInfo
    let showTitle: Bool

    init(profile: ProvisioningInfo, showTitle: Bool = true) {
        self.profile = profile
        self.showTitle = showTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: showTitle ? UIConstants.Padding.standard : UIConstants.Padding.medium) {
            if showTitle {
                Text(profile.name)
                    .font(.title)
                    .fontWeight(.bold)
            }

            HStack(spacing: UIConstants.Padding.standard) {
                StatusBadge(
                    text: profile.platform.map(\.rawValue).joined(separator: ", "),
                    color: .blue
                )

                StatusBadge(
                    text: profile.profileType.rawValue,
                    color: profile.profileType.color
                )

                StatusBadge(
                    text: profile.expirationStatus.rawValue,
                    color: profile.expirationStatus.color
                )

                if profile.signerStatus != .unknown {
                    StatusBadge(
                        text: profile.signerStatus.rawValue,
                        color: profile.signerStatus.color
                    )
                }

                if !profile.certificates.isEmpty {
                    StatusBadge(
                        text: "\(profile.certificates.count) certs",
                        color: .indigo
                    )
                }

                if let deviceCount = profile.devices?.count {
                    StatusBadge(
                        text: "\(deviceCount) devices",
                        color: .indigo
                    )
                }
            }
        }
    }
}
