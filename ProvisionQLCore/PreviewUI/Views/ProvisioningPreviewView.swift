//
//  ProvisioningPreviewView.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import ProvisionQLCore
import SwiftUI

struct ProvisioningPreviewView: View {
    let info: ProvisioningInfo
    let fileInfo: FileInfo

    var body: some View {
        PreviewDocument {
            ProvisioningProfileHeader(profile: info)

            OverviewSection(info: info)

            if !info.diagnostics.isEmpty {
                PreviewSection(title: "Diagnostics") {
                    DiagnosticsView(diagnostics: info.diagnostics)
                }
            }

            if !info.entitlements.isEmpty {
                PreviewSection(title: "Entitlements") {
                    EntitlementsSection(entitlements: info.entitlements)
                }
            }

            if !info.certificates.isEmpty {
                PreviewSection(title: "Certificates (\(info.certificates.count))") {
                    CertificatesSection(certificates: info.certificates)
                }
            }

            if let devices = info.devices, !devices.isEmpty {
                PreviewSection(title: "Devices (\(devices.count))") {
                    DevicesSection(devices: devices)
                }
            }

            PreviewSection(title: "File Info") {
                FileInfoSection(fileInfo: fileInfo)
            }

            PreviewFooter()
        }
    }
}
