#import "Shared.h"

NSData *unzipFile(NSURL *url, NSString *filePath) {
    NSTask *task = [NSTask new];
    [task setLaunchPath:@"/usr/bin/unzip"];
    [task setStandardOutput:[NSPipe pipe]];
    [task setArguments:@[@"-p", [url path], filePath]]; // @"-x", @"*/*/*/*"
    [task launch];

    NSData *pipeData = [[[task standardOutput] fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];
    if (pipeData.length == 0) {
        return nil;
    }
    return pipeData;
}

void unzipFileToDir(NSURL *url, NSString *targetDir, NSString *filePath) {
    NSTask *task = [NSTask new];
    [task setLaunchPath:@"/usr/bin/unzip"];
    [task setArguments:@[@"-u", @"-j", @"-d", targetDir, [url path], filePath]]; // @"-x", @"*/*/*/*"
    [task launch];
    [task waitUntilExit];
}

NSImage *roundCorners(NSImage *image) {
    NSImage *existingImage = image;
    NSSize existingSize = [existingImage size];
    NSImage *composedImage = [[NSImage alloc] initWithSize:existingSize];

    [composedImage lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

    NSRect imageFrame = NSRectFromCGRect(CGRectMake(0, 0, existingSize.width, existingSize.height));
    NSBezierPath *clipPath = [NSBezierPath bezierPathWithIOS7RoundedRect:imageFrame cornerRadius:existingSize.width * 0.225];
    [clipPath setWindingRule:NSWindingRuleEvenOdd];
    [clipPath addClip];

    [image drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0, 0, existingSize.width, existingSize.height) operation:NSCompositingOperationSourceOver fraction:1];

    [composedImage unlockFocus];

    return composedImage;
}

int expirationStatus(NSDate *date, NSCalendar *calendar) {
    int result = 0;

    if (date) {
        NSDateComponents *dateComponents = [calendar components:NSCalendarUnitDay fromDate:[NSDate date] toDate:date options:0];
        if ([date compare:[NSDate date]] == NSOrderedAscending) {
            // expired
            result = 0;
        } else if (dateComponents.day < 30) {
            // expiring
            result = 1;
        } else {
            // valid
            result = 2;
        }
    }

    return result;
}

NSImage *imageFromApp(NSURL *URL, NSString *dataType, NSString *fileName) {
    NSImage *appIcon = nil;

    if ([dataType isEqualToString:kDataType_xcode_archive]) {
        // get the embedded icon for the iOS app
        NSURL *appsDir = [URL URLByAppendingPathComponent:@"Products/Applications/"];
        if (!appsDir) {
            return nil;
        }

        NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appsDir.path error:nil];
        NSString *appName = dirFiles.firstObject;
        if (!appName) {
            return nil;
        }

        NSURL *appURL = [appsDir URLByAppendingPathComponent:appName];
        NSArray *appContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appURL.path error:nil];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF contains %@", fileName];
        NSString *appIconFullName = [appContents filteredArrayUsingPredicate:predicate].lastObject;
        if (!appIconFullName) {
            return nil;
        }

        NSURL *appIconFullURL = [appURL URLByAppendingPathComponent:appIconFullName];
        appIcon = [[NSImage alloc] initWithContentsOfURL:appIconFullURL];
    } else if([dataType isEqualToString:kDataType_ipa]) {
        NSData *data = unzipFile(URL, @"iTunesArtwork");
        if (!data && fileName.length > 0) {
            data = unzipFile(URL, [NSString stringWithFormat:@"Payload/*.app/%@*", fileName]);
        }
        if (data != nil) {
            appIcon = [[NSImage alloc] initWithData:data];
        }
    }

    return appIcon;
}

NSArray *iconsListForDictionary(NSDictionary *iconsDict) {
    if ([iconsDict isKindOfClass:[NSDictionary class]]) {
        id primaryIconDict = [iconsDict objectForKey:@"CFBundlePrimaryIcon"];
        if ([primaryIconDict isKindOfClass:[NSDictionary class]]) {
            id tempIcons = [primaryIconDict objectForKey:@"CFBundleIconFiles"];
            if ([tempIcons isKindOfClass:[NSArray class]]) {
                return tempIcons;
            }
        }
    }

    return nil;
}

NSString *mainIconNameForApp(NSDictionary *appPropertyList) {
    NSArray *icons;
    NSString *iconName;

    //Check for CFBundleIcons (since 5.0)
    icons = iconsListForDictionary([appPropertyList objectForKey:@"CFBundleIcons"]);
    if (!icons) {
        icons = iconsListForDictionary([appPropertyList objectForKey:@"CFBundleIcons~ipad"]);
    }

    if (!icons) {
        //Check for CFBundleIconFiles (since 3.2)
        id tempIcons = [appPropertyList objectForKey:@"CFBundleIconFiles"];
        if ([tempIcons isKindOfClass:[NSArray class]]) {
            icons = tempIcons;
        }
    }

    if (icons) {
        //Search some patterns for primary app icon (120x120)
        NSArray *matches = @[@"120",@"60"];

        for (NSString *match in matches) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF contains[c] %@",match];
            NSArray *results = [icons filteredArrayUsingPredicate:predicate];
            if ([results count]) {
                iconName = [results firstObject];
                break;
            }
        }

        //If no one matches any pattern, just take last item
        if (!iconName) {
            iconName = [icons lastObject];
        }
    } else {
        //Check for CFBundleIconFile (legacy, before 3.2)
        NSString *legacyIcon = [appPropertyList objectForKey:@"CFBundleIconFile"];
        if ([legacyIcon length]) {
            iconName = legacyIcon;
        }
    }

    return iconName;
}
