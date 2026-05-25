import AppKit
import Foundation

public struct IconSource: Sendable, Codable, Hashable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    public func makeImage() -> NSImage? {
        guard let image = NSImage(data: data) else {
            return nil
        }

        return IconExtractor.applyRoundedCorners(to: image)
    }
}
