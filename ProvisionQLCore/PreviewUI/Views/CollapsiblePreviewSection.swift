import SwiftUI

struct CollapsiblePreviewSection<Content: View>: View {
    let title: String
    let content: Content
    @State private var isExpanded: Bool

    init(
        title: String,
        isExpanded: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
        _isExpanded = State(initialValue: isExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
                .padding(.top, UIConstants.Padding.medium)
        } label: {
            Text(title)
                .fontWeight(.semibold)
                .font(.title2)
        }
    }
}
