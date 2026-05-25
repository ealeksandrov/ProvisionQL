//
//  DevicesSection.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import ProvisionQLCore
import SwiftUI

struct DevicesSection: View {
    let devices: [String]

    var sortedDevices: [String] {
        devices.sorted()
    }

    var body: some View {
        TableSection(data: sortedDevices) {
            HStack {
                Text("Device UDID")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } rowContent: { device in
            HStack {
                Text(device)
                    .codeText()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
