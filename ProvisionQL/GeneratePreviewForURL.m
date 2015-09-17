#import "Shared.h"

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

/* -----------------------------------------------------------------------------
 Generate a preview for file
 
 This function's job is to create preview for designated file
 ----------------------------------------------------------------------------- */

void displayKeyAndValue(NSUInteger level, NSString *key, id value, NSMutableString *output) {
	int indent = (int)(level * 4);
	
	if ([value isKindOfClass:[NSDictionary class]]) {
		if (key) {
			[output appendFormat:@"%*s%@ = {\n", indent, "", key];
		} else {
			[output appendFormat:@"%*s{\n", indent, ""];
		}
		NSDictionary *dictionary = (NSDictionary *)value;
		NSArray *keys = [[dictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];
		for (NSString *key in keys) {
			displayKeyAndValue(level + 1, key, [dictionary valueForKey:key], output);
		}
		[output appendFormat:@"%*s}\n", indent, ""];
	} else if ([value isKindOfClass:[NSArray class]]) {
		[output appendFormat:@"%*s%@ = (\n", indent, "", key];
		NSArray *array = (NSArray *)value;
		for (id value in array) {
			displayKeyAndValue(level + 1, nil, value, output);
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

NSString *expirationStringForDateInCalendar(NSDate *date, NSCalendar *calendar) {
	NSString *result = nil;
	
	if (date) {
		NSDateComponents *dateComponents = [calendar components:NSDayCalendarUnit fromDate:[NSDate date] toDate:date options:0];
		if (dateComponents.day == 0) {
			result = @"<span>Expires today</span>";
		} else if (dateComponents.day < 0) {
			result = [NSString stringWithFormat:@"<span>Expired %zd day%s ago</span>", -dateComponents.day, (dateComponents.day == -1 ? "" : "s")];
		} else if (dateComponents.day < 30) {
			result = [NSString stringWithFormat:@"<span>Expires in %zd day%s</span>", dateComponents.day, (dateComponents.day == 1 ? "" : "s")];
		} else {
			result = [NSString stringWithFormat:@"Expires in %zd days", dateComponents.day];
		}
	}
    
	return result;
}

NSString *formattedStringForCertificates(NSArray *value) {
    static NSString *const devCertSummaryKey = @"summary";
    static NSString *const devCertInvalidityDateKey = @"invalidity";
    
    NSMutableArray *certificateDetails = [NSMutableArray array];
    NSArray *array = (NSArray *)value;
    for (NSData *data in array) {
        SecCertificateRef certificateRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)data);
        if (certificateRef) {
            CFStringRef summaryRef = SecCertificateCopySubjectSummary(certificateRef);
            NSString *summary = (NSString *)CFBridgingRelease(summaryRef);
            if (summary) {
                NSMutableDictionary *detailsDict = [NSMutableDictionary dictionaryWithObject:summary forKey:devCertSummaryKey];
                
                CFErrorRef error;
                CFDictionaryRef valuesDict = SecCertificateCopyValues(certificateRef, (__bridge CFArrayRef)@[(__bridge id)kSecOIDInvalidityDate], &error);
                if (valuesDict) {
                    CFDictionaryRef invalidityDateDictionaryRef = CFDictionaryGetValue(valuesDict, kSecOIDInvalidityDate);
                    if (invalidityDateDictionaryRef) {
                        CFTypeRef invalidityRef = CFDictionaryGetValue(invalidityDateDictionaryRef, kSecPropertyKeyValue);
                        CFRetain(invalidityRef);
                        
                        // NOTE: the invalidity date type of kSecPropertyTypeDate is documented as a CFStringRef in the "Certificate, Key, and Trust Services Reference".
                        // In reality, it's a __NSTaggedDate (presumably a tagged pointer representing an NSDate.) But to sure, we'll check:
                        id invalidity = CFBridgingRelease(invalidityRef);
                        if (invalidity) {
                            if ([invalidity isKindOfClass:[NSDate class]]) {
                                // use the date directly
                                [detailsDict setObject:invalidity forKey:devCertInvalidityDateKey];
                            } else {
                                // parse the date from a string
                                NSString *string = [invalidity description];
                                NSDateFormatter *invalidityDateFormatter = [NSDateFormatter new];
                                [invalidityDateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss Z"];
                                NSDate *invalidityDate = [invalidityDateFormatter dateFromString:string];
                                if (invalidityDate) {
                                    [detailsDict setObject:invalidityDate forKey:devCertInvalidityDateKey];
                                }
                            }
                        } else {
                            NSLog(@"No invalidity date in '%@' certificate, dictionary = %@", summary, invalidityDateDictionaryRef);
                        }
                    } else {
                        NSLog(@"No invalidity values in '%@' certificate, dictionary = %@", summary, valuesDict);
                    }
                    
                    CFRelease(valuesDict);
                } else {
                    NSLog(@"Could not get values in '%@' certificate, error = %@", summary, error);
                }
                
                [certificateDetails addObject:detailsDict];
            } else {
                NSLog(@"Could not get summary from certificate");
            }
            
            CFRelease(certificateRef);
        }
    }
    
    NSMutableString *certificates = [NSMutableString string];
    [certificates appendString:@"<table>\n"];
    
    NSArray *sortedCertificateDetails = [certificateDetails sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [((NSDictionary *)obj1)[devCertSummaryKey] compare:((NSDictionary *)obj2)[devCertSummaryKey]];
    }];
    
    for (NSDictionary *detailsDict in sortedCertificateDetails) {
        NSString *summary = detailsDict[devCertSummaryKey];
        NSDate *invalidityDate = detailsDict[devCertInvalidityDateKey];
        NSString *expiration = expirationStringForDateInCalendar(invalidityDate, [NSCalendar currentCalendar]);
        if (! expiration) {
            expiration = @"<span class='warning'>No invalidity date in certificate</span>";
        }
        [certificates appendFormat:@"<tr><td>%@</td><td>%@</td></tr>\n", summary, expiration];
    }
    [certificates appendString:@"</table>\n"];
    
    return [certificates copy];
}

NSDictionary *formattedDevicesData(NSArray *value) {
    
#if !SIGNED_CODE
    // get the iOS devices that Xcode has seen, which only works if the plug-in is not running in a sandbox
    NSUserDefaults *xcodeDefaults = [NSUserDefaults new];
    [xcodeDefaults addSuiteNamed:@"com.apple.dt.XCode"];
    NSArray *savedDevices = [xcodeDefaults objectForKey:@"DVTSavediPhoneDevices"];
#endif
    
    NSArray *array = (NSArray *)value;
    NSArray *sortedArray = [array sortedArrayUsingSelector:@selector(compare:)];
    
    NSString *currentPrefix = nil;
    NSMutableString *devices = [NSMutableString string];
    [devices appendString:@"<table>\n"];

#if !SIGNED_CODE
    [devices appendString:@"<tr><th></th><th>UDID</th><th>Device</th><th>iOS</th></tr>\n"];
#else
    [devices appendString:@"<tr><th></th><th>UDID</th></tr>\n"];
#endif

    for (NSString *device in sortedArray) {
        // compute the prefix for the first column of the table
        NSString *displayPrefix = @"";
        NSString *devicePrefix = [device substringToIndex:1];
        if (! [currentPrefix isEqualToString:devicePrefix]) {
            currentPrefix = devicePrefix;
            displayPrefix = [NSString stringWithFormat:@"%@ ➞ ", devicePrefix];
        }
        
#if !SIGNED_CODE
        // check if Xcode has seen the device
        NSString *deviceName = @"";
        NSString *deviceType = @"Unknown";
        NSString *deviceSoftwareVerson = @"";
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"deviceIdentifier = %@", device];
        NSArray *matchingDevices = [savedDevices filteredArrayUsingPredicate:predicate];
        if ([matchingDevices count] > 0) {
            id matchingDevice = [matchingDevices objectAtIndex:0];
            if ([matchingDevice isKindOfClass:[NSDictionary class]]) {
                NSDictionary *matchingDeviceDictionary = (NSDictionary *)matchingDevice;
                deviceName = [matchingDeviceDictionary objectForKey:@"deviceName"];
                deviceType = [matchingDeviceDictionary objectForKey:@"deviceType"];
                deviceSoftwareVerson = [matchingDeviceDictionary objectForKey:@"productVersion"];
            }
        }
        
        NSString *span = ([deviceName length]) ? @"span" : @"i";
        [devices appendFormat:@"<tr><td>%@</td><td>%@</td><td>%@ <%@ class=\"deviceType\">%@</%@></td><td>%@</td></tr>\n", displayPrefix, device, deviceName, span, deviceType, span, deviceSoftwareVerson];
#else
        [devices appendFormat:@"<tr><td>%@</td><td>%@</td></tr>\n", displayPrefix, device];
#endif
    }
    [devices appendString:@"</table>\n"];
    
    return @{@"ProvisionedDevicesFormatted" : [devices copy], @"ProvisionedDevicesCount" : [NSString stringWithFormat:@"%zd Device%s", [array count], ([array count] == 1 ? "" : "s")]};
}

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options) {
    @autoreleasepool {
        // create temp directory
		NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString* tempDirFolder = [NSTemporaryDirectory() stringByAppendingPathComponent:kPluginBundleId];
        NSString* currentTempDirFolder = [tempDirFolder stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
        [fileManager createDirectoryAtPath:currentTempDirFolder withIntermediateDirectories:YES attributes:nil error:nil];
		
        NSURL *URL = (__bridge NSURL *)url;
        NSString *dataType = (__bridge NSString *)contentTypeUTI;
        NSData *provisionData = nil;
        NSData *appPlist = nil;
        NSImage *appIcon = nil;
        
        if([dataType isEqualToString:kDataType_app]) {
            // get the embedded provisioning & plist for the iOS app
			provisionData = [NSData dataWithContentsOfURL:[URL URLByAppendingPathComponent:@"embedded.mobileprovision"]];
            appPlist = [NSData dataWithContentsOfURL:[URL URLByAppendingPathComponent:@"Info.plist"]];

        } else if([dataType isEqualToString:kDataType_ipa]) {
            // get the embedded provisioning & plist from an app archive using: unzip -u -j -d <currentTempDirFolder> <URL> <files to unzip>
            NSTask *unzipTask = [NSTask new];
			[unzipTask setLaunchPath:@"/usr/bin/unzip"];
			[unzipTask setStandardOutput:[NSPipe pipe]];
			[unzipTask setArguments:@[@"-u", @"-j", @"-d", currentTempDirFolder, [URL path], @"Payload/*.app/embedded.mobileprovision", @"Payload/*.app/Info.plist"]];
			[unzipTask launch];
			[unzipTask waitUntilExit];
            
            NSString *provisionPath = [currentTempDirFolder stringByAppendingPathComponent:@"embedded.mobileprovision"];
			provisionData = [NSData dataWithContentsOfFile:provisionPath];
            NSString *plistPath = [currentTempDirFolder stringByAppendingPathComponent:@"Info.plist"];
			appPlist = [NSData dataWithContentsOfFile:plistPath];
            
            [fileManager removeItemAtPath:tempDirFolder error:nil];
        } else {
            // use provisioning directly
            provisionData = [NSData dataWithContentsOfURL:URL];
        }
        
        NSMutableDictionary *synthesizedInfo = [NSMutableDictionary dictionary];
        NSURL *htmlURL = [[NSBundle bundleWithIdentifier:kPluginBundleId] URLForResource:@"template" withExtension:@"html"];
        NSMutableString *html = [NSMutableString stringWithContentsOfURL:htmlURL encoding:NSUTF8StringEncoding error:NULL];
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
        NSCalendar *calendar = [NSCalendar currentCalendar];
        id value = nil;
        NSString *synthesizedValue = nil;
        
        if (!provisionData) {
			NSLog(@"No provisionData for %@", URL);
            
            if([dataType isEqualToString:kDataType_ipa] || [dataType isEqualToString:kDataType_app]) {
                [synthesizedInfo setObject:@"hiddenDiv" forKey:@"ProvisionInfo"];
            } else {
                return noErr;
            }
		} else {
            [synthesizedInfo setObject:@"" forKey:@"ProvisionInfo"];
        }
        
        if([dataType isEqualToString:kDataType_ipa] || [dataType isEqualToString:kDataType_app]) {
            NSDictionary *appPropertyList = [NSPropertyListSerialization propertyListWithData:appPlist options:0 format:NULL error:NULL];
            
            NSString *bundleName = [appPropertyList objectForKey:@"CFBundleDisplayName"];
            if(!bundleName) {
                bundleName = [appPropertyList objectForKey:@"CFBundleName"];
            }
            [synthesizedInfo setObject:bundleName forKey:@"CFBundleName"];
            [synthesizedInfo setObject:[appPropertyList objectForKey:@"CFBundleIdentifier"] forKey:@"CFBundleIdentifier"];
            [synthesizedInfo setObject:[appPropertyList objectForKey:@"CFBundleShortVersionString"] forKey:@"CFBundleShortVersionString"];
            [synthesizedInfo setObject:[appPropertyList objectForKey:@"CFBundleVersion"] forKey:@"CFBundleVersion"];
            
            NSString *iconName = mainIconNameForApp(appPropertyList);
            appIcon = imageFromApp(URL, dataType, iconName);
            
            NSMutableArray *platforms = [NSMutableArray array];
            for (NSNumber *number in [appPropertyList objectForKey:@"UIDeviceFamily"]) {
                if([number intValue] == 1) {
                    [platforms addObject:@"iPhone"];
                } else if([number intValue] == 2) {
                    [platforms addObject:@"iPad"];
                }
            }
            [synthesizedInfo setObject:[platforms componentsJoinedByString:@", "] forKey:@"UIDeviceFamily"];
            
            if(!appIcon) {
                NSURL *iconURL = [[NSBundle bundleWithIdentifier:kPluginBundleId] URLForResource:@"defaultIcon" withExtension:@"png"];
                appIcon = [[NSImage alloc] initWithContentsOfURL:iconURL];
            }
            appIcon = roundCorners(appIcon);
            
            NSData *imageData = [appIcon TIFFRepresentation];
            NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
            imageData = [imageRep representationUsingType:NSPNGFileType properties:nil];
            NSString *base64 = [imageData base64EncodedStringWithOptions:0];
            [synthesizedInfo setObject:base64 forKey:@"AppIcon"];
            [synthesizedInfo setObject:@"" forKey:@"AppInfo"];
            [synthesizedInfo setObject:@"hiddenDiv" forKey:@"ProvisionAsSubheader"];
        } else {
            [synthesizedInfo setObject:@"hiddenDiv" forKey:@"AppInfo"];
            [synthesizedInfo setObject:@"" forKey:@"ProvisionAsSubheader"];
        }
        
        CMSDecoderRef decoder = NULL;
        CMSDecoderCreate(&decoder);
        CMSDecoderUpdateMessage(decoder, provisionData.bytes, provisionData.length);
        CMSDecoderFinalizeMessage(decoder);
        CFDataRef dataRef = NULL;
        CMSDecoderCopyContent(decoder, &dataRef);
        NSData *data = (NSData *)CFBridgingRelease(dataRef);
        CFRelease(decoder);
        
        if ((!data && !([dataType isEqualToString:kDataType_ipa] || [dataType isEqualToString:kDataType_app])) || QLPreviewRequestIsCancelled(preview)) {
            return noErr;
        }
        
        if(data) {
            // use all keys and values in the property list to generate replacement tokens and values
            NSDictionary *propertyList = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
            for (NSString *key in [propertyList allKeys]) {
                NSString *replacementValue = [[propertyList valueForKey:key] description];
                NSString *replacementToken = [NSString stringWithFormat:@"__%@__", key];
                [html replaceOccurrencesOfString:replacementToken withString:replacementValue options:0 range:NSMakeRange(0, [html length])];
            }
            
            // synthesize other replacement tokens and values
            value = [propertyList objectForKey:@"CreationDate"];
            if ([value isKindOfClass:[NSDate class]]) {
                NSDate *date = (NSDate *)value;
                synthesizedValue = [dateFormatter stringFromDate:date];
                [synthesizedInfo setObject:synthesizedValue forKey:@"CreationDateFormatted"];
                
                NSDateComponents *dateComponents = [calendar components:NSDayCalendarUnit fromDate:date toDate:[NSDate date] options:0];
                if (dateComponents.day == 0) {
                    synthesizedValue = @"Created today";
                } else {
                    synthesizedValue = [NSString stringWithFormat:@"Created %zd day%s ago", dateComponents.day, (dateComponents.day == 1 ? "" : "s")];
                }
                [synthesizedInfo setObject:synthesizedValue forKey:@"CreationSummary"];
            }
            
            value = [propertyList objectForKey:@"ExpirationDate"];
            if ([value isKindOfClass:[NSDate class]]) {
                NSDate *date = (NSDate *)value;
                synthesizedValue = [dateFormatter stringFromDate:date];
                [synthesizedInfo setObject:synthesizedValue forKey:@"ExpirationDateFormatted"];
                
                synthesizedValue = expirationStringForDateInCalendar(date, calendar);
                [synthesizedInfo setObject:synthesizedValue forKey:@"ExpirationSummary"];
                
                int expStatus = expirationStatus(value,calendar);
                if(expStatus == 0) {
                    synthesizedValue = @"expired";
                } else if(expStatus == 1) {
                    synthesizedValue = @"expiring";
                } else {
                    synthesizedValue = @"valid";
                }
                [synthesizedInfo setObject:synthesizedValue forKey:@"ExpStatus"];
            }
            
            value = [propertyList objectForKey:@"TeamIdentifier"];
            if ([value isKindOfClass:[NSArray class]]) {
                NSArray *array = (NSArray *)value;
                synthesizedValue = [array componentsJoinedByString:@", "];
                [synthesizedInfo setObject:synthesizedValue forKey:@"TeamIds"];
            }
            
            value = [propertyList objectForKey:@"Entitlements"];
            if ([value isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dictionary = (NSDictionary *)value;
                NSMutableString *dictionaryFormatted = [NSMutableString string];
                displayKeyAndValue(0, nil, dictionary, dictionaryFormatted);
                synthesizedValue = [NSString stringWithFormat:@"<pre>%@</pre>", dictionaryFormatted];
                
                [synthesizedInfo setObject:synthesizedValue forKey:@"EntitlementsFormatted"];
            } else {
                [synthesizedInfo setObject:@"No Entitlements" forKey:@"EntitlementsFormatted"];
            }
            
            value = [propertyList objectForKey:@"DeveloperCertificates"];
            if ([value isKindOfClass:[NSArray class]]) {
                [synthesizedInfo setObject:formattedStringForCertificates(value) forKey:@"DeveloperCertificatesFormatted"];
            } else {
                [synthesizedInfo setObject:@"No Developer Certificates" forKey:@"DeveloperCertificatesFormatted"];
            }
            
            value = [propertyList objectForKey:@"ProvisionedDevices"];
            if ([value isKindOfClass:[NSArray class]]) {
                [synthesizedInfo addEntriesFromDictionary:formattedDevicesData(value)];
            } else {
                [synthesizedInfo setObject:@"No Devices" forKey:@"ProvisionedDevicesFormatted"];
                [synthesizedInfo setObject:@"Distribution Profile" forKey:@"ProvisionedDevicesCount"];
            }
            
            {
                NSString *profileString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                profileString = [profileString stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
                NSDictionary *htmlEntityReplacement = @{
                                                        @"\"": @"&quot;",
                                                        @"'": @"&apos;",
                                                        @"<": @"&lt;",
                                                        @">": @"&gt;",
                                                        };
                for (NSString *key in [htmlEntityReplacement allKeys]) {
                    NSString *replacement = [htmlEntityReplacement objectForKey:key];
                    profileString = [profileString stringByReplacingOccurrencesOfString:key withString:replacement];
                }
                synthesizedValue = [NSString stringWithFormat:@"<pre>%@</pre>", profileString];
                [synthesizedInfo setObject:synthesizedValue forKey:@"RawData"];
            }
            
            // older provisioning files don't include some key/value pairs
            value = [propertyList objectForKey:@"TeamName"];
            if (! value) {
                [synthesizedInfo setObject:@"<em>Team name not available</em>" forKey:@"TeamName"];
            }
            value = [propertyList objectForKey:@"TeamIdentifier"];
            if (! value) {
                [synthesizedInfo setObject:@"<em>Team ID not available</em>" forKey:@"TeamIds"];
            }
            value = [propertyList objectForKey:@"AppIDName"];
            if (! value) {
                [synthesizedInfo setObject:@"<em>App name not available</em>" forKey:@"AppIDName"];
            }
            
            // determine the profile type
            BOOL getTaskAllow = NO;
            value = [propertyList objectForKey:@"Entitlements"];
            if ([value isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dictionary = (NSDictionary *)value;
                getTaskAllow = [[dictionary valueForKey:@"get-task-allow"] boolValue];
            }
            
            BOOL hasDevices = NO;
            value = [propertyList objectForKey:@"ProvisionedDevices"];
            if ([value isKindOfClass:[NSArray class]]) {
                hasDevices = YES;
            }
            
            BOOL isEnterprise = [[propertyList objectForKey:@"ProvisionsAllDevices"] boolValue];
            
            if ([dataType isEqualToString:kDataType_osx_provision]) {
                [synthesizedInfo setObject:@"mac" forKey:@"Platform"];
                
                [synthesizedInfo setObject:@"Mac" forKey:@"ProfilePlatform"];
                if (hasDevices) {
                    [synthesizedInfo setObject:@"Development" forKey:@"ProfileType"];
                } else {
                    [synthesizedInfo setObject:@"Distribution (App Store)" forKey:@"ProfileType"];
                }
            } else {
                [synthesizedInfo setObject:@"ios" forKey:@"Platform"];
                
                [synthesizedInfo setObject:@"iOS" forKey:@"ProfilePlatform"];
                if (hasDevices) {
                    if (getTaskAllow) {
                        [synthesizedInfo setObject:@"Development" forKey:@"ProfileType"];
                    } else {
                        [synthesizedInfo setObject:@"Distribution (Ad Hoc)" forKey:@"ProfileType"];
                    }
                } else {
                    if (isEnterprise) {
                        [synthesizedInfo setObject:@"Enterprise" forKey:@"ProfileType"];
                    } else {
                        [synthesizedInfo setObject:@"Distribution (App Store)" forKey:@"ProfileType"];
                    }
                }
            }
        }
        
        {
            [synthesizedInfo setObject:[URL lastPathComponent] forKey:@"FileName"];
            
            if ([[URL pathExtension] isEqualToString:@"app"] || [[URL pathExtension] isEqualToString:@"appex"]) {
                // get the "file" information using the application package folder
                NSString *folderPath = [URL path];
                
                NSDictionary *folderAttributes = [fileManager attributesOfItemAtPath:folderPath error:NULL];
                if (folderAttributes) {
                    NSDate *folderModificationDate = [folderAttributes fileModificationDate];
                    
                    unsigned long long folderSize = 0;
                    NSArray *filesArray = [fileManager subpathsOfDirectoryAtPath:folderPath error:nil];
                    for (NSString *fileName in filesArray) {
                        NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:[folderPath stringByAppendingPathComponent:fileName] error:NULL];
                        if (fileAttributes)
                            folderSize += [fileAttributes fileSize];
                    }
                    
                    synthesizedValue = [NSString stringWithFormat:@"%@, Modified %@",
                                        [NSByteCountFormatter stringFromByteCount:folderSize countStyle:NSByteCountFormatterCountStyleFile],
                                        [dateFormatter stringFromDate:folderModificationDate]];
                    [synthesizedInfo setObject:synthesizedValue forKey:@"FileInfo"];
                } else {
                    [synthesizedInfo setObject:@"" forKey:@"FileInfo"];
                }
            } else {
                NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:[URL path] error:NULL];
                if (fileAttributes) {
                    NSDate *fileModificationDate = [fileAttributes fileModificationDate];
                    unsigned long long fileSize = [fileAttributes fileSize];
                    
                    synthesizedValue = [NSString stringWithFormat:@"%@, Modified %@",
                                        [NSByteCountFormatter stringFromByteCount:fileSize countStyle:NSByteCountFormatterCountStyleFile],
                                        [dateFormatter stringFromDate:fileModificationDate]];
                    [synthesizedInfo setObject:synthesizedValue forKey:@"FileInfo"];
                }
            }
        }
        
#ifdef DEBUG
        [synthesizedInfo setObject:@"(debug)" forKey:@"DEBUG"];
#else
        [synthesizedInfo setObject:@"" forKey:@"DEBUG"];
#endif
        
        {
            synthesizedValue = [[NSBundle bundleWithIdentifier:kPluginBundleId] objectForInfoDictionaryKey:@"CFBundleVersion"];
            [synthesizedInfo setObject:synthesizedValue forKey:@"BundleVersion"];
        }
        
        for (NSString *key in [synthesizedInfo allKeys]) {
            NSString *replacementValue = [synthesizedInfo objectForKey:key];
            NSString *replacementToken = [NSString stringWithFormat:@"__%@__", key];
            [html replaceOccurrencesOfString:replacementToken withString:replacementValue options:0 range:NSMakeRange(0, [html length])];
        }
        
        NSDictionary *properties = @{ // properties for the HTML data
                                     (__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
                                     (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html" };
        
        QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)[html dataUsingEncoding:NSUTF8StringEncoding], kUTTypeHTML, (__bridge CFDictionaryRef)properties);
	}
	
	return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {
    // Implement only if supported
}
