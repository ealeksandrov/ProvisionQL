//
//  PreviewViewController.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import Cocoa
import Observation
import ProvisionQLCore
import Quartz
import SwiftUI
import UniformTypeIdentifiers

class PreviewViewController: NSViewController, QLPreviewingController {
    private let model = PreviewModel()
    private var hostingController: NSHostingController<PreviewRootView>?

    override func loadView() {
        let hostingController = NSHostingController(rootView: PreviewRootView(model: model))
        self.hostingController = hostingController

        view = hostingController.view
        addChild(hostingController)

        preferredContentSize = NSSize(width: 800, height: 600)
    }

    func preparePreviewOfFile(at url: URL) async throws {
        await model.previewRequested(for: url)
    }
}

@MainActor
@Observable
final class PreviewModel {
    var content: PreviewContent = .loading

    func previewRequested(for url: URL) async {
        content = .loading

        do {
            content = try await Self.loadContent(for: url)
        } catch {
            let fileInfo = await Self.fileInfo(for: url)
            content = .failed(error, url, fileInfo)
        }
    }
}

private extension PreviewModel {
    static func loadContent(for url: URL) async throws -> PreviewContent {
        let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType

        if let contentType, contentType.isAppArchive {
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

        return .archive(result.appInfo, result.iconSource?.makeImage(), fileInfo)
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
    case archive(AppInfo, NSImage?, FileInfo)
    case failed(Error, URL, FileInfo)
}

struct PreviewRootView: View {
    let model: PreviewModel

    var body: some View {
        switch model.content {
        case .loading:
            ProgressView()
                .frame(minWidth: UIConstants.Window.minWidth, minHeight: UIConstants.Window.minHeight)
        case .profile(let info, let fileInfo):
            ProvisioningPreviewView(info: info, fileInfo: fileInfo)
        case .archive(let appInfo, let icon, let fileInfo):
            AppArchivePreviewView(appInfo: appInfo, icon: icon, fileInfo: fileInfo)
        case .failed(let error, let fileURL, let fileInfo):
            FailedDocumentView(error: error, fileURL: fileURL, fileInfo: fileInfo)
        }
    }
}

private extension UTType {
    var isAppArchive: Bool {
        switch identifier {
        case "com.apple.itunes.ipa",
             "com.apple.xcode.archive",
             "com.apple.application-and-system-extension":
            true
        default:
            false
        }
    }
}
