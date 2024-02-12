#import "AppIcon.h"
#import "Shared.h"
#import "ZipEntry.h"

#define CUI_ENABLED 1

#ifdef CUI_ENABLED
#import <CoreUI/CUICatalog.h>
#import <CoreUI/CUINamedImage.h>
#endif


@interface AppIcon()
@property (nonatomic, assign) QuickLookInfo meta;
@end


@implementation AppIcon

+ (instancetype)load:(QuickLookInfo)meta {
    return [[self alloc] initWithMeta:meta];
}

- (instancetype)initWithMeta:(QuickLookInfo)meta {
    self = [super init];
    if (self) {
        _meta = meta;
    }
    return self;
}


// MARK: - Public methods

/// You should check this before calling @c extractImage
- (BOOL)canExtractImage {
    switch (_meta.type) {
        case FileTypeIPA:
        case FileTypeArchive:
        case FileTypeExtension:
            return YES;
        case FileTypeProvision:
            return NO;
    }
    return NO;
}


// MARK: - Image Extraction

/// Try multiple methods to extract image. You should check @c canExtractImage before calling this method.
/// This method will always return an image even if none is found, in which case it returns the default image.
- (NSImage * _Nonnull)extractImage:(NSDictionary * _Nullable)appPlist {
    // no need to unwrap the plist, and most .ipa should include the Artwork anyway
    if (_meta.type == FileTypeIPA) {
        NSData *data = [_meta.zipFile unzipFile:@"iTunesArtwork"];
        if (data) {
#ifdef DEBUG
            NSLog(@"[icon] using iTunesArtwork.");
#endif
            return [[NSImage alloc] initWithData:data];
        }
    }

    // Extract image name from app plist
    NSString *plistImgName = [self iconNameFromPlist:appPlist];
#ifdef DEBUG
    NSLog(@"[icon] icon name: %@", plistImgName);
#endif
    if (plistImgName) {
        // First, try if an image file with that name exists.
        NSString *actualName = [self expandImageName:plistImgName];
        if (actualName) {
#ifdef DEBUG
            NSLog(@"[icon] using plist with key %@ and image file %@", plistImgName, actualName);
#endif
            if (_meta.type == FileTypeIPA) {
                NSData *data = [_meta.zipFile unzipFile:[@"Payload/*.app/" stringByAppendingString:actualName]];
                return [[NSImage alloc] initWithData:data];
            }
            NSURL *basePath = _meta.effectiveUrl ?: _meta.url;
            return [[NSImage alloc] initWithContentsOfURL:[basePath URLByAppendingPathComponent:actualName]];
        }

        // Else: try Assets.car
#ifdef CUI_ENABLED
        @try {
            NSImage *img = [self imageFromAssetsCar:plistImgName];
            if (img) {
                return img;
            }
        } @catch (NSException *exception) {
            NSLog(@"ERROR: unknown private framework issue: %@", exception);
        }
#endif
    }

    // Fallback to default icon
    NSURL *iconURL = [[NSBundle bundleWithIdentifier:kPluginBundleId] URLForResource:@"defaultIcon" withExtension:@"png"];
    return [[NSImage alloc] initWithContentsOfURL:iconURL];
}

#ifdef CUI_ENABLED

/// Use @c CUICatalog to extract an image from @c Assets.car
- (NSImage * _Nullable)imageFromAssetsCar:(NSString *)imageName {
    NSData *data = readPayloadFile(_meta, @"Assets.car");
    if (!data) {
        return nil;
    }
    NSError *err;
    CUICatalog *catalog = [[CUICatalog alloc] initWithBytes:[data bytes] length:data.length error:&err];
    if (err) {
        NSLog(@"[icon-car] ERROR: could not open catalog: %@", err);
        return nil;
    }
    NSString *validName = [self carVerifyNameExists:imageName inCatalog:catalog];
    if (validName) {
        CUINamedImage *bestImage = [self carFindHighestResolutionIcon:[catalog imagesWithName:validName]];
        if (bestImage) {
#ifdef DEBUG
            NSLog(@"[icon] using Assets.car with key %@", validName);
#endif
            return [[NSImage alloc] initWithCGImage:bestImage.image size:bestImage.size];
        }
    }
    return nil;
}


// MARK: - Helper: Assets.car

