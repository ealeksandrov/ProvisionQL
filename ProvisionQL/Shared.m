#import "Shared.h"

NSImage *roundCorners(NSImage *image) {
    NSImage *existingImage = image;
    NSSize existingSize = [existingImage size];
    NSImage *composedImage = [[NSImage alloc] initWithSize:existingSize];

    [composedImage lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

    NSRect imageFrame = NSRectFromCGRect(CGRectMake(0, 0, existingSize.width, existingSize.height));
    NSBezierPath *clipPath = [NSBezierPath bezierPathWithIOS7RoundedRect:imageFrame cornerRadius:existingSize.width * 0.225];
    [clipPath setWindingRule:NSEvenOddWindingRule];
    [clipPath addClip];

    [image drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0, 0, existingSize.width, existingSize.height) operation:NSCompositeSourceOver fraction:1];

    [composedImage unlockFocus];

    return composedImage;
}

int expirationStatus(NSDate *date, NSCalendar *calendar) {
	int result = 0;

	if (date) {
		NSDateComponents *dateComponents = [calendar components:NSDayCalendarUnit fromDate:[NSDate date] toDate:date options:0];
        if ([date compare: [NSDate date]] == NSOrderedAscending) {
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
        if (appsDir != nil) {
            NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appsDir.path error:nil];
            if (dirFiles.count > 0) {
                appIcon = [[NSImage alloc] initWithContentsOfURL:[appsDir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", dirFiles[0], fileName]]];
            }
        }
    } else if([dataType isEqualToString:kDataType_ipa]) {
        // get the embedded icon from an app arcive using: unzip -p <URL> 'Payload/*.app/<fileName>' (piped to standard output)
        NSTask *unzipTask = [NSTask new];
        [unzipTask setLaunchPath:@"/usr/bin/unzip"];
        [unzipTask setStandardOutput:[NSPipe pipe]];
        [unzipTask setArguments:@[@"-p", [URL path], [NSString stringWithFormat:@"Payload/*.app/%@", fileName], @"-x", @"*/*/*/*"]];
        [unzipTask launch];
        [unzipTask waitUntilExit];

        appIcon = [[NSImage alloc] initWithData:[[[unzipTask standardOutput] fileHandleForReading] readDataToEndOfFile]];
    }

    return appIcon;
}

NSString *mainIconNameForApp(NSDictionary *appPropertyList) {
    id icons;
    NSString *iconName;

    //Check for CFBundleIcons (since 5.0)
    id iconsDict = [appPropertyList objectForKey:@"CFBundleIcons"];
    if ([iconsDict isKindOfClass:[NSDictionary class]]) {
        id primaryIconDict = [iconsDict objectForKey:@"CFBundlePrimaryIcon"];
        if ([primaryIconDict isKindOfClass:[NSDictionary class]]) {
            id tempIcons = [primaryIconDict objectForKey:@"CFBundleIconFiles"];
            if ([tempIcons isKindOfClass:[NSArray class]]) {
                icons = tempIcons;
            }
        }
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
        NSArray *matches = @[@"120",@"60",@"@2x"];

        for (NSString *match in matches) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF contains[c] %@",match];
            NSArray *results = [icons filteredArrayUsingPredicate:predicate];
            if ([results count]) {
                iconName = [results firstObject];
                //Check for @2x existence
                if ([match isEqualToString:@"60"] && ![[iconName pathExtension] length]) {
                    if (![iconName hasSuffix:@"@2x"]) {
                        iconName = [iconName stringByAppendingString:@"@2x"];
                    }
                }
                break;
            }
        }

        //If no one matches any pattern, just take first item
        if (!iconName) {
            iconName = [icons firstObject];
        }
    } else {
        //Check for CFBundleIconFile (legacy, before 3.2)
        NSString *legacyIcon = [appPropertyList objectForKey:@"CFBundleIconFile"];
        if ([legacyIcon length]) {
            iconName = legacyIcon;
        }
    }

    //Load NSImage
    if ([iconName length]) {
        if (![[iconName pathExtension] length]) {
            iconName = [iconName stringByAppendingPathExtension:@"png"];
        }
        return iconName;
    }

    return nil;
}
