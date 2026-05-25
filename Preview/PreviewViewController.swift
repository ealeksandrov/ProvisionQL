//
//  PreviewViewController.swift
//  Preview
//
//  Created by Evgeny Aleksandrov

import Cocoa
import PreviewUI
import Quartz
import SwiftUI

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
