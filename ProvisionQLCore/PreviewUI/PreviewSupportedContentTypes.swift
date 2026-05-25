import UniformTypeIdentifiers

public enum PreviewSupportedContentTypes {
    public static let ipa = UTType(importedAs: "com.apple.itunes.ipa")
    public static let trollStoreIPA = UTType(importedAs: "com.opa334.trollstore.tipa")
    public static let dynamicTrollStoreIPA = UTType(importedAs: "dyn.ah62d4rv4ge81k4puqe")
    public static let xcodeArchive = UTType(importedAs: "com.apple.xcode.archive")
    public static let appExtension = UTType(importedAs: "com.apple.application-and-system-extension")
    public static let mobileProvision = UTType(importedAs: "com.apple.mobileprovision")
    public static let legacyMobileProvision = UTType(importedAs: "com.apple.iphone.mobileprovision")
    public static let provisionProfile = UTType(importedAs: "com.apple.provisionprofile")

    public static let all: [UTType] = [
        ipa,
        trollStoreIPA,
        xcodeArchive,
        appExtension,
        mobileProvision,
        legacyMobileProvision,
        provisionProfile,
    ]

    static func isAppArchive(_ contentType: UTType) -> Bool {
        switch contentType.identifier {
        case ipa.identifier,
             trollStoreIPA.identifier,
             dynamicTrollStoreIPA.identifier,
             xcodeArchive.identifier,
             appExtension.identifier:
            true
        default:
            false
        }
    }
}
