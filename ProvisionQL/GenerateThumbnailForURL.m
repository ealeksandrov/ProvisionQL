#import "Shared.h"

// makro to stop further processing
#define ALLOW_EXIT if (QLThumbnailRequestIsCancelled(thumbnail)) { return noErr; }

//Layout constants
#define BADGE_MARGIN        10.0
#define MIN_BADGE_WIDTH     40.0
#define BADGE_HEIGHT        75.0
#define BADGE_MARGIN_X      60.0
#define BADGE_MARGIN_Y      80.0

//Drawing constants
#define BADGE_BG_COLOR          [NSColor lightGrayColor]
#define BADGE_VALID_COLOR       [NSColor colorWithCalibratedRed:(0/255.0) green:(98/255.0) blue:(25/255.0) alpha:1]
#define BADGE_EXPIRING_COLOR    [NSColor colorWithCalibratedRed:(146/255.0) green:(95/255.0) blue:(28/255.0) alpha:1]
#define BADGE_EXPIRED_COLOR     [NSColor colorWithCalibratedRed:(141/255.0) green:(0/255.0) blue:(7/255.0) alpha:1]
#define BADGE_FONT              [NSFont boldSystemFontOfSize:64]


OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);

/* -----------------------------------------------------------------------------
 Generate a thumbnail for file

 This function's job is to create thumbnail for designated file as fast as possible
 ----------------------------------------------------------------------------- */

// MARK: .ipa .xarchive

OSStatus renderAppIcon(QuickLookInfo meta, QLThumbnailRequestRef thumbnail) {
	NSImage *appIcon = imageFromApp(meta, nil);
	ALLOW_EXIT

	// downscale as required by QLThumbnailRequestSetImageWithData
	CGSize maxSize = QLThumbnailRequestGetMaximumSize(thumbnail);
	if (appIcon.size.width > maxSize.width && appIcon.size.height > maxSize.height) {
		[appIcon setSize:maxSize];
	}

	appIcon = roundCorners(appIcon);
	ALLOW_EXIT

	// set magic flag to draw icon without additional markers
	static const NSString *IconFlavor;
	if (@available(macOS 10.15, *)) {
		IconFlavor = @"icon";
	} else {
		IconFlavor = @"IconFlavor";
	}
	NSDictionary *propertiesDict = nil;
	if (meta.type == FileTypeArchive) {
		// 0: Plain transparent, 1: Shadow, 2: Book, 3: Movie, 4: Address, 5: Image,
		// 6: Gloss, 7: Slide, 8: Square, 9: Border, 11: Calendar, 12: Pattern
		propertiesDict = @{IconFlavor : @(12)}; // looks like "in development"
	} else {
		propertiesDict = @{IconFlavor : @(0)}; // no border, no anything
	}

	// image-only icons can be drawn efficiently by calling `SetImage` directly.
	QLThumbnailRequestSetImageWithData(thumbnail, (__bridge CFDataRef)[appIcon TIFFRepresentation], (__bridge CFDictionaryRef)propertiesDict);
	return noErr;
}


// MARK: .provisioning

OSStatus renderProvision(QuickLookInfo meta, QLThumbnailRequestRef thumbnail, BOOL iconMode) {
	NSDictionary *propertyList = readPlistProvision(meta);
	ALLOW_EXIT

	NSUInteger devicesCount = arrayOrNil(propertyList[@"ProvisionedDevices"]).count;
	NSDate *expirationDate = dateOrNil(propertyList[@"ExpirationDate"]);

	NSImage *appIcon = nil;
	if (iconMode) {
		NSURL *iconURL = [[NSBundle bundleWithIdentifier:kPluginBundleId] URLForResource:@"blankIcon" withExtension:@"png"];
		appIcon = [[NSImage alloc] initWithContentsOfURL:iconURL];
	} else {
		appIcon = [[NSWorkspace sharedWorkspace] iconForFileType:meta.UTI];
		[appIcon setSize:NSMakeSize(512, 512)];
	}
	ALLOW_EXIT

	NSRect renderRect = NSMakeRect(0.0, 0.0, appIcon.size.width, appIcon.size.height);

	// Font attributes
	NSColor *outlineColor;
	switch (expirationStatus(expirationDate)) {
		case ExpirationStatusExpired:  outlineColor = BADGE_EXPIRED_COLOR; break;
		case ExpirationStatusExpiring: outlineColor = BADGE_EXPIRING_COLOR; break;
		case ExpirationStatusValid:    outlineColor = BADGE_VALID_COLOR; break;
	}

	NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
	paragraphStyle.alignment = NSTextAlignmentCenter;

	NSDictionary *fontAttrs = @{
		NSFontAttributeName : BADGE_FONT,
		NSForegroundColorAttributeName : outlineColor,
		NSParagraphStyleAttributeName: paragraphStyle
	};

	// Badge size & placement
	int badgeX = renderRect.origin.x + BADGE_MARGIN_X;
	int badgeY = renderRect.origin.y + renderRect.size.height - BADGE_HEIGHT - BADGE_MARGIN_Y;
	if (!iconMode) {
		badgeX += 75;
		badgeY -= 10;
	}
	int badgeNumX = badgeX + BADGE_MARGIN;
	NSPoint badgeTextPoint = NSMakePoint(badgeNumX, badgeY);

	NSString *badge = [NSString stringWithFormat:@"%lu",(unsigned long)devicesCount];
	NSSize badgeNumSize = [badge sizeWithAttributes:fontAttrs];
	int badgeWidth = badgeNumSize.width + BADGE_MARGIN * 2;
	NSRect badgeOutlineRect = NSMakeRect(badgeX, badgeY, MAX(badgeWidth, MIN_BADGE_WIDTH), BADGE_HEIGHT);

	// Do as much work as possible before the `CreateContext`. We can try to quit early before that!
	CGContextRef _context = QLThumbnailRequestCreateContext(thumbnail, renderRect.size, false, NULL);
	if (_context) {
		NSGraphicsContext *_graphicsContext = [NSGraphicsContext graphicsContextWithCGContext:(void *)_context flipped:NO];
		[NSGraphicsContext setCurrentContext:_graphicsContext];
		[appIcon drawInRect:renderRect];

		NSBezierPath *badgePath = [NSBezierPath bezierPathWithRoundedRect:badgeOutlineRect xRadius:10 yRadius:10];
		[badgePath setLineWidth:8.0];
		[BADGE_BG_COLOR set];
		[badgePath fill];
		[outlineColor set];
		[badgePath stroke];

		[badge drawAtPoint:badgeTextPoint withAttributes:fontAttrs];

		QLThumbnailRequestFlushContext(thumbnail, _context);
		CFRelease(_context);
	}
	return noErr;
}


// MARK: Main Entry

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize) {
	@autoreleasepool {
		QuickLookInfo meta = initQLInfo(contentTypeUTI, url);

		if (meta.type == FileTypeIPA || meta.type == FileTypeArchive) {
			return renderAppIcon(meta, thumbnail);
		} else if (meta.type == FileTypeProvision) {
			NSDictionary *optionsDict = (__bridge NSDictionary *)options;
			BOOL iconMode = ([optionsDict objectForKey:(NSString *)kQLThumbnailOptionIconModeKey]) ? YES : NO;
			return renderProvision(meta, thumbnail, iconMode);
		}
	}
	return noErr;
}

void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail) {
	// Implement only if supported
}
