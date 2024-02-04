#import "Shared.h"
#import "AppCategories.h"
#import "Entitlements.h"

// makro to stop further processing
#define ALLOW_EXIT if (QLPreviewRequestIsCancelled(preview)) { return noErr; }

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

/* -----------------------------------------------------------------------------
 Generate a preview for file
 
 This function's job is to create preview for designated file
 ----------------------------------------------------------------------------- */

// MARK: - Generic data formatting & printing

typedef NSArray<NSString*> TableRow;

/// Print html table with arbitrary number of columns
/// @param header If set, start the table with a @c tr column row.
NSString * _Nonnull formatAsTable(TableRow * _Nullable header, NSArray<TableRow*>* data) {
	NSMutableString *table = [NSMutableString string];
	[table appendString:@"<table>\n"];
	if (header) {
		[table appendFormat:@"<tr><th>%@</th></tr>\n", [header componentsJoinedByString:@"</th><th>"]];
	}
	for (TableRow *row in data) {
		[table appendFormat:@"<tr><td>%@</td></tr>\n", [row componentsJoinedByString:@"</td><td>"]];
	}
	[table appendString:@"</table>\n"];
	return table;
}

/// Print recursive tree of key-value mappings.
void recursiveDictWithReplacements(NSDictionary *dictionary, NSDictionary *replacements, int level, NSMutableString *output) {
	for (NSString *key in dictionary) {
		NSString *localizedKey = replacements[key] ?: key;
		NSObject *object = dictionary[key];

		for (int idx = 0; idx < level; idx++) {
			[output appendString:(level == 1) ? @"- " : @"&nbsp;&nbsp;"];
		}

		if ([object isKindOfClass:[NSDictionary class]]) {
			[output appendFormat:@"%@:<div class=\"list\">", localizedKey];
			recursiveDictWithReplacements((NSDictionary *)object, replacements, level + 1, output);
			[output appendString:@"</div>"];
		} else if ([object isKindOfClass:[NSNumber class]]) {
			object = [(NSNumber *)object boolValue] ? @"YES" : @"NO";
			[output appendFormat:@"%@: %@<br />", localizedKey, object];
		} else {
			[output appendFormat:@"%@: %@<br />", localizedKey, object];
		}
	}
}

