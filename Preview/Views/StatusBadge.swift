import SwiftUI

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
