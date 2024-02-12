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

#import <Foundation/Foundation.h>


@interface ZipEntry : NSObject {
    NSString *url;
    NSString *filepath;
    int offset;
    int method;
    int sizeCompressed;
    int sizeUncompressed;
    unsigned int crc32;
    int filenameLength;
    int extraFieldLength;
    NSData *data;
}

@property (nonatomic, retain) NSString *url;
@property (nonatomic, retain) NSString *filepath;
@property (nonatomic, assign) int offset;
@property (nonatomic, assign) int method;
@property (nonatomic, assign) int sizeCompressed;
@property (nonatomic, assign) int sizeUncompressed;
@property (nonatomic, assign) unsigned int crc32;
@property (nonatomic, assign) int filenameLength;
@property (nonatomic, assign) int extraFieldLength;
@property (nonatomic, retain) NSData *data;

@end

@interface NSArray (ZipEntry)

- (ZipEntry*)zipEntryWithPath:(NSString*)path;

@end
