//
//  ThumbnailProvider.swift
//  Thumbnail
//
//  Created by Evgeny Aleksandrov

import AppKit
import ProvisionQLCore
import QuickLookThumbnailing

class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let url = request.fileURL
        let size = request.maximumSize
        let fileExtension = url.pathExtension.lowercased()

        var icon: NSImage
        var badgeInfo: BadgeInfo?
        var extensionBadge: String?

        switch fileExtension {
        case "mobileprovision", "provisionprofile":
            badgeInfo = try? ProvisioningParser.fetchBadgeInfo(from: url)
            icon = getProvisioningIcon()
            extensionBadge = "PROV"

        case "ipa", "tipa", "xcarchive", "appex":
            icon = (try? IconExtractor.extractIcon(from: url)) ?? getDefaultAppIcon()
            extensionBadge = fileExtension.uppercased()

        default:
            handler(nil, ThumbnailError.unsupportedFileType)
            return
        }

        let reply = QLThumbnailReply(contextSize: size, currentContextDrawing: { () -> Bool in
            return self.drawThumbnail(in: size, icon: icon, badgeInfo: badgeInfo)
        })

        if let extensionBadge {
            reply.extensionBadge = extensionBadge
        }

        handler(reply, nil)
    }

    enum ThumbnailError: Error {
        case unsupportedFileType
    }
}

private extension ThumbnailProvider {
    func drawThumbnail(in size: CGSize, icon: NSImage, badgeInfo: BadgeInfo?) -> Bool {
        guard let context = NSGraphicsContext.current?.cgContext else { return false }

        let iconRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        if let cgImage = icon.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: iconRect)
        }

        if let badgeInfo {
            drawDeviceBadge(
                deviceCount: badgeInfo.deviceCount,
                expirationStatus: badgeInfo.expirationStatus,
                in: context,
                size: size
            )
        }

        return true
    }

    func getProvisioningIcon() -> NSImage {
        let iconSize = NSSize(width: 256, height: 256)
        let image = NSImage(size: iconSize)
        image.lockFocus()

        // Create border path
        let padding: CGFloat = 12
        let borderPath = NSBezierPath(roundedRect: NSRect(
            x: 0 + padding,
            y: 0 + padding,
            width: iconSize.width - padding * 2,
            height: iconSize.height - padding * 2
        ), xRadius: 20, yRadius: 20)

        // Fill white background
        NSColor.white.setFill()
        borderPath.fill()

        // SF Symbol
        if let symbolImage = NSImage(systemSymbolName: "gear", accessibilityDescription: nil) {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 120, weight: .medium)
                .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.systemGray]))

            if let configuredSymbol = symbolImage.withSymbolConfiguration(symbolConfig) {
                let symbolSize = configuredSymbol.size
                let symbolRect = NSRect(
                    x: (iconSize.width - symbolSize.width) / 2,
                    y: (iconSize.height - symbolSize.height) / 2,
                    width: symbolSize.width,
                    height: symbolSize.height
                )

                configuredSymbol.draw(in: symbolRect)
            }
        }

        image.unlockFocus()
        return image
    }

    func getDefaultAppIcon() -> NSImage {
        let iconSize = NSSize(width: 256, height: 256)
        let image = NSImage(size: iconSize)
        image.lockFocus()

        // Create border path
        let padding: CGFloat = 12
        let borderPath = NSBezierPath(roundedRect: NSRect(
            x: 0 + padding,
            y: 0 + padding,
            width: iconSize.width - padding * 2,
            height: iconSize.height - padding * 2
        ), xRadius: 56, yRadius: 56) // iOS-style rounded corners

        // Fill white background
        NSColor.white.setFill()
        borderPath.fill()

        if let symbolImage = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 120, weight: .medium)
                .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.systemGray]))

            if let configuredSymbol = symbolImage.withSymbolConfiguration(symbolConfig) {
                let symbolSize = configuredSymbol.size
                let symbolRect = NSRect(
                    x: (iconSize.width - symbolSize.width) / 2,
                    y: (iconSize.height - symbolSize.height) / 2,
                    width: symbolSize.width,
                    height: symbolSize.height
                )
                configuredSymbol.draw(in: symbolRect)
            }
        }

        image.unlockFocus()
        return image
    }

    func drawDeviceBadge(deviceCount: Int, expirationStatus: ExpirationStatus, in context: CGContext, size: CGSize) {
        let badgeSize: CGFloat = min(size.width, size.height) * 0.2
        let badgeX: CGFloat = size.width * 0.2
        let badgeY = size.height - badgeSize - size.height * 0.2

        let badgeColor = switch expirationStatus {
        case .expired:
            CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) // Red
        case .expiring:
            CGColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0) // Orange
        case .valid:
            CGColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 1.0) // Green
        }

        let text = "\(deviceCount)"
        let font = NSFont.boldSystemFont(ofSize: min(size.width, size.height) * 0.12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        let badgeHeight = badgeSize * 0.7
        let padding = badgeHeight * 0.4
        let minWidth = badgeHeight
        let badgeWidth = max(minWidth, textSize.width + padding * 2)
        let badgeRect = CGRect(
            x: badgeX,
            y: badgeY + (badgeSize - badgeHeight) / 2,
            width: badgeWidth,
            height: badgeHeight
        )

        context.setFillColor(badgeColor)
        let pillPath = CGPath(
            roundedRect: badgeRect,
            cornerWidth: badgeHeight / 2,
            cornerHeight: badgeHeight / 2,
            transform: nil
        )
        context.addPath(pillPath)
        context.fillPath()

        let textX = badgeX + (badgeWidth - textSize.width) / 2
        let textY = badgeY + (badgeSize - badgeHeight) / 2 + (badgeHeight - textSize.height) / 2
        let textRect = CGRect(x: textX, y: textY, width: textSize.width, height: textSize.height)
        attributedString.draw(in: textRect)
    }
}
