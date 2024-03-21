#import <Foundation/Foundation.h>
@class ZipEntry;

NS_ASSUME_NONNULL_BEGIN

@interface ZipFile : NSObject
+ (instancetype)open:(NSString *)path;
- (NSData * _Nullable)unzipFile:(NSString *)filePath isExactMatch:(BOOL)exact;
- (void)unzipFile:(NSString *)filePath toDir:(NSString *)targetDir;
- (NSArray<ZipEntry*> * _Nullable)filesMatching:(NSString * _Nonnull)path;
@end

NS_ASSUME_NONNULL_END