/// Helper method to check available icon names. Will return a valid name or @c nil if no image with that key is found.
- (NSString * _Nullable)carVerifyNameExists:(NSString *)imageName inCatalog:(CUICatalog *)catalog {
    NSArray<NSString *> *availableNames = nil;
    @try {
        availableNames = [catalog allImageNames];
    } @catch (NSException *exception) {
        NSLog(@"[icon-car] ERROR: method allImageNames unavailable: %@", exception);
        // fallback to use the provided imageName just in case it may still proceed.
    }
    if (availableNames && ![availableNames containsObject:imageName]) {
        // Theoretically this should never happen. Assuming the image name is found in an image file.
        NSLog(@"[icon-car] WARN: key '%@' does not match any available key", imageName);
        NSString *alternativeName = [self carSearchAlternativeName:imageName inAvailable:availableNames];
        if (alternativeName) {
            NSLog(@"[icon-car] falling back to '%@'", alternativeName);
            return alternativeName;
        }
        // NSLog(@"[icon-car] available keys: %@", [car allImageNames]);
        return nil;
    }
    return imageName;
}

/// If exact name does not exist in catalog, search for a name that shares the same prefix.
/// E.g., "AppIcon60x60" may match "AppIcon" or "AppIcon60x60_small"
- (NSString * _Nullable)carSearchAlternativeName:(NSString *)originalName inAvailable:(NSArray<NSString*> *)availableNames {
    NSString *bestOption = nil;
    NSUInteger bestDiff = 999;
    for (NSString *option in availableNames) {
        if ([option hasPrefix:originalName] || [originalName hasPrefix:option]) {
            NSUInteger thisDiff = MAX(originalName.length, option.length) - MIN(originalName.length, option.length);
            if (thisDiff < bestDiff) {
                bestDiff = thisDiff;
                bestOption = option;
            }
        }
    }
    return bestOption;
}

/// Given a list of @c CUINamedImage, return the one with the highest resolution. Vector graphics are ignored.
- (CUINamedImage * _Nullable)carFindHighestResolutionIcon:(NSArray<CUINamedImage*> *)availableImages {
    CGFloat largestWidth = 0;
    CUINamedImage *largestImage = nil;
    for (CUINamedImage *img in availableImages) {
        if (![img isKindOfClass:[CUINamedImage class]]) {
            continue; // ignore CUINamedMultisizeImageSet
        }
        @try {
            CGFloat w = img.size.width;
            if (w > largestWidth) {
                largestWidth = w;
                largestImage = img;
            }
        } @catch (NSException *exception) {
            continue;
        }
    }
    return largestImage;
}

#endif


// MARK: - Helper: Plist Filename

/// Parse app plist to find the bundle icon filename.
/// @param appPlist If @c nil, will load plist on the fly (used for thumbnail)
/// @return Filename which is available in Bundle or Filesystem. This may include @c @2x and an arbitrary file extension.
- (NSString * _Nullable)iconNameFromPlist:(NSDictionary *)appPlist {
    if (!appPlist) {
        appPlist = readPlistApp(_meta);
    }
    //Check for CFBundleIcons (since 5.0)
    NSArray *icons = [self unpackNameListFromPlistDict:appPlist[@"CFBundleIcons"]];
    if (!icons) {
        icons = [self unpackNameListFromPlistDict:appPlist[@"CFBundleIcons~ipad"]];
        if (!icons) {
            //Check for CFBundleIconFiles (since 3.2)
            icons = arrayOrNil(appPlist[@"CFBundleIconFiles"]);
            if (!icons) {
                icons = arrayOrNil(appPlist[@"Icon files"]); // key found on iTunesU app
                if (!icons) {
                    //Check for CFBundleIconFile (legacy, before 3.2)
                    return appPlist[@"CFBundleIconFile"]; // may be nil
                }
            }
        }
    }
    return [self findHighestResolutionIconName:icons];
}

/// Given a filename, search Bundle or Filesystem for files that match. Select the filename with the highest resolution.
- (NSString * _Nullable)expandImageName:(NSString * _Nullable)fileName {
    if (!fileName) {
        return nil;
    }
    NSArray *matchingNames = nil;
    if (_meta.type == FileTypeIPA) {
        if (!_meta.zipFile) {
            // in case unzip in memory is not available, fallback to pattern matching with dynamic suffix
            return [fileName stringByAppendingString:@"*"];
        }
        NSString *zipPath = [NSString stringWithFormat:@"Payload/*.app/%@*", fileName];
        NSMutableArray *matches = [NSMutableArray array];
        for (ZipEntry *zip in [_meta.zipFile filesMatching:zipPath]) {
            [matches addObject:[zip.filepath lastPathComponent]];
        }
        matchingNames = matches;
    } else if (_meta.type == FileTypeArchive || _meta.type == FileTypeExtension) {
        NSURL *basePath = _meta.effectiveUrl ?: _meta.url;
        NSArray *appContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath.path error:nil];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF beginswith %@", fileName];
        matchingNames = [appContents filteredArrayUsingPredicate:predicate];
    }
    if (matchingNames.count > 0) {
        return [self findHighestResolutionIconName:matchingNames];
    }
    return nil;
}

