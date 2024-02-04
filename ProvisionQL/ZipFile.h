#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZipFile : NSObject
+ (instancetype)open:(NSString *)path;
- (NSData * _Nullable)unzipFile:(NSString *)filePath;
- (void)unzipFile:(NSString *)filePath toDir:(NSString *)targetDir;
@end

NS_ASSUME_NONNULL_END
