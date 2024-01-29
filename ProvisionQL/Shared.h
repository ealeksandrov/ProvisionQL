#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Security/Security.h>

#import <NSBezierPath+IOS7RoundedRect.h>

#import "ZipFile.h"

static NSString * _Nonnull const kPluginBundleId = @"com.ealeksandrov.ProvisionQL";
static NSString * _Nonnull const kDataType_ipa               = @"com.apple.itunes.ipa";
static NSString * _Nonnull const kDataType_ios_provision     = @"com.apple.mobileprovision";
static NSString * _Nonnull const kDataType_ios_provision_old = @"com.apple.iphone.mobileprovision";
static NSString * _Nonnull const kDataType_osx_provision     = @"com.apple.provisionprofile";
static NSString * _Nonnull const kDataType_xcode_archive     = @"com.apple.xcode.archive";
static NSString * _Nonnull const kDataType_app_extension     = @"com.apple.application-and-system-extension";

// Init QuickLook Type
typedef NS_ENUM(NSUInteger, FileType) {
	FileTypeIPA = 1,
	FileTypeArchive,
	FileTypeExtension,
	FileTypeProvision,
};

typedef struct QuickLookMeta {
	NSString * _Nonnull UTI;
	NSURL * _Nonnull url;
	NSURL * _Nullable effectiveUrl; // if set, will point to the app inside of an archive

	FileType type;
	BOOL isOSX;
	ZipFile * _Nullable zipFile; // only set for zipped file types
} QuickLookInfo;

QuickLookInfo initQLInfo(_Nonnull CFStringRef contentTypeUTI, _Nonnull CFURLRef url);

// Plist
NSDictionary * _Nullable readPlistApp(QuickLookInfo meta);
NSDictionary * _Nullable readPlistProvision(QuickLookInfo meta);
NSDictionary * _Nullable readPlistItunes(QuickLookInfo meta);

// Other helper
typedef NS_ENUM(NSUInteger, ExpirationStatus) {
	ExpirationStatusExpired = 0,
	ExpirationStatusExpiring = 1,
	ExpirationStatusValid = 2,
};
ExpirationStatus expirationStatus(NSDate * _Nullable date);
NSDate * _Nullable dateOrNil(NSDate * _Nullable value);
NSArray * _Nullable arrayOrNil(NSArray * _Nullable value);

// App Icon
NSImage * _Nonnull roundCorners(NSImage * _Nonnull image);
NSImage * _Nonnull imageFromApp(QuickLookInfo meta, NSDictionary * _Nullable appPlist);