/// Deep select icons from plist key @c CFBundleIcons and @c CFBundleIcons~ipad
- (NSArray * _Nullable)unpackNameListFromPlistDict:(NSDictionary *)bundleDict {
    if ([bundleDict isKindOfClass:[NSDictionary class]]) {
        NSDictionary *primaryDict = [bundleDict objectForKey:@"CFBundlePrimaryIcon"];
        if ([primaryDict isKindOfClass:[NSDictionary class]]) {
            NSArray *icons = [primaryDict objectForKey:@"CFBundleIconFiles"];
            if ([icons isKindOfClass:[NSArray class]]) {
                return icons;
            }
            NSString *name = [primaryDict objectForKey:@"CFBundleIconName"]; // key found on a .tipa file
            if ([name isKindOfClass:[NSString class]]) {
                return @[name];
            }
        }
    }
    return nil;
}

/// Given a list of filenames, try to find the one with the highest resolution
- (NSString *)findHighestResolutionIconName:(NSArray<NSString *> *)icons {
    for (NSString *match in @[@"@3x", @"@2x", @"180", @"167", @"152", @"120"]) {
        for (NSString *icon in icons) {
            if ([icon containsString:match]) {
                return icon;
            }
        }
    }
    //If no one matches any pattern, just take last item
    NSString *lastName = [icons lastObject];
    if ([[lastName lowercaseString] containsString:@"small"]) {
        return [icons firstObject];
    }
    return lastName;
}

@end


// MARK: - Extension: NSBezierPath

//
//  NSBezierPath+IOS7RoundedRect
//
//  Created by Matej Dunik on 11/12/13.
//  Copyright (c) 2013 PixelCut. All rights reserved except as below:
//  This code is provided as-is, without warranty of any kind. You may use it in your projects as you wish.
//

@implementation NSBezierPath (IOS7RoundedRect)

#define TOP_LEFT(X, Y) NSMakePoint(rect.origin.x + X * limitedRadius, rect.origin.y + Y * limitedRadius)
#define TOP_RIGHT(X, Y) NSMakePoint(rect.origin.x + rect.size.width - X * limitedRadius, rect.origin.y + Y * limitedRadius)
#define BOTTOM_RIGHT(X, Y) NSMakePoint(rect.origin.x + rect.size.width - X * limitedRadius, rect.origin.y + rect.size.height - Y * limitedRadius)
#define BOTTOM_LEFT(X, Y) NSMakePoint(rect.origin.x + X * limitedRadius, rect.origin.y + rect.size.height - Y * limitedRadius)

