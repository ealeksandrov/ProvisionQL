//
//  ProvisioningPreviewView.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import ProvisionQLCore
import Quartz
import SwiftUI

struct ProvisioningPreviewView: View {
    let info: ProvisioningInfo
    let fileInfo: FileInfo

    var body: some View {
        documentContent(for: info)
    }
}

private extension ProvisioningPreviewView {
    func documentContent(for info: ProvisioningInfo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Padding.standard) {
                header(for: info)

                OverviewSection(info: info)

                if !info.diagnostics.isEmpty {
                    section(title: "Diagnostics") {
                        DiagnosticsSection(diagnostics: info.diagnostics)
                    }
                }

                if !info.entitlements.isEmpty {
                    section(title: "Entitlements") {
                        EntitlementsSection(entitlements: info.entitlements)
                    }
                }

                if !info.certificates.isEmpty {
                    section(title: "Certificates (\(info.certificates.count))") {
                        CertificatesSection(certificates: info.certificates)
                    }
                }

                if let devices = info.devices, !devices.isEmpty {
                    section(title: "Devices (\(devices.count))") {
                        DevicesSection(devices: devices)
                    }
                }

                section(title: "File Info") {
                    FileInfoSection(fileInfo: fileInfo)
                }

                footer()
            }
            .padding()
        }
        .frame(minWidth: UIConstants.Window.minWidth, minHeight: UIConstants.Window.minHeight)
    }

    func header(for info: ProvisioningInfo) -> some View {
        ProvisioningProfileHeader(profile: info)
    }

    func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .fontWeight(.semibold)
                .font(.title2)

            content()
        }
    }

    func footer() -> some View {
        HStack {
            Text("ProvisionQL \(AppVersion.versionString)")

            #if DEBUG
                Text("(debug)")
            #endif

            Spacer()
        }
        .foregroundColor(.secondary)
        .font(.subheadline)
        .frame(maxWidth: .infinity)
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

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, UIConstants.Padding.medium)
            .padding(.vertical, UIConstants.Padding.small)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(UIConstants.CornerRadius.small)
    }
}

struct DiagnosticsSection: View {
    let diagnostics: [ProvisioningDiagnostic]

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: UIConstants.Padding.medium) {
                ForEach(diagnostics, id: \.self) { diagnostic in
                    HStack(alignment: .top, spacing: UIConstants.Padding.medium) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)

                        Text(diagnostic.message)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

struct FailedDocumentView: View {
    let error: Error
    let fileInfo: FileInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Padding.standard) {
                Text("\(fileInfo.fileName) could not be parsed")
                    .font(.title)
                    .fontWeight(.bold)

                GroupBox {
                    VStack(alignment: .leading, spacing: UIConstants.Padding.medium) {
                        Text(error.localizedDescription)
                            .textSelection(.enabled)

                        if !missingFields.isEmpty {
                            Divider()

                            InfoRow(label: "Missing", value: missingFields.joined(separator: ", "))
                        }
                    }
                }

                section(title: "File Info") {
                    FileInfoSection(fileInfo: fileInfo)
                }

                footer()
            }
            .padding()
        }
        .frame(minWidth: UIConstants.Window.minWidth, minHeight: UIConstants.Window.minHeight)
    }

    func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .fontWeight(.semibold)
                .font(.title2)

            content()
        }
    }

    func footer() -> some View {
        HStack {
            Text("ProvisionQL \(AppVersion.versionString)")

            #if DEBUG
                Text("(debug)")
            #endif

            Spacer()
        }
        .foregroundColor(.secondary)
        .font(.subheadline)
        .frame(maxWidth: .infinity)
    }

    var missingFields: [String] {
        guard let error = error as? ProvisioningProfileValidationError else {
            return []
        }

        return error.missingFields
    }
}
