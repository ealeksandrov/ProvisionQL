import Foundation
import Observation
import PreviewUI

@MainActor
@Observable
final class HostAppModel {
    let previewModel: PreviewModel
    var extensionHintDismissed = false
    var openedFileName: String?

    var hasOpenedFile: Bool {
        openedFileName != nil
    }

    var windowTitle: String {
        openedFileName ?? "ProvisionQL"
    }

    init(previewModel: PreviewModel = PreviewModel()) {
        self.previewModel = previewModel
    }

    func previewRequested(for url: URL) async {
        openedFileName = url.lastPathComponent
        await previewModel.previewRequested(for: url)
    }
}
