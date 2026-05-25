import Foundation

public struct ProvisioningDiagnostic: Sendable, Codable, Hashable {
    public enum Severity: String, Sendable, Codable, Hashable {
        case warning
    }

    public enum Code: String, Sendable, Codable, Hashable {
        case invalidDeveloperCertificate
        case missingPlatform
    }

    public let severity: Severity
    public let code: Code
    public let message: String

    public init(severity: Severity, code: Code, message: String) {
        self.severity = severity
        self.code = code
        self.message = message
    }
}
