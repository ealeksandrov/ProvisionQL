//
//  OverviewSection.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import ProvisionQLCore
import SwiftUI

struct OverviewSection: View {
    let info: ProvisioningInfo

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: UIConstants.Padding.medium) {
                InfoRow(label: "UUID", value: info.uuid)
                InfoRow(label: "Team", value: "\(info.teamName) (\(info.teamID))")
                InfoRow(label: "App ID", value: info.appID)
                Divider()
                InfoRow(label: "Created", value: info.creationDate.formatted(date: .long, time: .shortened))
                InfoRow(label: "Expires", value: info.expirationDate.formatted(date: .long, time: .shortened))
                    .foregroundColor(info.expirationStatus.color)
            }
        }
    }
}
