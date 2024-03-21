#import "Shared.h"
#import "ZipFile.h"

// MARK: - Meta data for QuickLook

/// Search an archive for the .app or .ipa bundle.
NSURL * _Nullable appPathForArchive(NSURL *url) {
    NSURL *appsDir = [url URLByAppendingPathComponent:@"Products/Applications/"];
    if (appsDir != nil) {
        NSArray *dirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appsDir.path error:nil];
        if (dirFiles.count > 0) {
            return [appsDir URLByAppendingPathComponent:dirFiles[0] isDirectory:YES];
        }
    }
    return nil;
}

/// Use file url and UTI type to generate an info object to pass around.
QuickLookInfo initQLInfo(CFStringRef contentTypeUTI, CFURLRef url) {
    QuickLookInfo data = {};
    data.UTI = (__bridge NSString *)contentTypeUTI;
    data.url = (__bridge NSURL *)url;
    
    if ([data.UTI isEqualToString:kDataType_ipa]) {
        data.type = FileTypeIPA;
        data.zipFile = [ZipFile open:data.url.path];
    } else if ([data.UTI isEqualToString:kDataType_xcode_archive]) {
        data.type = FileTypeArchive;
        data.effectiveUrl = appPathForArchive(data.url);
    } else if ([data.UTI isEqualToString:kDataType_app_extension]) {
        data.type = FileTypeExtension;
    } else if ([data.UTI isEqualToString:kDataType_ios_provision]) {
        data.type = FileTypeProvision;
    } else if ([data.UTI isEqualToString:kDataType_ios_provision_old]) {
        data.type = FileTypeProvision;
    } else if ([data.UTI isEqualToString:kDataType_osx_provision]) {
        data.type = FileTypeProvision;
        data.isOSX = YES;
    }
    return data;
}

/// Load a file from bundle into memory. Either by file path or via unzip.
NSData * _Nullable readPayloadFile(QuickLookInfo meta, NSString *filename) {
    switch (meta.type) {
        case FileTypeIPA: return [meta.zipFile unzipFile:[@"Payload/*.app/" stringByAppendingString:filename] isExactMatch:NO];
        case FileTypeArchive: return [NSData dataWithContentsOfURL:[meta.effectiveUrl URLByAppendingPathComponent:filename]];
        case FileTypeExtension: return [NSData dataWithContentsOfURL:[meta.url URLByAppendingPathComponent:filename]];
        case FileTypeProvision: return nil;
    }
    return nil;
}

// MARK: - Plist

/// Helper for optional chaining.
NSDictionary * _Nullable asPlistOrNil(NSData * _Nullable data) {
    if (!data.length) { return nil; }
    NSError *err;
    NSDictionary *dict = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:&err];
    if (err) {
        NSLog(@"ERROR reading plist %@", err);
        return nil;
    }
    return dict;
}

/// Read app default @c Info.plist.
NSDictionary * _Nullable readPlistApp(QuickLookInfo meta) {
    switch (meta.type) {
        case FileTypeIPA:
        case FileTypeArchive:
        case FileTypeExtension: {
            return asPlistOrNil(readPayloadFile(meta, @"Info.plist"));
        }
        case FileTypeProvision:
            return nil;
    }
    return nil;
}

/// Read @c embedded.mobileprovision file and decode with CMS decoder.
NSDictionary * _Nullable readPlistProvision(QuickLookInfo meta) {
    NSData *provisionData;
    if (meta.type == FileTypeProvision) {
        provisionData = [NSData dataWithContentsOfURL:meta.url]; // the target file itself
    } else {
        provisionData = readPayloadFile(meta, @"embedded.mobileprovision");
    }
    if (!provisionData) {
        NSLog(@"No provisionData for %@", meta.url);
        return nil;
    }
    
    CMSDecoderRef decoder = NULL;
    CMSDecoderCreate(&decoder);
    CMSDecoderUpdateMessage(decoder, provisionData.bytes, provisionData.length);
    CMSDecoderFinalizeMessage(decoder);
    CFDataRef dataRef = NULL;
    CMSDecoderCopyContent(decoder, &dataRef);
    NSData *data = (NSData *)CFBridgingRelease(dataRef);
    CFRelease(decoder);
    return asPlistOrNil(data);
}

/// Read @c iTunesMetadata.plist if available
NSDictionary * _Nullable readPlistItunes(QuickLookInfo meta) {
    if (meta.type == FileTypeIPA) {
        return asPlistOrNil([meta.zipFile unzipFile:@"iTunesMetadata.plist" isExactMatch:YES]);
    }
    return nil;
}

// MARK: - Other helper

/// Check time between date and now. Set Expiring if less than 30 days until expiration
ExpirationStatus expirationStatus(NSDate *date) {
    if (!date || [date compare:[NSDate date]] == NSOrderedAscending) {
        return ExpirationStatusExpired;
    }
    NSDateComponents *dateComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitDay fromDate:[NSDate date] toDate:date options:0];
    return dateComponents.day < 30 ? ExpirationStatusExpiring : ExpirationStatusValid;
}

/// Ensures the value is of type @c NSDate
inline NSDate * _Nullable dateOrNil(NSDate * _Nullable value) {
    return [value isKindOfClass:[NSDate class]] ? value : nil;
}

/// Ensures the value is of type @c NSArray
inline NSArray * _Nullable arrayOrNil(NSArray * _Nullable value) {
    return [value isKindOfClass:[NSArray class]] ? value : nil;
}
