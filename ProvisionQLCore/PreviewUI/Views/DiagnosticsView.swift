import ProvisionQLCore
import SwiftUI

protocol PreviewDiagnosticItem: Hashable {
    var message: String { get }
}

extension AppDiagnostic: PreviewDiagnosticItem {}
extension ProvisioningDiagnostic: PreviewDiagnosticItem {}

struct DiagnosticsView<Diagnostic: PreviewDiagnosticItem>: View {
    let diagnostics: [Diagnostic]

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
