#import "Shared.h"

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
void recursiveKeyValue(NSUInteger level, NSString *key, id value, NSMutableString *output) {
	int indent = (int)(level * 4);

	if ([value isKindOfClass:[NSDictionary class]]) {
		if (key) {
			[output appendFormat:@"%*s%@ = {\n", indent, "", key];
		} else if (level != 0) {
			[output appendFormat:@"%*s{\n", indent, ""];
		}
		NSDictionary *dictionary = (NSDictionary *)value;
		NSArray *keys = [[dictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];
		for (NSString *subKey in keys) {
			NSUInteger subLevel = (key == nil && level == 0) ? 0 : level + 1;
			recursiveKeyValue(subLevel, subKey, [dictionary valueForKey:subKey], output);
		}
		if (level != 0) {
			[output appendFormat:@"%*s}\n", indent, ""];
		}
	} else if ([value isKindOfClass:[NSArray class]]) {
		[output appendFormat:@"%*s%@ = (\n", indent, "", key];
		NSArray *array = (NSArray *)value;
		for (id value in array) {
			recursiveKeyValue(level + 1, nil, value, output);
		}
		[output appendFormat:@"%*s)\n", indent, ""];
	} else if ([value isKindOfClass:[NSData class]]) {
		NSData *data = (NSData *)value;
		if (key) {
			[output appendFormat:@"%*s%@ = %zd bytes of data\n", indent, "", key, [data length]];
		} else {
			[output appendFormat:@"%*s%zd bytes of data\n", indent, "", [data length]];
		}
	} else {
		if (key) {
			[output appendFormat:@"%*s%@ = %@\n", indent, "", key, value];
		} else {
			[output appendFormat:@"%*s%@\n", indent, "", value];
		}
	}
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
			@"AppInfo": @"hiddenDiv",
			@"ProvisionAsSubheader": @"",
		};
	}

	NSString *bundleName = appPlist[@"CFBundleDisplayName"];
	if (!bundleName) {
		bundleName = appPlist[@"CFBundleName"];
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
		@"AppInfo": @"",
		@"ProvisionAsSubheader": @"hiddenDiv",

		@"CFBundleName": appPlist[@"CFBundleDisplayName"] ?: appPlist[@"CFBundleName"] ?: @"",
		@"CFBundleShortVersionString": appPlist[@"CFBundleShortVersionString"] ?: @"",
		@"CFBundleVersion": appPlist[@"CFBundleVersion"] ?: @"",
		@"CFBundleIdentifier": appPlist[@"CFBundleIdentifier"] ?: @"",

		@"ExtensionInfo": extensionType ? @"" : @"hiddenDiv",
		@"NSExtensionPointIdentifier": extensionType ?: @"",

		@"UIDeviceFamily": [platforms componentsJoinedByString:@", "],
		@"DTSDKName": appPlist[@"DTSDKName"] ?: @"",
		@"MinimumOSVersion": appPlist[@"MinimumOSVersion"] ?: @"",
		@"AppTransportSecurityFormatted": formattedAppTransportSecurity(appPlist),
	};
}


// MARK: - Certificates

