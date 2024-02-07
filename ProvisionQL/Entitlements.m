#import "Entitlements.h"

void recursiveKeyValue(NSUInteger level, NSString *key, id value, NSMutableString *output);


@interface Entitlements()
@property (nonatomic, copy, readonly) NSString * _Nonnull binaryPath;
/// It is either @c plist or @c codeSignErrors not both.
@property (nonatomic, retain, readonly) NSDictionary * _Nullable plist;
/// It is either @c plist or @c codeSignErrors not both.
@property (nonatomic, retain, readonly) NSString * _Nullable codeSignError;
@end


@implementation Entitlements

/// Use provision plist data without running @c codesign or
+ (instancetype)withoutBinary {
	return [[self alloc] init];
}

/// First, try to extract real entitlements by running @c SecCode module in-memory.
/// If that fails, fallback to running @c codesign via system call.
+ (instancetype)withBinary:(NSString * _Nonnull)appBinaryPath {
	return [[self alloc] initWithBinaryPath:appBinaryPath];
}

- (instancetype)initWithBinaryPath:(NSString * _Nonnull)path {
	self = [super init];
	if (self) {
		if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
			NSLog(@"WARN: provided binary '%@' does not exist (unzip error?).", [path lastPathComponent]);
			return self;
		}
		_binaryPath = path;
		_plist = [self getSecCodeEntitlements];
		if (!_plist) {
			_plist = [self sysCallCodeSign]; // fallback to system call
		}
	}
	return self;
}

// MARK: - public methods

/// Provided provision plist is only used if @c SecCode and @c CodeSign failed.
- (void)applyFallbackIfNeeded:(NSDictionary * _Nullable)fallbackEntitlementsPlist {
	// checking for !error ensures that codesign gets precedence.
	// show error before falling back to provision based entitlements.
	if (!_plist && !_codeSignError) {
		// read the entitlements from the provisioning profile instead
		if ([fallbackEntitlementsPlist isKindOfClass:[NSDictionary class]]) {
#ifdef DEBUG
			NSLog(@"[entitlements] fallback to provision plist entitlements");
#endif
			_plist = fallbackEntitlementsPlist;
		}
	}
	_html = [self format:_plist];
	_plist = nil; // free memory
	_codeSignError = nil;
}

/// Print formatted plist in a @c \<pre> tag
- (NSString * _Nullable)format:(NSDictionary *)plist {
	if (plist) {
		NSMutableString *output = [NSMutableString string];
		recursiveKeyValue(0, nil, plist, output);
		return [NSString stringWithFormat:@"<pre>%@</pre>", output];
	}
	return _codeSignError; // may be nil
}


// MARK: - SecCode in-memory reader

/// use in-memory @c SecCode for entitlement extraction
- (NSDictionary *)getSecCodeEntitlements {
	NSURL *url = [NSURL fileURLWithPath:_binaryPath];
	NSDictionary *plist = nil;
	SecStaticCodeRef codeRef;
	SecStaticCodeCreateWithPath((__bridge CFURLRef)url, kSecCSDefaultFlags, &codeRef);
	if (codeRef) {
		CFDictionaryRef requirementInfo;
		SecCodeCopySigningInformation(codeRef, kSecCSRequirementInformation, &requirementInfo);
		if (requirementInfo) {
#ifdef DEBUG
			NSLog(@"[entitlements] read SecCode 'entitlements-dict' key");
#endif
			CFDictionaryRef dict = CFDictionaryGetValue(requirementInfo, kSecCodeInfoEntitlementsDict);
			// if 'entitlements-dict' key exists, use that one
			if (dict) {
				plist = (__bridge NSDictionary *)dict;
			}
			// else, fallback to parse data from 'entitlements' key
			if (!plist) {
#ifdef DEBUG
				NSLog(@"[entitlements] read SecCode 'entitlements' key");
#endif
				NSData *data = (__bridge NSData*)CFDictionaryGetValue(requirementInfo, kSecCodeInfoEntitlements);
				if (data) {
					NSData *header = [data subdataWithRange:NSMakeRange(0, 8)];
					const char *cptr = (const char*)[header bytes];

					// expected magic header number. Currently no support for other formats.
					if (memcmp("\xFA\xDE\x71\x71", cptr, 4) == 0) {
						// big endian, so no memcpy for us :(
						uint32_t size = ((uint8_t)cptr[4] << 24) | ((uint8_t)cptr[5] << 16) | ((uint8_t)cptr[6] << 8) | (uint8_t)cptr[7];
						if (size == data.length) {
							data = [data subdataWithRange:NSMakeRange(8, data.length - 8)];
						} else {
							NSLog(@"[entitlements] unpack error for FADE7171 size %lu != %u", data.length, size);
						}
					} else {
						NSLog(@"[entitlements] unsupported embedded plist format: %@", header);
					}
					plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
				}
			}
			CFRelease(requirementInfo);
		}
		CFRelease(codeRef);
	}
	return plist;
}


// MARK: - fallback to sys call

/// run:  @c codesign -d <AppBinary> --entitlements - --xml
- (NSDictionary *)sysCallCodeSign {
	NSTask *codesignTask = [NSTask new];
	[codesignTask setLaunchPath:@"/usr/bin/codesign"];
	[codesignTask setStandardOutput:[NSPipe pipe]];
	[codesignTask setStandardError:[NSPipe pipe]];
	if (@available(macOS 11, *)) {
		[codesignTask setArguments:@[@"-d", _binaryPath, @"--entitlements", @"-", @"--xml"]];
	} else {
		[codesignTask setArguments:@[@"-d", _binaryPath, @"--entitlements", @":-"]];
	}
	[codesignTask launch];

#ifdef DEBUG
	NSLog(@"[sys-call] codesign %@", [[codesignTask arguments] componentsJoinedByString:@" "]);
#endif

	NSData *outputData = [[[codesignTask standardOutput] fileHandleForReading] readDataToEndOfFile];
	NSData *errorData = [[[codesignTask standardError] fileHandleForReading] readDataToEndOfFile];
	[codesignTask waitUntilExit];

	if (outputData) {
		NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:outputData options:0 format:NULL error:NULL];
		if (plist) {
			return plist;
		}
		// errorData = outputData; // not sure if necessary
	}

	NSString *output = [[NSString alloc] initWithData:errorData ?: outputData encoding:NSUTF8StringEncoding];
	if ([output hasPrefix:@"Executable="]) {
		// remove first line with long temporary path to the executable
		NSArray *allLines = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		_codeSignError = [[allLines subarrayWithRange:NSMakeRange(1, allLines.count - 1)] componentsJoinedByString:@"<br />"];
	} else {
		_codeSignError = output;
	}
	_hasError = YES;
	return nil;
}

@end


// MARK: - Plist formatter

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
