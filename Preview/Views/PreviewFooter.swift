import SwiftUI

struct PreviewFooter: View {
    var body: some View {
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