/// Process a single certificate. Extract invalidity / expiration date.
/// @param subject just used for printing error logs.
NSDate * _Nullable getCertificateInvalidityDate(SecCertificateRef certificateRef, NSString *subject) {
	NSDate *invalidityDate = nil;
	CFErrorRef error = nil;
	CFDictionaryRef outerDictRef = SecCertificateCopyValues(certificateRef, (__bridge CFArrayRef)@[(__bridge NSString*)kSecOIDInvalidityDate], &error);
	if (outerDictRef && !error) {
		CFDictionaryRef innerDictRef = CFDictionaryGetValue(outerDictRef, kSecOIDInvalidityDate);
		if (innerDictRef) {
			// NOTE: the invalidity date type of kSecPropertyTypeDate is documented as a CFStringRef in the "Certificate, Key, and Trust Services Reference".
			// In reality, it's a __NSTaggedDate (presumably a tagged pointer representing an NSDate.) But to sure, we'll check:
			id value = CFBridgingRelease(CFDictionaryGetValue(innerDictRef, kSecPropertyKeyValue));
			if (value) {
				if ([value isKindOfClass:[NSDate class]]) {
					invalidityDate = value;
				} else {
					// parse the date from a string
					NSDateFormatter *dateFormatter = [NSDateFormatter new];
					[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss Z"];
					invalidityDate = [dateFormatter dateFromString:[value description]];
				}
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
			@"ProvisionInfo": @"hiddenDiv",
		};
	}

	NSDate *creationDate = dateOrNil(provisionPlist[@"CreationDate"]);
	NSDate *expireDate = dateOrNil(provisionPlist[@"ExpirationDate"]);
	NSArray<TableRow*>* devices = getDeviceList(provisionPlist);

	return @{
		@"ProvisionInfo": @"",
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

/// run:  @c codesign -d <AppBinary> --entitlements - --xml
NSData *runCodeSign(NSString *binaryPath) {
	NSTask *codesignTask = [NSTask new];
	[codesignTask setLaunchPath:@"/usr/bin/codesign"];
	[codesignTask setStandardOutput:[NSPipe pipe]];
	[codesignTask setStandardError:[NSPipe pipe]];
	if (@available(macOS 11, *)) {
		[codesignTask setArguments:@[@"-d", binaryPath, @"--entitlements", @"-", @"--xml"]];
	} else {
		[codesignTask setArguments:@[@"-d", binaryPath, @"--entitlements", @":-"]];
	}
	[codesignTask launch];

	NSData *outputData = [[[codesignTask standardOutput] fileHandleForReading] readDataToEndOfFile];
	NSData *errorData = [[[codesignTask standardError] fileHandleForReading] readDataToEndOfFile];
	[codesignTask waitUntilExit];

	if (outputData.length == 0) {
		return errorData;
	}
	return outputData;
}

/// Search for app binary and run @c codesign on it.
NSData *getCodeSignEntitlements(QuickLookInfo meta, NSString *bundleExecutable) {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *tempDirFolder = [NSTemporaryDirectory() stringByAppendingPathComponent:kPluginBundleId];
	NSString *currentTempDirFolder = [tempDirFolder stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];

	NSString *basePath = nil;
	switch (meta.type) {
		case FileTypeIPA:
			basePath = currentTempDirFolder;
			[fileManager createDirectoryAtPath:currentTempDirFolder withIntermediateDirectories:YES attributes:nil error:nil];
			unzipFileToDir(meta.url, currentTempDirFolder, [@"Payload/*.app/" stringByAppendingPathComponent:bundleExecutable]);
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

	NSData *data = runCodeSign([basePath stringByAppendingPathComponent:bundleExecutable]);
	[fileManager removeItemAtPath:currentTempDirFolder error:nil];
	return data;
}

/// Print formatted plist in a @c \<pre> tag
NSString * _Nonnull formattedPlist(NSDictionary *dict) {
	NSMutableString *output = [NSMutableString string];
	recursiveKeyValue(0, nil, dict, output);
	return [NSString stringWithFormat:@"<pre>%@</pre>", output];
}

/// First, try to extract real entitlements by running codesign.
/// If that fails, fallback to entitlements provided by provision plist.
NSDictionary * _Nonnull procEntitlements(NSData *codeSignData, NSDictionary *provisionPlist) {
	BOOL showEntitlementsWarning = false;
	NSString *formattedOutput = nil;
	if (codeSignData != nil) {
		NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:codeSignData options:0 format:NULL error:NULL];
		if (plist != nil) {
			formattedOutput = formattedPlist(plist);
		} else {
			showEntitlementsWarning = true;
			NSString *output = [[NSString alloc] initWithData:codeSignData encoding:NSUTF8StringEncoding];
			if ([output hasPrefix:@"Executable="]) {
				// remove first line with long temporary path to the executable
				NSArray *allLines = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
				formattedOutput = [[allLines subarrayWithRange:NSMakeRange(1, allLines.count - 1)] componentsJoinedByString:@"<br />"];
			} else {
				formattedOutput = output;
			}
		}
	} else {
		// read the entitlements from the provisioning profile instead
		NSDictionary *value = provisionPlist[@"Entitlements"];
		if ([value isKindOfClass:[NSDictionary class]]) {
			formattedOutput = formattedPlist(value);
		} else {
			formattedOutput = @"No Entitlements";
		}
	}

	return @{
		@"EntitlementsFormatted": formattedOutput ?: @"",
		@"EntitlementsWarning": showEntitlementsWarning ? @"" : @"hiddenDiv",
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
		if (!value) {
			NSLog(@"WARN: unused key %@", key);
		} else {
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
		NSMutableDictionary* infoLayer = [NSMutableDictionary dictionary];
		infoLayer[@"AppInfoTitle"] = stringForFileType(meta);

		// App Info
		NSDictionary *plistApp = readPlistApp(meta);
		ALLOW_EXIT

		[infoLayer addEntriesFromDictionary:procAppInfo(plistApp)];
		ALLOW_EXIT

		// Provisioning
		NSDictionary *plistProvision = readPlistProvision(meta);
		ALLOW_EXIT

		if (!plistApp && !plistProvision) {
			return noErr; // nothing to do. Maybe another QL plugin can do better.
		}

		[infoLayer addEntriesFromDictionary:procProvision(plistProvision, meta.isOSX)];
		ALLOW_EXIT

		// App Icon
		infoLayer[@"AppIcon"] = iconAsBase64(imageFromApp(meta, plistApp));
		ALLOW_EXIT

		// Entitlements
		NSString *bundleExecutable = plistApp[@"CFBundleExecutable"];
		NSData *codeSignData = getCodeSignEntitlements(meta, bundleExecutable);
		ALLOW_EXIT

		[infoLayer addEntriesFromDictionary:procEntitlements(codeSignData, plistProvision)];
		ALLOW_EXIT

		// File Info
		[infoLayer addEntriesFromDictionary:procFileInfo(meta.url)];
		ALLOW_EXIT

		// Footer Info
		[infoLayer addEntriesFromDictionary:procFooterInfo()];
		ALLOW_EXIT

		// prepare html, replace values
		NSString *html = applyHtmlTemplate(infoLayer);
		ALLOW_EXIT

		// QL render html
		NSDictionary *properties = @{ // properties for the HTML data
			(__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
			(__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html"
		};
		QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)[html dataUsingEncoding:NSUTF8StringEncoding], kUTTypeHTML, (__bridge CFDictionaryRef)properties);
	}
	return noErr;
}

void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail) {
	// Implement only if supported
}
