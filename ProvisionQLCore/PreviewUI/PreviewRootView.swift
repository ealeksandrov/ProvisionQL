import SwiftUI

public struct PreviewRootView: View {
    let model: PreviewModel

    public init(model: PreviewModel) {
        self.model = model
    }

    public var body: some View {
        switch model.content {
        case .loading:
            ProgressView()
                .frame(minWidth: UIConstants.Window.minWidth, minHeight: UIConstants.Window.minHeight)
        case .profile(let info, let fileInfo):
            ProvisioningPreviewView(info: info, fileInfo: fileInfo)
        case .archive(let appInfo, let iconSource, let fileInfo):
            AppArchivePreviewView(appInfo: appInfo, iconSource: iconSource, fileInfo: fileInfo)
        case .failed(let failure, let fileInfo):
            FailedDocumentView(failure: failure, fileInfo: fileInfo)
        }
    }
}
