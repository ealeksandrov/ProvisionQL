import Foundation

public struct ProvisioningProfileValidationError: Error, LocalizedError, Sendable, Hashable {
    public let missingFields: [String]

    public init(missingFields: [String]) {
        self.missingFields = missingFields
    }

    public var errorDescription: String? {
        guard !missingFields.isEmpty else {
            return "Malformed provisioning profile"
        }

        return "Malformed provisioning profile: missing required fields: \(missingFields.joined(separator: ", "))"
    }
}
