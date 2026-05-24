//
//  PreviewViewController.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import Cocoa
import ProvisionQLCore
import Quartz
import SwiftUI
import UniformTypeIdentifiers

class PreviewViewController: NSViewController, QLPreviewingController {
    private var hostingController: NSHostingController<AnyView>?

    override func loadView() {
        let placeholderView = ProvisioningPreviewView(info: nil, fileURL: nil)

        let hostingController = NSHostingController(rootView: AnyView(placeholderView))
        self.hostingController = hostingController

        view = hostingController.view
        addChild(hostingController)

        preferredContentSize = NSSize(width: 800, height: 600)
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let fileType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType

        if let contentType = fileType {
            // Check for IPA files (which conform to data) or xcarchive files (which conform to package)
            if contentType.identifier == "com.apple.itunes.ipa" ||
                contentType.identifier == "com.apple.xcode.archive"
            {
                // Handle ipa/xcarchive files
                let appInfo = try AppArchiveParser.parse(url)
                let previewView = AppArchivePreviewView(appInfo: appInfo, fileURL: url)
                hostingController?.rootView = AnyView(previewView)
            } else if contentType.identifier == "com.apple.application-and-system-extension" {
                // Handle .appex files
                let appInfo = try AppArchiveParser.parse(url)
                let previewView = AppArchivePreviewView(appInfo: appInfo, fileURL: url)
                hostingController?.rootView = AnyView(previewView)
            } else {
                // Handle provisioning profile files
                showProvisioningProfilePreview(for: url)
            }
        } else {
            // Fallback to provisioning profile parsing
            showProvisioningProfilePreview(for: url)
        }
    }

    private func showProvisioningProfilePreview(for url: URL) {
        do {
            let info = try ProvisioningParser.parse(url)
            let previewView = ProvisioningPreviewView(info: info, fileURL: url)
            hostingController?.rootView = AnyView(previewView)
        } catch {
            let previewView = FailedProvisioningProfileView(error: error, fileURL: url)
            hostingController?.rootView = AnyView(previewView)
        }
    }
}
