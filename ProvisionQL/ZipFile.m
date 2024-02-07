#import "ZipFile.h"
#import "pinch.h"

@interface ZipFile()
@property (nonatomic, retain, readonly) NSString * pathToZipFile;
@property (nonatomic, retain, readonly, nullable) NSArray<ZipEntry*> *centralDirectory;
@end


@implementation ZipFile

+ (instancetype)open:(NSString *)path {
	return [[self alloc] initWithFile:path];
}

- (instancetype)initWithFile:(NSString *)path {
	self = [super init];
	if (self) {
		_pathToZipFile = path;
		_centralDirectory = listZip(path);
	}
	return self;
}


// MARK: - public methods

- (NSArray<ZipEntry*> * _Nullable)filesMatching:(NSString * _Nonnull)path {
	if (self.centralDirectory) {
		NSPredicate *pred = [NSPredicate predicateWithFormat:@"filepath LIKE %@", path];
		return [self.centralDirectory filteredArrayUsingPredicate:pred];
	}
	return nil;
}

/// Unzip file directly into memory.
/// @param filePath File path inside zip file.
- (NSData * _Nullable)unzipFile:(NSString *)filePath {
	if (self.centralDirectory) {
		ZipEntry *matchingFile = [self.centralDirectory zipEntryWithPath:filePath];
		if (!matchingFile) {
#ifdef DEBUG
			NSLog(@"[unzip] cant find '%@'", filePath);
#endif
			// There is a dir listing but no matching file.
			// This means there wont be anything to extract.
			// Not even a sys-call can help here.
			return nil;
		}
#ifdef DEBUG
		NSLog(@"[unzip] %@", matchingFile.filepath);
#endif
		NSData *data = unzipFileEntry(self.pathToZipFile, matchingFile);
		if (data) {
			return data;
		}
	}
	// fallback to sys unzip
	return [self sysUnzipFile:filePath];
}

/// Unzip file to filesystem.
/// @param filePath File path inside zip file.
/// @param targetDir Directory in which to unzip the file.
- (void)unzipFile:(NSString *)filePath toDir:(NSString *)targetDir {
	if (self.centralDirectory) {
		NSData *data = [self unzipFile:filePath];
		if (data) {
			NSString *outputPath = [targetDir stringByAppendingPathComponent:[filePath lastPathComponent]];
#ifdef DEBUG
			NSLog(@"[unzip] write to %@", outputPath);
#endif
			[data writeToFile:outputPath atomically:NO];
			return;
		}
	}
	[self sysUnzipFile:filePath toDir:targetDir];
}


// MARK: - fallback to sys call

- (NSData * _Nullable)sysUnzipFile:(NSString *)filePath {
	NSTask *task = [NSTask new];
	[task setLaunchPath:@"/usr/bin/unzip"];
	[task setStandardOutput:[NSPipe pipe]];
	[task setArguments:@[@"-p", self.pathToZipFile, filePath, @"-x", @"*/*/*/*"]];
	[task launch];

#ifdef DEBUG
	NSLog(@"[sys-call] unzip %@", [[task arguments] componentsJoinedByString:@" "]);
#endif

	NSData *pipeData = [[[task standardOutput] fileHandleForReading] readDataToEndOfFile];
	[task waitUntilExit];
	if (pipeData.length == 0) {
		return nil;
	}
	return pipeData;
}

- (void)sysUnzipFile:(NSString *)filePath toDir:(NSString *)targetDir {
	NSTask *task = [NSTask new];
	[task setLaunchPath:@"/usr/bin/unzip"];
	[task setArguments:@[@"-u", @"-j", @"-d", targetDir, self.pathToZipFile, filePath, @"-x", @"*/*/*/*"]];
	[task launch];

#ifdef DEBUG
	NSLog(@"[sys-call] unzip %@", [[task arguments] componentsJoinedByString:@" "]);
#endif

	[task waitUntilExit];
}

@end
