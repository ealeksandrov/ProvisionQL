#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Entitlements : NSObject
@property (nonatomic, assign, readonly) BOOL hasError;
/// only set after calling @c applyFallbackIfNeeded:
@property (nonatomic, retain, readonly) NSString * _Nullable html;

+ (instancetype)withoutBinary;
+ (instancetype)withBinary:(NSString *)appBinaryPath;
- (instancetype)init UNAVAILABLE_ATTRIBUTE;

- (void)applyFallbackIfNeeded:(NSDictionary * _Nullable)fallbackEntitlementsPlist;
@end

NS_ASSUME_NONNULL_END
