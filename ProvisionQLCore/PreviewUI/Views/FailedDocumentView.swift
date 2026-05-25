import Foundation
import ProvisionQLCore
import SwiftUI

struct PreviewFailure: Hashable {
    let message: String
    let missingFields: [String]

    init(error: Error) {
        message = error.localizedDescription

        if let error = error as? ProvisioningProfileValidationError {
            missingFields = error.missingFields
        } else {
            missingFields = []
        }
    }
}

struct FailedDocumentView: View {
    let failure: PreviewFailure
    let fileInfo: FileInfo

    var body: some View {
        PreviewDocument {
            Text("\(fileInfo.fileName) could not be parsed")
                .font(.title)
                .fontWeight(.bold)

            GroupBox {
                VStack(alignment: .leading, spacing: UIConstants.Padding.medium) {
                    Text(failure.message)
                        .textSelection(.enabled)

                    if !failure.missingFields.isEmpty {
                        Divider()

                        InfoRow(label: "Missing", value: failure.missingFields.joined(separator: ", "))
                    }
                }
            }

            PreviewSection(title: "File Info") {
                FileInfoSection(fileInfo: fileInfo)
            }

            PreviewFooter()
        }
    }
}
