import AppKit

enum AboutPanel {
    static let repositoryURL = URL(string: "https://github.com/ealeksandrov/ProvisionQL")!

    @MainActor
    static func show() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits
        ])
    }

    private static var credits: NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        return NSAttributedString(
            string: "GitHub",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.linkColor,
                .link: repositoryURL,
                .paragraphStyle: paragraphStyle,
            ]
        )
    }
}
