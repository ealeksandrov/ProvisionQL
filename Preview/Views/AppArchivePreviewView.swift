//
//  AppArchivePreviewView.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import ProvisionQLCore
import SwiftUI

struct AppArchivePreviewView: View {
    let appInfo: AppInfo
    let fileURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Padding.standard) {
                appHeader()

                GroupBox {
                    VStack(alignment: .leading, spacing: UIConstants.Padding.medium) {
                        InfoRow(label: "Version", value: appInfo.displayVersion)
                        InfoRow(label: "Bundle ID", value: appInfo.bundleIdentifier)

                        if let extensionPointIdentifier = appInfo.extensionPointIdentifier {
                            InfoRow(label: "Extension Point", value: extensionPointIdentifier)
                        }

                        if !appInfo.deviceFamily.isEmpty {
                            InfoRow(label: "Device Family", value: appInfo.deviceFamily.joined(separator: ", "))
                        }

                        if let sdkVersion = appInfo.sdkVersion {
                            Divider()
                            InfoRow(label: "SDK Version", value: sdkVersion)
                        }

                        if let minimumOS = appInfo.minimumOSVersion {
                            InfoRow(label: "Minimum OS", value: minimumOS)
                        }
                    }
                }

                if !appInfo.diagnostics.isEmpty {
                    section(title: "Diagnostics") {
                        AppDiagnosticsSection(diagnostics: appInfo.diagnostics)
                    }
                }

                if !appInfo.entitlements.isEmpty {
                    Divider()
                    section(title: "App Entitlements") {
                        EntitlementsSection(entitlements: appInfo.entitlements)
                    }
                }

                if appInfo.hasEmbeddedProfile, let profile = appInfo.embeddedProvisioningProfile {
                    Divider()
                    embeddedProfileSection(profile: profile)
                }

                if let fileURL {
                    section(title: "File Info") {
                        FileInfoSection(fileURL: fileURL)
                    }
                }

                footer()
            }
            .padding()
        }
        .frame(minWidth: UIConstants.Window.minWidth, minHeight: UIConstants.Window.minHeight)
    }
}

private extension AppArchivePreviewView {
    func appHeader() -> some View {
        HStack(alignment: .top, spacing: UIConstants.Padding.large) {
            if let icon = appInfo.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: UIConstants.Size.iconSize, height: UIConstants.Size.iconSize)
            } else {
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.large)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: UIConstants.Size.iconSize, height: UIConstants.Size.iconSize)
                    .overlay(
                        Image(systemName: isAppExtension ? "puzzlepiece.extension" : "app")
                            .font(.title)
                            .foregroundColor(.gray)
                    )
            }

            VStack(alignment: .leading, spacing: UIConstants.Padding.small) {
                Text(appInfo.name)
                    .font(.title)
                    .fontWeight(.bold)

                Text(appInfo.bundleIdentifier)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    func embeddedProfileSection(profile: ProvisioningInfo) -> some View {
        section(title: "Embedded Provisioning Profile") {
            VStack(alignment: .leading, spacing: UIConstants.Padding.standard) {
                // Profile header with smaller title
                VStack(alignment: .leading, spacing: UIConstants.Padding.medium) {
                    Text(profile.name)
                        .font(.headline)
                        .fontWeight(.semibold)

                    ProvisioningProfileHeader(profile: profile, showTitle: false)
                }

                profileContent(for: profile)
            }
        }
    }

    func profileContent(for profile: ProvisioningInfo) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Padding.standard) {
            OverviewSection(info: profile)

            if !profile.diagnostics.isEmpty {
                section(title: "Diagnostics") {
                    DiagnosticsSection(diagnostics: profile.diagnostics)
                }
            }

            if !profile.certificates.isEmpty {
                section(title: "Certificates (\(profile.certificates.count))") {
                    CertificatesSection(certificates: profile.certificates)
                }
            }

            if let devices = profile.devices, !devices.isEmpty {
                section(title: "Devices (\(devices.count))") {
                    DevicesSection(devices: devices)
                }
            }
        }
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

    var isAppExtension: Bool {
        guard let fileURL else { return false }
        return fileURL.pathExtension.lowercased() == "appex"
    }
}

struct AppDiagnosticsSection: View {
    let diagnostics: [AppDiagnostic]

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
