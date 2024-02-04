#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

#import "Shared.h"

@interface NSImage (AppIcon)
- (NSImage * _Nonnull)withRoundCorners;
- (NSString * _Nonnull)asBase64;
- (void)downscale:(CGSize)maxSize;
@end


@interface AppIcon : NSObject
+ (instancetype _Nonnull)load:(QuickLookInfo)meta;
- (BOOL)canExtractImage;
- (NSImage * _Nonnull)extractImage:(NSDictionary * _Nullable)appPlist;
@end
