import Foundation
import Observation
import ProvisionQLCore
import UniformTypeIdentifiers

@MainActor
@Observable
public final class PreviewModel {
    var content: PreviewContent = .loading

    public init() {}

    public func previewRequested(for url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        content = .loading

        do {
            content = try await Self.loadContent(for: url)
        } catch {
            let fileInfo = await Self.fileInfo(for: url)
            content = .failed(PreviewFailure(error: error), fileInfo)
        }
    }
}

private extension PreviewModel {
    static func loadContent(for url: URL) async throws -> PreviewContent {
        let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType

        if let contentType, PreviewSupportedContentTypes.isAppArchive(contentType) {
            return try await loadAppArchiveContent(for: url)
        }

        return try await loadProvisioningProfileContent(for: url)
    }

    static func loadAppArchiveContent(for url: URL) async throws -> PreviewContent {
        let (result, fileInfo) = try await Task.detached(priority: .userInitiated) {
            let result = try AppArchiveParser.parseWithResources(url)
            let fileInfo = FileInfo(fileURL: url)
            return (result, fileInfo)
        }.value

        return .archive(result.appInfo, result.iconSource, fileInfo)
    }

    static func loadProvisioningProfileContent(for url: URL) async throws -> PreviewContent {
        let (info, fileInfo) = try await Task.detached(priority: .userInitiated) {
            let info = try ProvisioningParser.parse(url)
            let fileInfo = FileInfo(fileURL: url)
            return (info, fileInfo)
        }.value

        return .profile(info, fileInfo)
    }

    static func fileInfo(for url: URL) async -> FileInfo {
        await Task.detached(priority: .utility) {
            FileInfo(fileURL: url)
        }.value
    }
}

enum PreviewContent {
    case loading
    case profile(ProvisioningInfo, FileInfo)
    case archive(AppInfo, IconSource?, FileInfo)
    case failed(PreviewFailure, FileInfo)
}
