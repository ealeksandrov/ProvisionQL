//
//  AppArchivePreviewView.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import ProvisionQLCore
import SwiftUI

struct AppArchivePreviewView: View {
    let appInfo: AppInfo
    let iconSource: IconSource?
    let fileInfo: FileInfo

    var body: some View {
        PreviewDocument {
            AppArchiveHeader(appInfo: appInfo, iconSource: iconSource, fileInfo: fileInfo)

            GroupBox {
                appDetails
            }

            if !appInfo.diagnostics.isEmpty {
                PreviewSection(title: "Diagnostics") {
                    DiagnosticsView(diagnostics: appInfo.diagnostics)
                }
            }

            if !appInfo.entitlements.isEmpty {
                Divider()
                PreviewSection(title: "App Entitlements") {
                    EntitlementsSection(entitlements: appInfo.entitlements)
                }
            }

            if appInfo.hasEmbeddedProfile, let profile = appInfo.embeddedProvisioningProfile {
                Divider()
                EmbeddedProvisioningProfileSection(profile: profile)
            }

            PreviewSection(title: "File Info") {
                FileInfoSection(fileInfo: fileInfo)
            }

            PreviewFooter()
        }
    }

    private var appDetails: some View {
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
}
