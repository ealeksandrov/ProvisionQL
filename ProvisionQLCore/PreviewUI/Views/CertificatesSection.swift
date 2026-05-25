//
//  CertificatesSection.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import ProvisionQLCore
import SwiftUI

struct CertificatesSection: View {
    let certificates: [CertificateInfo]

    var body: some View {
        TableSection(data: certificates) {
            HStack {
                Text("Subject")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Expires")
                    .fontWeight(.semibold)
                    .frame(width: UIConstants.Width.dateColumn, alignment: .trailing)
            }
        } rowContent: { certificate in
            HStack {
                Text(certificate.subject)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)

                if let expirationDate = certificate.expirationDate {
                    let isExpired = expirationDate < Date()
                    Text(expirationDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(isExpired ? .red : .primary)
                        .frame(width: UIConstants.Width.dateColumn, alignment: .trailing)
                } else {
                    Text("Unknown")
                        .foregroundColor(.secondary)
                        .frame(width: UIConstants.Width.dateColumn, alignment: .trailing)
                }
            }
        }
    }
}
