#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZipFile : NSObject
+ (instancetype)open:(NSString *)path;

/// Unzip file directly into memory.
/// @param filePath File path inside zip file.
- (NSData * _Nullable)unzipFile:(NSString *)filePath;

/// Unzip file to filesystem.
/// @param filePath File path inside zip file.
/// @param targetDir Directory in which to unzip the file.
- (void)unzipFile:(NSString *)filePath toDir:(NSString *)targetDir;
@end

NS_ASSUME_NONNULL_END
