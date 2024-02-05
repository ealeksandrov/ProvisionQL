/*---------------------------------------------------------------------------
 
 Modified 2024 by relikd
 
 Based on original version:
 
 https://github.com/epatel/pinch-objc
 
 Copyright (c) 2011-2012 Edward Patel
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 ---------------------------------------------------------------------------*/

#import "pinch.h"
#import "ZipEntry.h"

#include <zlib.h>
#include <ctype.h>
#include <stdio.h>

typedef unsigned int uint32;
typedef unsigned short uint16;

// The headers, see http://en.wikipedia.org/wiki/ZIP_(file_format)#File_headers
// Note that here they will not be as tightly packed as defined in the file format,
// so the extraction is done with a macro below. 

typedef struct ZipRecordEnd {
	uint32 endOfCentralDirectorySignature;
	uint16 numberOfThisDisk;
	uint16 diskWhereCentralDirectoryStarts;
	uint16 numberOfCentralDirectoryRecordsOnThisDisk;
	uint16 totalNumberOfCentralDirectoryRecords;
	uint32 sizeOfCentralDirectory;
	uint32 offsetOfStartOfCentralDirectory;
	uint16 ZIPfileCommentLength;
} ZipRecordEnd;

typedef struct ZipRecordDir {
	uint32 centralDirectoryFileHeaderSignature;
	uint16 versionMadeBy;
	uint16 versionNeededToExtract;
	uint16 generalPurposeBitFlag;
	uint16 compressionMethod;
	uint16 fileLastModificationTime;
	uint16 fileLastModificationDate;
	uint32 CRC32;
	uint32 compressedSize;
	uint32 uncompressedSize;
	uint16 fileNameLength;
	uint16 extraFieldLength;
	uint16 fileCommentLength;
	uint16 diskNumberWhereFileStarts;
	uint16 internalFileAttributes;
	uint32 externalFileAttributes;
	uint32 relativeOffsetOfLocalFileHeader;
} ZipRecordDir;

typedef struct ZipFileHeader {
	uint32 localFileHeaderSignature;
	uint16 versionNeededToExtract;
	uint16 generalPurposeBitFlag;
	uint16 compressionMethod;
	uint16 fileLastModificationTime;
	uint16 fileLastModificationDate;
	uint32 CRC32;
	uint32 compressedSize;
	uint32 uncompressedSize;
	uint16 fileNameLength;
	uint16 extraFieldLength;
} ZipFileHeader;


BOOL isValid(unsigned char *ptr, int lenUncompressed, uint32 expectedCrc32) {
	unsigned long crc = crc32(0L, Z_NULL, 0);
	crc = crc32(crc, (const unsigned char*)ptr, lenUncompressed);
	BOOL valid = crc == expectedCrc32;
	if (!valid) {
		NSLog(@"WARN: CRC check failed.");
	}
	return valid;
}


// MARK: - Unzip data

NSData *unzipFileEntry(NSString *path, ZipEntry *entry) {
	NSData *inputData = nil;
	NSData *outputData = nil;
	int length = sizeof(ZipFileHeader) + entry.sizeCompressed + entry.filenameLength + entry.extraFieldLength;

	// Download '16' extra bytes as I've seen that extraFieldLength sometimes differs
	// from the centralDirectory and the fileEntry header...
	NSFileHandle *fp = [NSFileHandle fileHandleForReadingAtPath:path];
	@try {
		[fp seekToFileOffset:entry.offset];
		inputData = [fp readDataOfLength:length + 16];
	} @finally {
		[fp closeFile];
	}

	if (!inputData)
		return nil;

	//	NSData *data = [NSData new];
	unsigned char *cptr = (unsigned char*)[inputData bytes];

	ZipFileHeader file_record;
	int idx = 0;

	// Extract fields with a macro, if we would need to swap byteorder this would be the place
#define GETFIELD( _field ) \
memcpy(&file_record._field, &cptr[idx], sizeof(file_record._field)); \
idx += sizeof(file_record._field)
	GETFIELD( localFileHeaderSignature );
	GETFIELD( versionNeededToExtract );
	GETFIELD( generalPurposeBitFlag );
	GETFIELD( compressionMethod );
	GETFIELD( fileLastModificationTime );
	GETFIELD( fileLastModificationDate );
	GETFIELD( CRC32 );
	GETFIELD( compressedSize );
	GETFIELD( uncompressedSize );
	GETFIELD( fileNameLength );
	GETFIELD( extraFieldLength );
#undef GETFIELD

	if (entry.method == Z_DEFLATED) {
		z_stream zstream;
		int ret;

		zstream.zalloc = Z_NULL;
		zstream.zfree = Z_NULL;
		zstream.opaque = Z_NULL;
		zstream.avail_in = 0;
		zstream.next_in = Z_NULL;

		ret = inflateInit2(&zstream, -MAX_WBITS);
		if (ret != Z_OK)
			return nil;

		zstream.avail_in = entry.sizeCompressed;
		zstream.next_in = &cptr[idx + file_record.fileNameLength + file_record.extraFieldLength];

		unsigned char *ptr = malloc(entry.sizeUncompressed);

		zstream.avail_out = entry.sizeUncompressed;
		zstream.next_out = ptr;

		ret = inflate(&zstream, Z_SYNC_FLUSH);

		if (isValid(ptr, entry.sizeUncompressed, file_record.CRC32)) {
			outputData = [NSData dataWithBytes:ptr length:entry.sizeUncompressed];
		}

		free(ptr);

		// TODO: handle inflate errors
		assert(ret != Z_STREAM_ERROR);  /* state not clobbered */
		switch (ret) {
			case Z_NEED_DICT:
				ret = Z_DATA_ERROR;     /* and fall through */
			case Z_DATA_ERROR:
			case Z_MEM_ERROR:
				//inflateEnd(&zstream);
				//return;
				;
		}

		inflateEnd(&zstream);

	} else if (entry.method == 0) {

		unsigned char *ptr = &cptr[idx + file_record.fileNameLength + file_record.extraFieldLength];

		if (isValid(ptr, entry.sizeUncompressed, file_record.CRC32)) {
			outputData = [NSData dataWithBytes:ptr length:entry.sizeUncompressed];
		}

	} else {
		NSLog(@"WARN: unimplemented compression method: %d", entry.method);
	}

	return outputData;
}


