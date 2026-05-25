import Foundation

public struct AppArchiveParseResult: Sendable, Codable, Hashable {
    public let appInfo: AppInfo
    public let iconSource: IconSource?

    public init(appInfo: AppInfo, iconSource: IconSource? = nil) {
        self.appInfo = appInfo
        self.iconSource = iconSource
    }
}
