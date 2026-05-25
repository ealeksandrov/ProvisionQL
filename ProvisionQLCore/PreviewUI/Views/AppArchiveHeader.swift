import ProvisionQLCore
import SwiftUI

struct AppArchiveHeader: View {
    let appInfo: AppInfo
    let iconSource: IconSource?
    let fileInfo: FileInfo

    var body: some View {
        HStack(alignment: .top, spacing: UIConstants.Padding.large) {
            iconView

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

    @ViewBuilder
    private var iconView: some View {
        if let icon = iconSource?.makeImage() {
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
    }

    private var isAppExtension: Bool {
        appInfo.extensionPointIdentifier != nil || fileInfo.fileName.lowercased().hasSuffix(".appex")
    }
}
