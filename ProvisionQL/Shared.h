#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Security/Security.h>

#import <NSBezierPath+IOS7RoundedRect.h>

static NSString * const kPluginBundleId = @"com.ealeksandrov.ProvisionQL";
static NSString * const kDataType_ipa               = @"com.apple.itunes.ipa";
static NSString * const kDataType_ios_provision     = @"com.apple.mobileprovision";
static NSString * const kDataType_ios_provision_old = @"com.apple.iphone.mobileprovision";
static NSString * const kDataType_osx_provision     = @"com.apple.provisionprofile";
static NSString * const kDataType_xcode_archive     = @"com.apple.xcode.archive";
static NSString * const kDataType_app_extension     = @"com.apple.application-and-system-extension";

NSData *unzipFile(NSURL *url, NSString *filePath);
void unzipFileToDir(NSURL *url, NSString *filePath, NSString *targetDir);

NSImage *roundCorners(NSImage *image);
NSImage *imageFromApp(NSURL *URL, NSString *dataType, NSString *fileName);
NSString *mainIconNameForApp(NSDictionary *appPropertyList);
int expirationStatus(NSDate *date, NSCalendar *calendar);
