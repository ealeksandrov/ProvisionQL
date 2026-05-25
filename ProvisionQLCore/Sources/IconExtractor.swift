//
//  IconExtractor.swift
//  Core
//
//  Created by Evgeny Aleksandrov

import AppKit
import Foundation

public enum IconExtractor {
    public static func extractIcon(from url: URL) throws -> NSImage? {
        try extractIconSource(from: url)?.makeImage()
    }

    public static func extractIconSource(from url: URL) throws -> IconSource? {
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "ipa":
            let source = try IPAAppBundleSource(url: url)
            return try extractIconSource(from: source)
        case "xcarchive":
            let appBundleURL = try DirectoryAppBundleSource.findAppBundleInXCArchive(at: url)
            let source = try DirectoryAppBundleSource(bundleURL: appBundleURL)
            return try extractIconSource(from: source)
        case "appex":
            let source = try DirectoryAppBundleSource(bundleURL: url)
            return try extractIconSource(from: source)
        default:
            return nil
        }
    }
}

extension IconExtractor {
    static func extractIconSource(from source: AppBundleSource) throws -> IconSource? {
        let artworkNames = ["iTunesArtwork@3x", "iTunesArtwork@2x", "iTunesArtwork"]
        if source.containerKind == .ipa {
            for artworkName in artworkNames {
                if let imageData = try source.data(
                    at: artworkName,
                    relativeToBundle: false,
                    caseInsensitive: true
                ) {
                    return IconSource(data: imageData)
                }
            }
        }

        let plist = try source.infoPlist()

        if let iconName = findMainIconName(in: plist),
           let iconSource = try findIconSource(iconName: iconName, in: source)
        {
            return iconSource
        }

        let commonPrefixes = ["AppIcon", "Icon"]
        for prefix in commonPrefixes {
            if let iconSource = try findIconSource(iconName: prefix, in: source) {
                return iconSource
            }
        }

        return nil
    }

    // MARK: - Icon Search

    static func findIconSource(iconName: String, in source: AppBundleSource) throws -> IconSource? {
        try findIconData(iconName: iconName) { iconPath in
            let candidatePaths = if source.bundleStyle == .macOS {
                [
                    "Contents/Resources/\(iconPath)",
                    "Contents/\(iconPath)",
                    iconPath
                ]
            } else {
                [iconPath]
            }

            for candidatePath in candidatePaths {
                if let data = try source.data(
                    at: candidatePath,
                    relativeToBundle: true,
                    caseInsensitive: true
                ) {
                    return data
                }
            }

            return nil
        }
        .map(IconSource.init(data:))
    }

    static func findIconData(iconName: String, using action: (String) throws -> Data?) rethrows -> Data? {
        let deviceSuffixes = ["~tv", "~ipad", ""]
        let sizeExtensions = ["@3x", "@2x", ""]
        let fileExtensions = [".png", ".icns", ""]

        for deviceSuffix in deviceSuffixes {
            for sizeExt in sizeExtensions {
                for fileExt in fileExtensions {
                    let iconPath = "\(iconName)\(sizeExt)\(deviceSuffix)\(fileExt)"
                    if let data = try action(iconPath) {
                        return data
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Icon Name Detection

    static func findMainIconName(in plist: [String: Any]?) -> String? {
        guard let plist else { return nil }

        var allIconFiles: [String] = []

        // Try CFBundleIcons (iOS 5.0+)
        if let bundleIcons = plist["CFBundleIcons"] as? [String: Any],
           let primaryIcon = bundleIcons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String]
        {
            allIconFiles.append(contentsOf: iconFiles)
        }

        // Try CFBundleIcons~ipad
        if let bundleIcons = plist["CFBundleIcons~ipad"] as? [String: Any],
           let primaryIcon = bundleIcons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String]
        {
            allIconFiles.append(contentsOf: iconFiles)
        }

        // Try CFBundleIcons~tv (tvOS)
        if let bundleIcons = plist["CFBundleIcons~tv"] as? [String: Any],
           let primaryIcon = bundleIcons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String]
        {
            allIconFiles.append(contentsOf: iconFiles)
        }

        if !allIconFiles.isEmpty,
           let iconName = findBestIcon(from: allIconFiles)
        {
            return iconName
        }

        // Try CFBundleIconFiles (iOS 3.2+)
        if let iconFiles = plist["CFBundleIconFiles"] as? [String],
           let iconName = findBestIcon(from: iconFiles)
        {
            return iconName
        }

        // Try CFBundleIconFile (legacy)
        if let iconFile = plist["CFBundleIconFile"] as? String {
            return iconFile
        }

        return nil
    }

    static func findBestIcon(from icons: [String]) -> String? {
        let sortedIcons = icons.sorted { icon1, icon2 in
            let size1 = extractSizeFromFilename(icon1)
            let size2 = extractSizeFromFilename(icon2)
            return size1 > size2
        }

        return sortedIcons.first
    }

    static func extractSizeFromFilename(_ filename: String) -> Int {
        let numbers = filename.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Int(numbers) ?? 0
    }

    // MARK: - Image Processing

    static func applyRoundedCorners(to image: NSImage) -> NSImage {
        let size = image.size
        let cornerRadius = size.width * 0.225

        let newImage = NSImage(size: size)
        newImage.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high

        let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size),
                                xRadius: cornerRadius,
                                yRadius: cornerRadius)
        path.addClip()

        image.draw(at: .zero,
                   from: NSRect(origin: .zero, size: size),
                   operation: .sourceOver,
                   fraction: 1.0)

        newImage.unlockFocus()
        return newImage
    }
}
