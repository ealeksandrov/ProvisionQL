import SwiftUI

struct PreviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .fontWeight(.semibold)
                .font(.title2)

            content
        }
    }
}
