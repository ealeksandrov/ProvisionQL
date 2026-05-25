import ProvisionQLCore
import SwiftUI

struct EmbeddedProvisioningProfileSection: View {
    let profile: ProvisioningInfo

    var body: some View {
        PreviewSection(title: "Embedded Provisioning Profile") {
            VStack(alignment: .leading, spacing: UIConstants.Padding.standard) {
                VStack(alignment: .leading, spacing: UIConstants.Padding.medium) {
                    Text(profile.name)
                        .font(.headline)
                        .fontWeight(.semibold)

                    ProvisioningProfileHeader(profile: profile, showTitle: false)
                }

                profileContent
            }
        }
    }

    private var profileContent: some View {
        VStack(alignment: .leading, spacing: UIConstants.Padding.standard) {
            OverviewSection(info: profile)

            if !profile.diagnostics.isEmpty {
                PreviewSection(title: "Diagnostics") {
                    DiagnosticsView(diagnostics: profile.diagnostics)
                }
            }

            if !profile.certificates.isEmpty {
                PreviewSection(title: "Certificates (\(profile.certificates.count))") {
                    CertificatesSection(certificates: profile.certificates)
                }
            }

            if let devices = profile.devices, !devices.isEmpty {
                PreviewSection(title: "Devices (\(devices.count))") {
                    DevicesSection(devices: devices)
                }
            }
        }
    }
}