// MARK: - List files

/// Find signature for central directory.
ZipRecordEnd findCentralDirectory(NSFileHandle *fp) {
	unsigned long long eof = [fp seekToEndOfFile];
	[fp seekToFileOffset:MAX(0, eof - 4096)];
	NSData *data = [fp readDataToEndOfFile];

	char centralDirSignature[4] = {
		0x50, 0x4b, 0x05, 0x06
	};

	const char *cptr = (const char*)[data bytes];
	long len = [data length];
	char *found = NULL;

	do {
		char *fptr = memchr(cptr, 0x50, len);

		if (!fptr) // done searching
			break;

		// Use the last found directory
		if (!memcmp(centralDirSignature, fptr, 4))
			found = fptr;

		len = len - (fptr - cptr) - 1;
		cptr = fptr + 1;
	} while (1);

	ZipRecordEnd end_record = {};
	if (!found) {
		NSLog(@"WARN: no zip end-header found!");
		return end_record;
	}

	int idx = 0;
	// Extract fields with a macro, if we would need to swap byteorder this would be the place
#define GETFIELD( _field ) \
memcpy(&end_record._field, &found[idx], sizeof(end_record._field)); \
idx += sizeof(end_record._field)
	GETFIELD( endOfCentralDirectorySignature );
	GETFIELD( numberOfThisDisk );
	GETFIELD( diskWhereCentralDirectoryStarts );
	GETFIELD( numberOfCentralDirectoryRecordsOnThisDisk );
	GETFIELD( totalNumberOfCentralDirectoryRecords );
	GETFIELD( sizeOfCentralDirectory );
	GETFIELD( offsetOfStartOfCentralDirectory );
	GETFIELD( ZIPfileCommentLength );
#undef GETFIELD
	return end_record;
}

/// List all files and folders of of the central directory.
NSArray<ZipEntry*> *listCentralDirectory(NSFileHandle *fp, ZipRecordEnd end_record) {
	[fp seekToFileOffset:end_record.offsetOfStartOfCentralDirectory];
	NSData *data = [fp readDataOfLength:end_record.sizeOfCentralDirectory];

	const char *cptr = (const char*)[data bytes];
	long len = [data length];

	// 46 ?!? That's the record length up to the filename see
	// http://en.wikipedia.org/wiki/ZIP_(file_format)#File_headers

	NSMutableArray *array = [NSMutableArray array];
	while (len > 46) {
		ZipRecordDir dir_record;
		int idx = 0;

		// Extract fields with a macro, if we would need to swap byteorder this would be the place
#define GETFIELD( _field ) \
memcpy(&dir_record._field, &cptr[idx], sizeof(dir_record._field)); \
idx += sizeof(dir_record._field)
		GETFIELD( centralDirectoryFileHeaderSignature );
		GETFIELD( versionMadeBy );
		GETFIELD( versionNeededToExtract );
		GETFIELD( generalPurposeBitFlag );
		GETFIELD( compressionMethod );
		GETFIELD( fileLastModificationTime );
		GETFIELD( fileLastModificationDate );
		GETFIELD( CRC32 );
		GETFIELD( compressedSize );
		GETFIELD( uncompressedSize );
		GETFIELD( fileNameLength );
		GETFIELD( extraFieldLength );
		GETFIELD( fileCommentLength );
		GETFIELD( diskNumberWhereFileStarts );
		GETFIELD( internalFileAttributes );
		GETFIELD( externalFileAttributes );
		GETFIELD( relativeOffsetOfLocalFileHeader );
#undef GETFIELD

		NSString *filename = [[NSString alloc] initWithBytes:cptr + 46
													  length:dir_record.fileNameLength
													encoding:NSUTF8StringEncoding];
		ZipEntry *entry = [[ZipEntry alloc] init];
		entry.url = @""; //url
		entry.filepath = filename;
		entry.method = dir_record.compressionMethod;
		entry.sizeCompressed = dir_record.compressedSize;
		entry.sizeUncompressed = dir_record.uncompressedSize;
		entry.offset = dir_record.relativeOffsetOfLocalFileHeader;
		entry.filenameLength = dir_record.fileNameLength;
		entry.extraFieldLength = dir_record.extraFieldLength;
		[array addObject:entry];

		len -= 46 + dir_record.fileNameLength + dir_record.extraFieldLength + dir_record.fileCommentLength;
		cptr += 46 + dir_record.fileNameLength + dir_record.extraFieldLength + dir_record.fileCommentLength;
	}
	return array;
}

NSArray<ZipEntry*> *listZip(NSString *path) {
	NSFileHandle *fp = [NSFileHandle fileHandleForReadingAtPath:path];
	@try {
		ZipRecordEnd end_record = findCentralDirectory(fp);
		if (end_record.sizeOfCentralDirectory == 0) {
			return nil;
		}
		return listCentralDirectory(fp, end_record);
	} @finally {
		[fp closeFile];
	}
	return nil;
}
