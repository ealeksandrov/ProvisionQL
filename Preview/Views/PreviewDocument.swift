import SwiftUI

struct PreviewDocument<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Padding.standard) {
                content
            }
            .padding()
        }
        .frame(minWidth: UIConstants.Window.minWidth, minHeight: UIConstants.Window.minHeight)
    }
}
