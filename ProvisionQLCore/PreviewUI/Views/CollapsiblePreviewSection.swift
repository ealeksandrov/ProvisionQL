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
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggleExpanded) {
                HStack(spacing: UIConstants.Padding.medium) {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.15), value: isExpanded)

                    Text(title)
                        .fontWeight(.semibold)
                        .font(.title2)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .padding(.top, UIConstants.Padding.medium)
            }
        }
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isExpanded.toggle()
        }
    }
}