/// Replace occurrences of chars @c &"'<> with html encoding.
NSString *escapedXML(NSString *stringToEscape) {
	stringToEscape = [stringToEscape stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
	NSDictionary *htmlEntityReplacement = @{
		@"\"": @"&quot;",
		@"'": @"&apos;",
		@"<": @"&lt;",
		@">": @"&gt;",
	};
	for (NSString *key in [htmlEntityReplacement allKeys]) {
		NSString *replacement = [htmlEntityReplacement objectForKey:key];
		stringToEscape = [stringToEscape stringByReplacingOccurrencesOfString:key withString:replacement];
	}
	return stringToEscape;
}

/// Convert image to PNG and encode with base64 to be embeded in html output.
NSString * _Nonnull iconAsBase64(NSImage *appIcon) {
	appIcon = roundCorners(appIcon);
	NSData *imageData = [appIcon TIFFRepresentation];
	NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
	imageData = [imageRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
	return [imageData base64EncodedStringWithOptions:0];
}


// MARK: - Date processing

/// @return Difference between two dates as components.
NSDateComponents * _Nonnull dateDiff(NSDate *start, NSDate *end, NSCalendar *calendar) {
	return [calendar components:(NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute)
					   fromDate:start toDate:end options:0];
}

/// @return Print largest component. E.g., "3 days" or "14 hours"
NSString * _Nonnull relativeDateString(NSDateComponents *comp) {
	NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
	formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
	formatter.maximumUnitCount = 1;
	return [formatter stringFromDateComponents:comp];
}

/// @return Print the date with current locale and medium length style.
NSString * _Nonnull formattedDate(NSDate *date) {
	NSDateFormatter *formatter = [NSDateFormatter new];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterMediumStyle];
	return [formatter stringFromDate:date];
}

/// Parse date from plist regardless if it has @c NSDate or @c NSString type.
NSDate *parseDate(id value) {
	if (!value) {
		return nil;
	}
	if ([value isKindOfClass:[NSDate class]]) {
		return value;
	}
	// parse the date from a string
	NSString *dateStr = [value description];
	NSDateFormatter *dateFormatter = [NSDateFormatter new];
	[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss Z"];
	NSDate *rv = [dateFormatter dateFromString:dateStr];
	if (!rv) {
		[dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
		rv = [dateFormatter dateFromString:dateStr];
	}
	if (!rv) {
		NSLog(@"ERROR formatting date: %@", dateStr);
	}
	return rv;
}

/// @return Relative distance to today. E.g., "Expired today"
NSString * _Nullable relativeExpirationDateString(NSDate *date) {
	if (!date) {
		return nil;
	}

	NSCalendar *calendar = [NSCalendar currentCalendar];
	BOOL isPast = [date compare:[NSDate date]] == NSOrderedAscending;
	BOOL isToday = [calendar isDate:date inSameDayAsDate:[NSDate date]];

	if (isToday) {
		return isPast ? @"<span>Expired today</span>" : @"<span>Expires today</span>";
	}

	if (isPast) {
		NSDateComponents *comp = dateDiff(date, [NSDate date], calendar);
		return [NSString stringWithFormat:@"<span>Expired %@ ago</span>", relativeDateString(comp)];
	}

	NSDateComponents *comp = dateDiff([NSDate date], date, calendar);
	if (comp.day < 30) {
		return [NSString stringWithFormat:@"<span>Expires in %@</span>", relativeDateString(comp)];
	}
	return [NSString stringWithFormat:@"Expires in %@", relativeDateString(comp)];
}

/// @return Relative distance to today. E.g., "DATE (Expires in 3 days)"
NSString * _Nonnull formattedExpirationDate(NSDate *expireDate) {
	return [NSString stringWithFormat:@"%@ (%@)", formattedDate(expireDate), relativeExpirationDateString(expireDate)];
}

/// @return Relative distance to today. E.g., "DATE (Created 3 days ago)"
NSString * _Nonnull formattedCreationDate(NSDate *creationDate) {
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *comp = dateDiff(creationDate, [NSDate date], calendar);
	BOOL isToday = [calendar isDate:creationDate inSameDayAsDate:[NSDate date]];
	return [NSString stringWithFormat:@"%@ (Created %@)", formattedDate(creationDate),
			isToday ? @"today" : [NSString stringWithFormat:@"%@ ago", relativeDateString(comp)]];
}

/// @return CSS class for expiration status.
NSString * _Nonnull classNameForExpirationStatus(NSDate *date) {
	switch (expirationStatus(date)) {
		case ExpirationStatusExpired:  return @"expired";
		case ExpirationStatusExpiring: return @"expiring";
		case ExpirationStatusValid:    return @"valid";
	}
}


// MARK: - App Info

/// @return List of ATS flags.
NSString * _Nonnull formattedAppTransportSecurity(NSDictionary *appPlist) {
	NSDictionary *value = appPlist[@"NSAppTransportSecurity"];
	if ([value isKindOfClass:[NSDictionary class]]) {
		NSDictionary *localizedKeys = @{
			@"NSAllowsArbitraryLoads": @"Allows Arbitrary Loads",
			@"NSAllowsArbitraryLoadsForMedia": @"Allows Arbitrary Loads for Media",
			@"NSAllowsArbitraryLoadsInWebContent": @"Allows Arbitrary Loads in Web Content",
			@"NSAllowsLocalNetworking": @"Allows Local Networking",
			@"NSExceptionDomains": @"Exception Domains",

			@"NSIncludesSubdomains": @"Includes Subdomains",
			@"NSRequiresCertificateTransparency": @"Requires Certificate Transparency",

			@"NSExceptionAllowsInsecureHTTPLoads": @"Allows Insecure HTTP Loads",
			@"NSExceptionMinimumTLSVersion": @"Minimum TLS Version",
			@"NSExceptionRequiresForwardSecrecy": @"Requires Forward Secrecy",

			@"NSThirdPartyExceptionAllowsInsecureHTTPLoads": @"Allows Insecure HTTP Loads",
			@"NSThirdPartyExceptionMinimumTLSVersion": @"Minimum TLS Version",
			@"NSThirdPartyExceptionRequiresForwardSecrecy": @"Requires Forward Secrecy"
		};

		NSMutableString *output = [NSMutableString string];
		recursiveDictWithReplacements(value, localizedKeys, 0, output);
		return [NSString stringWithFormat:@"<div class=\"list\">%@</div>", output];
	}

	NSString *sdkName = appPlist[@"DTSDKName"];
	double sdkNumber = [[sdkName stringByTrimmingCharactersInSet:[NSCharacterSet letterCharacterSet]] doubleValue];
	if (sdkNumber < 9.0) {
		return @"Not applicable before iOS 9.0";
	}
	return @"No exceptions";
}

/// Process info stored in @c Info.plist
NSDictionary * _Nonnull procAppInfo(NSDictionary *appPlist) {
	if (!appPlist) {
		return @{
			@"AppInfoHidden": @"hiddenDiv",
			@"ProvisionTitleHidden": @"",
		};
	}

	NSString *extensionType = appPlist[@"NSExtension"][@"NSExtensionPointIdentifier"];

	NSMutableArray *platforms = [NSMutableArray array];
	for (NSNumber *number in appPlist[@"UIDeviceFamily"]) {
		switch ([number intValue]) {
			case 1: [platforms addObject:@"iPhone"]; break;
			case 2: [platforms addObject:@"iPad"]; break;
			case 3: [platforms addObject:@"TV"]; break;
			case 4: [platforms addObject:@"Watch"]; break;
			default: break;
		}
	}

	return @{
		@"AppInfoHidden": @"",
		@"ProvisionTitleHidden": @"hiddenDiv",

		@"CFBundleName": appPlist[@"CFBundleDisplayName"] ?: appPlist[@"CFBundleName"] ?: @"",
		@"CFBundleShortVersionString": appPlist[@"CFBundleShortVersionString"] ?: @"",
		@"CFBundleVersion": appPlist[@"CFBundleVersion"] ?: @"",
		@"CFBundleIdentifier": appPlist[@"CFBundleIdentifier"] ?: @"",

		@"ExtensionTypeHidden": extensionType ? @"" : @"hiddenDiv",
		@"ExtensionType": extensionType ?: @"",

		@"UIDeviceFamily": [platforms componentsJoinedByString:@", "],
		@"DTSDKName": appPlist[@"DTSDKName"] ?: @"",
		@"MinimumOSVersion": appPlist[@"MinimumOSVersion"] ?: @"",
		@"AppTransportSecurityFormatted": formattedAppTransportSecurity(appPlist),
	};
}


// MARK: - iTunes Purchase Information

/// Concatenate all (sub)genres into a comma separated list.
NSString *formattedGenres(NSDictionary *itunesPlist) {
	NSDictionary *categories = getAppCategories();
	NSMutableArray *genres = [NSMutableArray array];
	NSString *mainGenre = categories[itunesPlist[@"genreId"] ?: @0] ?: itunesPlist[@"genre"];
	if (mainGenre) {
		[genres addObject:mainGenre];
	}
	for (NSDictionary *item in itunesPlist[@"subgenres"]) {
		NSString *subgenre = categories[item[@"genreId"] ?: @0] ?: item[@"genre"];
		if (subgenre) {
			[genres addObject:subgenre];
		}
	}
	return [genres componentsJoinedByString:@", "];
}

/// Process info stored in @c iTunesMetadata.plist
NSDictionary *parseItunesMeta(NSDictionary *itunesPlist) {
	if (!itunesPlist) {
		return @{
			@"iTunesHidden": @"hiddenDiv",
		};
	}

	NSDictionary *downloadInfo = itunesPlist[@"com.apple.iTunesStore.downloadInfo"];
	NSDictionary *accountInfo = downloadInfo[@"accountInfo"];

	NSDate *purchaseDate = parseDate(downloadInfo[@"purchaseDate"] ?: itunesPlist[@"purchaseDate"]);
	NSDate *releaseDate = parseDate(downloadInfo[@"releaseDate"] ?: itunesPlist[@"releaseDate"]);
	// AppleId & purchaser name
	NSString *appleId = accountInfo[@"AppleID"] ?: itunesPlist[@"appleId"];
	NSString *firstName = accountInfo[@"FirstName"];
	NSString *lastName = accountInfo[@"LastName"];
	NSString *name;
	if (firstName || lastName) {
		name = [NSString stringWithFormat:@"%@ %@ (%@)", firstName, lastName, appleId];
	} else {
		name = appleId;
	}

	return @{
		@"iTunesHidden": @"",
		@"iTunesId": [itunesPlist[@"itemId"] description] ?: @"",
		@"iTunesName": itunesPlist[@"itemName"] ?: @"",
		@"iTunesGenres": formattedGenres(itunesPlist),
		@"iTunesReleaseDate": releaseDate ? formattedDate(releaseDate) : @"",

		@"iTunesAppleId": name ?: @"",
		@"iTunesPurchaseDate": purchaseDate ? formattedDate(purchaseDate) : @"",
		@"iTunesPrice": itunesPlist[@"priceDisplay"] ?: @"",
	};
}


// MARK: - Certificates

/// Process a single certificate. Extract invalidity / expiration date.
/// @param subject just used for printing error logs.
NSDate * _Nullable getCertificateInvalidityDate(SecCertificateRef certificateRef, NSString *subject) {
	NSDate *invalidityDate = nil;
	CFErrorRef error = nil;
	CFDictionaryRef outerDictRef = SecCertificateCopyValues(certificateRef, (__bridge CFArrayRef)@[(__bridge NSString*)kSecOIDInvalidityDate], &error);
	if (outerDictRef) {
		CFDictionaryRef innerDictRef = CFDictionaryGetValue(outerDictRef, kSecOIDInvalidityDate);
		if (innerDictRef) {
			// NOTE: the invalidity date type of kSecPropertyTypeDate is documented as a CFStringRef in the "Certificate, Key, and Trust Services Reference".
			// In reality, it's a __NSTaggedDate (presumably a tagged pointer representing an NSDate.) But to sure, we'll check:
			id value = CFBridgingRelease(CFDictionaryGetValue(innerDictRef, kSecPropertyKeyValue));
			if (value) {
				invalidityDate = parseDate(value);
			} else {
				NSLog(@"No invalidity date in '%@' certificate, dictionary = %@", subject, innerDictRef);
			}
			// no CFRelease(innerDictRef); since it has the same references as outerDictRef
		} else {
			NSLog(@"No invalidity values in '%@' certificate, dictionary = %@", subject, outerDictRef);
		}
		CFRelease(outerDictRef);
	} else {
		NSLog(@"Could not get values in '%@' certificate, error = %@", subject, error);
		CFRelease(error);
	}
	return invalidityDate;
}

/// Process list of all certificates. Return a two column table with subject and expiration date.
NSArray<TableRow*> * _Nonnull getCertificateList(NSDictionary *provisionPlist) {
	NSArray *certArr = provisionPlist[@"DeveloperCertificates"];
	if (![certArr isKindOfClass:[NSArray class]]) {
		return @[];
	}

	NSMutableArray<TableRow*> *entries = [NSMutableArray array];
	for (NSData *data in certArr) {
		SecCertificateRef certificateRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)data);
		if (!certificateRef) {
			continue;
		}
		NSString *subject = (NSString *)CFBridgingRelease(SecCertificateCopySubjectSummary(certificateRef));
		if (subject) {
			NSDate *invalidityDate = getCertificateInvalidityDate(certificateRef, subject);
			NSString *expiration = relativeExpirationDateString(invalidityDate);
			[entries addObject:@[subject, expiration ?: @"<span class='warning'>No invalidity date in certificate</span>"]];
		} else {
			NSLog(@"Could not get subject from certificate");
		}
		CFRelease(certificateRef);
	}
	
	[entries sortUsingComparator:^NSComparisonResult(NSArray *obj1, NSArray *obj2) {
		return [obj1[0] compare:obj2[0]];
	}];
	return entries;
}


// MARK: - Provisioning

/// Returns provision type string like "Development" or "Distribution (App Store)".
NSString * _Nonnull stringForProfileType(NSDictionary *provisionPlist, BOOL isOSX) {
	BOOL hasDevices = [provisionPlist[@"ProvisionedDevices"] isKindOfClass:[NSArray class]];
	if (isOSX) {
		return hasDevices ? @"Development" : @"Distribution (App Store)";
	}
	if (hasDevices) {
		BOOL getTaskAllow = [[provisionPlist[@"Entitlements"] valueForKey:@"get-task-allow"] boolValue];
		return getTaskAllow ? @"Development" : @"Distribution (Ad Hoc)";
	}
	BOOL isEnterprise = [provisionPlist[@"ProvisionsAllDevices"] boolValue];
	return isEnterprise ? @"Enterprise" : @"Distribution (App Store)";
}

/// Enumerate all entries from provison plist with key @c ProvisionedDevices
NSArray<TableRow*> * _Nonnull getDeviceList(NSDictionary *provisionPlist) {
	NSArray *devArr = provisionPlist[@"ProvisionedDevices"];
	if (![devArr isKindOfClass:[NSArray class]]) {
		return @[];
	}

	NSMutableArray<TableRow*> *devices = [NSMutableArray array];
	NSString *currentPrefix = nil;

	for (NSString *device in [devArr sortedArrayUsingSelector:@selector(compare:)]) {
		// compute the prefix for the first column of the table
		NSString *displayPrefix = @"";
		NSString *devicePrefix = [device substringToIndex:1];
		if (! [currentPrefix isEqualToString:devicePrefix]) {
			currentPrefix = devicePrefix;
			displayPrefix = [NSString stringWithFormat:@"%@ ➞ ", devicePrefix];
		}
		[devices addObject:@[displayPrefix, device]];
	}
	return devices;
}

/// Process info stored in @c embedded.mobileprovision
NSDictionary * _Nonnull procProvision(NSDictionary *provisionPlist, BOOL isOSX) {
	if (!provisionPlist) {
		return @{
			@"ProvisionHidden": @"hiddenDiv",
		};
	}

	NSDate *creationDate = dateOrNil(provisionPlist[@"CreationDate"]);
	NSDate *expireDate = dateOrNil(provisionPlist[@"ExpirationDate"]);
	NSArray<TableRow*>* devices = getDeviceList(provisionPlist);

	return @{
		@"ProvisionHidden": @"",
		@"ProfileName": provisionPlist[@"Name"] ?: @"",
		@"ProfileUUID": provisionPlist[@"UUID"] ?: @"",
		@"TeamName": provisionPlist[@"TeamName"] ?: @"<em>Team name not available</em>",
		@"TeamIds": [provisionPlist[@"TeamIdentifier"] componentsJoinedByString:@", "] ?: @"<em>Team ID not available</em>",
		@"CreationDateFormatted": creationDate ? formattedCreationDate(creationDate) : @"",
		@"ExpirationDateFormatted": expireDate ? formattedExpirationDate(expireDate) : @"",
		@"ExpStatus": classNameForExpirationStatus(expireDate),

		@"ProfilePlatform": isOSX ? @"Mac" : @"iOS",
		@"ProfileType": stringForProfileType(provisionPlist, isOSX),

		@"ProvisionedDevicesCount": devices.count ? [NSString stringWithFormat:@"%zd Device%s", devices.count, (devices.count == 1 ? "" : "s")] : @"No Devices",
		@"ProvisionedDevicesFormatted": devices.count ? formatAsTable(@[@"", @"UDID"], devices) : @"Distribution Profile",

		@"DeveloperCertificatesFormatted": formatAsTable(nil, getCertificateList(provisionPlist)) ?: @"No Developer Certificates",
	};
}


// MARK: - Entitlements

/// Search for app binary and run @c codesign on it.
Entitlements *readEntitlements(QuickLookInfo meta, NSString *bundleExecutable) {
	if (!bundleExecutable) {
		return [Entitlements withoutBinary];
	}
	NSString *tempDirFolder = [NSTemporaryDirectory() stringByAppendingPathComponent:kPluginBundleId];
	NSString *currentTempDirFolder = nil;
	NSString *basePath = nil;
	switch (meta.type) {
		case FileTypeIPA:
			currentTempDirFolder = [tempDirFolder stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
			[[NSFileManager defaultManager] createDirectoryAtPath:currentTempDirFolder withIntermediateDirectories:YES attributes:nil error:nil];
			[meta.zipFile unzipFile:[@"Payload/*.app/" stringByAppendingPathComponent:bundleExecutable] toDir:currentTempDirFolder];
			basePath = currentTempDirFolder;
			break;
		case FileTypeArchive:
			basePath = meta.effectiveUrl.path;
			break;
		case FileTypeExtension:
			basePath = meta.url.path;
			break;
		case FileTypeProvision:
			return nil;
	}

	Entitlements *rv = [Entitlements withBinary:[basePath stringByAppendingPathComponent:bundleExecutable]];
	if (currentTempDirFolder) {
		[[NSFileManager defaultManager] removeItemAtPath:currentTempDirFolder error:nil];
	}
	return rv;
}

/// Process compiled binary and provision plist to extract @c Entitlements
NSDictionary * _Nonnull procEntitlements(QuickLookInfo meta, NSDictionary *appPlist, NSDictionary *provisionPlist) {
	Entitlements *entitlements = readEntitlements(meta, appPlist[@"CFBundleExecutable"]);
	[entitlements applyFallbackIfNeeded:provisionPlist[@"Entitlements"]];

	return @{
		@"EntitlementsWarningHidden": entitlements.hasError ? @"" : @"hiddenDiv",
		@"EntitlementsFormatted": entitlements.html ?: @"No Entitlements",
	};
}


// MARK: - File Info

/// Title of the preview window
NSString * _Nullable stringForFileType(QuickLookInfo meta) {
	switch (meta.type) {
		case FileTypeIPA: return @"App info";
		case FileTypeArchive: return @"Archive info";
		case FileTypeExtension: return @"App extension info";
		case FileTypeProvision: return nil;
	}
	return nil;
}

/// Calculate file / folder size.
unsigned long long getFileSize(NSString *path) {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDir;
	[fileManager fileExistsAtPath:path isDirectory:&isDir];
	if (!isDir) {
		return [[fileManager attributesOfItemAtPath:path error:NULL] fileSize];
	}

	unsigned long long fileSize = 0;
	NSArray *children = [fileManager subpathsOfDirectoryAtPath:path error:nil];
	for (NSString *fileName in children) {
		fileSize += [[fileManager attributesOfItemAtPath:[path stringByAppendingPathComponent:fileName] error:NULL] fileSize];
	}
	return fileSize;
}

/// Process meta information about the file itself. Like file size and last modification.
NSDictionary * _Nonnull procFileInfo(NSURL *url) {
	NSString *formattedValue = nil;
	NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:NULL];
	if (attrs) {
		formattedValue = [NSString stringWithFormat:@"%@, Modified %@",
						  [NSByteCountFormatter stringFromByteCount:getFileSize(url.path) countStyle:NSByteCountFormatterCountStyleFile],
						  formattedDate([attrs fileModificationDate])];
	}

	return @{
		@"FileName": escapedXML([url lastPathComponent]),
		@"FileInfo": formattedValue ?: @"",
	};
}


// MARK: - Footer Info

/// Process meta information about the plugin. Like version and debug flag.
NSDictionary * _Nonnull procFooterInfo() {
	NSBundle *mainBundle = [NSBundle bundleWithIdentifier:kPluginBundleId];
	return @{
#ifdef DEBUG
		@"DEBUG": @"(debug)",
#else
		@"DEBUG": @"",
#endif
		@"BundleShortVersionString": [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"",
		@"BundleVersion": [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"",
	};
}


// MARK: - Main Entry

NSString *applyHtmlTemplate(NSDictionary *templateValues) {
	NSURL *templateURL = [[NSBundle bundleWithIdentifier:kPluginBundleId] URLForResource:@"template" withExtension:@"html"];
	NSString *html = [NSString stringWithContentsOfURL:templateURL encoding:NSUTF8StringEncoding error:NULL];

	// this is less efficient
//	for (NSString *key in [templateValues allKeys]) {
//		[html replaceOccurrencesOfString:[NSString stringWithFormat:@"__%@__", key]
//							  withString:[templateValues objectForKey:key]
//								 options:0 range:NSMakeRange(0, [html length])];
//	}

	NSMutableString *rv = [NSMutableString string];
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"__[^ _]{1,40}?__" options:0 error:nil];
	__block NSUInteger prevLoc = 0;
	[regex enumerateMatchesInString:html options:0 range:NSMakeRange(0, html.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
		NSUInteger start = result.range.location;
		NSString *key = [html substringWithRange:NSMakeRange(start + 2, result.range.length - 4)];
		[rv appendString:[html substringWithRange:NSMakeRange(prevLoc, start - prevLoc)]];
		NSString *value = templateValues[key];
		if (value) {
			[rv appendString:value];
		}
		prevLoc = start + result.range.length;
	}];
	[rv appendString:[html substringWithRange:NSMakeRange(prevLoc, html.length - prevLoc)]];
	return rv;
}

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options) {
	@autoreleasepool {
		QuickLookInfo meta = initQLInfo(contentTypeUTI, url);
		if (!meta.type) {
			return noErr;
		}
		NSMutableDictionary* infoLayer = [NSMutableDictionary dictionary];
		infoLayer[@"AppInfoTitle"] = stringForFileType(meta);

		// App Info
		NSDictionary *plistApp = readPlistApp(meta);
		[infoLayer addEntriesFromDictionary:procAppInfo(plistApp)];
		ALLOW_EXIT

		NSDictionary *plistItunes = readPlistItunes(meta);
		[infoLayer addEntriesFromDictionary:parseItunesMeta(plistItunes)];
		ALLOW_EXIT

		// Provisioning
		NSDictionary *plistProvision = readPlistProvision(meta);

		if (!plistApp && !plistProvision) {
			return noErr; // nothing to do. Maybe another QL plugin can do better.
		}

		[infoLayer addEntriesFromDictionary:procProvision(plistProvision, meta.isOSX)];
		ALLOW_EXIT

		// App Icon
		infoLayer[@"AppIcon"] = iconAsBase64(imageFromApp(meta, plistApp));
		ALLOW_EXIT

		// Entitlements
		[infoLayer addEntriesFromDictionary:procEntitlements(meta, plistApp, plistProvision)];
		ALLOW_EXIT

		// File Info
		[infoLayer addEntriesFromDictionary:procFileInfo(meta.url)];

		// Footer Info
		[infoLayer addEntriesFromDictionary:procFooterInfo()];
		ALLOW_EXIT

		// prepare html, replace values
		NSString *html = applyHtmlTemplate(infoLayer);

		// QL render html
		NSDictionary *properties = @{ // properties for the HTML data
			(__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
			(__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html"
		};
		QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)[html dataUsingEncoding:NSUTF8StringEncoding], kUTTypeHTML, (__bridge CFDictionaryRef)properties);
	}
	return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {
	// Implement only if supported
}