/// iOS 7 rounded corners
+ (NSBezierPath *)bezierPathWithIOS7RoundedRect:(NSRect)rect cornerRadius:(CGFloat)radius {
    NSBezierPath *path = NSBezierPath.bezierPath;
    CGFloat limit = MIN(rect.size.width, rect.size.height) / 2 / 1.52866483;
    CGFloat limitedRadius = MIN(radius, limit);

    [path moveToPoint: TOP_LEFT(1.52866483, 0.00000000)];
    [path lineToPoint: TOP_RIGHT(1.52866471, 0.00000000)];
    [path curveToPoint: TOP_RIGHT(0.66993427, 0.06549600) controlPoint1: TOP_RIGHT(1.08849323, 0.00000000) controlPoint2: TOP_RIGHT(0.86840689, 0.00000000)];
    [path lineToPoint: TOP_RIGHT(0.63149399, 0.07491100)];
    [path curveToPoint: TOP_RIGHT(0.07491176, 0.63149399) controlPoint1: TOP_RIGHT(0.37282392, 0.16905899) controlPoint2: TOP_RIGHT(0.16906013, 0.37282401)];
    [path curveToPoint: TOP_RIGHT(0.00000000, 1.52866483) controlPoint1: TOP_RIGHT(0.00000000, 0.86840701) controlPoint2: TOP_RIGHT(0.00000000, 1.08849299)];
    [path lineToPoint: BOTTOM_RIGHT(0.00000000, 1.52866471)];
    [path curveToPoint: BOTTOM_RIGHT(0.06549569, 0.66993493) controlPoint1: BOTTOM_RIGHT(0.00000000, 1.08849323) controlPoint2: BOTTOM_RIGHT(0.00000000, 0.86840689)];
    [path lineToPoint: BOTTOM_RIGHT(0.07491111, 0.63149399)];
    [path curveToPoint: BOTTOM_RIGHT(0.63149399, 0.07491111) controlPoint1: BOTTOM_RIGHT(0.16905883, 0.37282392) controlPoint2: BOTTOM_RIGHT(0.37282392, 0.16905883)];
    [path curveToPoint: BOTTOM_RIGHT(1.52866471, 0.00000000) controlPoint1: BOTTOM_RIGHT(0.86840689, 0.00000000) controlPoint2: BOTTOM_RIGHT(1.08849323, 0.00000000)];
    [path lineToPoint: BOTTOM_LEFT(1.52866483, 0.00000000)];
    [path curveToPoint: BOTTOM_LEFT(0.66993397, 0.06549569) controlPoint1: BOTTOM_LEFT(1.08849299, 0.00000000) controlPoint2: BOTTOM_LEFT(0.86840701, 0.00000000)];
    [path lineToPoint: BOTTOM_LEFT(0.63149399, 0.07491111)];
    [path curveToPoint: BOTTOM_LEFT(0.07491100, 0.63149399) controlPoint1: BOTTOM_LEFT(0.37282401, 0.16905883) controlPoint2: BOTTOM_LEFT(0.16906001, 0.37282392)];
    [path curveToPoint: BOTTOM_LEFT(0.00000000, 1.52866471) controlPoint1: BOTTOM_LEFT(0.00000000, 0.86840689) controlPoint2: BOTTOM_LEFT(0.00000000, 1.08849323)];
    [path lineToPoint: TOP_LEFT(0.00000000, 1.52866483)];
    [path curveToPoint: TOP_LEFT(0.06549600, 0.66993397) controlPoint1: TOP_LEFT(0.00000000, 1.08849299) controlPoint2: TOP_LEFT(0.00000000, 0.86840701)];
    [path lineToPoint: TOP_LEFT(0.07491100, 0.63149399)];
    [path curveToPoint: TOP_LEFT(0.63149399, 0.07491100) controlPoint1: TOP_LEFT(0.16906001, 0.37282401) controlPoint2: TOP_LEFT(0.37282401, 0.16906001)];
    [path curveToPoint: TOP_LEFT(1.52866483, 0.00000000) controlPoint1: TOP_LEFT(0.86840701, 0.00000000) controlPoint2: TOP_LEFT(1.08849299, 0.00000000)];
    [path closePath];
    return path;
}

@end


// MARK: - Extension: NSImage


@implementation NSImage (AppIcon)

/// Apply rounded corners to image (iOS7 style)
- (NSImage * _Nonnull)withRoundCorners {
    NSSize existingSize = [self size];
    NSImage *composedImage = [[NSImage alloc] initWithSize:existingSize];

    [composedImage lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

    NSRect imageFrame = NSRectFromCGRect(CGRectMake(0, 0, existingSize.width, existingSize.height));
    NSBezierPath *clipPath = [NSBezierPath bezierPathWithIOS7RoundedRect:imageFrame cornerRadius:existingSize.width * 0.225];
    [clipPath setWindingRule:NSWindingRuleEvenOdd];
    [clipPath addClip];

    [self drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0, 0, existingSize.width, existingSize.height) operation:NSCompositingOperationSourceOver fraction:1];
    [composedImage unlockFocus];
    return composedImage;
}

/// Convert image to PNG and encode with base64 to be embeded in html output.
- (NSString * _Nonnull)asBase64 {
    //	appIcon = [self roundCorners:appIcon];
    NSData *imageData = [self TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    imageData = [imageRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [imageData base64EncodedStringWithOptions:0];
}

/// If the image is larger than the provided maximum size, scale it down. Otherwise leave it untouched.
- (void)downscale:(CGSize)maxSize {
    // TODO: if downscale, then this should respect retina resolution
    if (self.size.width > maxSize.width && self.size.height > maxSize.height) {
        [self setSize:maxSize];
    }
}

@end
