#import <Foundation/Foundation.h>

@class NSBundle, NSCache, NSMapTable, NSString;
@class CUINamedImage, CUIStructuredThemeStore;

@interface CUICatalog: NSObject {
    NSString * _assetStoreName;
    NSBundle * _bundle;
    unsigned int  _fileHasDisplayGamutInKeySpace;
    NSCache * _localObjectCache;
    NSCache * _lookupCache;
    NSCache * _negativeCache;
    unsigned short  _preferredLocalization;
    unsigned int  _purgeWhenFinished;
    unsigned int  _reserved;
    NSMapTable * _storageMapTable;
    unsigned long long  _storageRef;
    NSDictionary * _vibrantColorMatrixTints;
}

- (CUIStructuredThemeStore *)_themeStore;

+ (id)defaultUICatalogForBundle:(id)arg1;

- (id)initWithBytes:(const void*)arg1 length:(unsigned long long)arg2 error:(NSError **)arg3;
- (id)initWithName:(id)arg1 fromBundle:(id)arg2;
- (id)initWithName:(id)arg1 fromBundle:(id)arg2 error:(id*)arg3;
- (id)initWithURL:(id)arg1 error:(NSError **)arg2;

- (BOOL)imageExistsWithName:(id)arg1;
- (BOOL)imageExistsWithName:(id)arg1 scaleFactor:(double)arg2;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 appearanceName:(id)arg3;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 deviceIdiom:(long long)arg3;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 deviceIdiom:(long long)arg3 appearanceName:(id)arg4;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 deviceIdiom:(long long)arg3 deviceSubtype:(unsigned long long)arg4;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 deviceIdiom:(long long)arg3 deviceSubtype:(unsigned long long)arg4 appearanceName:(id)arg5;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 deviceIdiom:(long long)arg3 deviceSubtype:(unsigned long long)arg4 displayGamut:(long long)arg5 layoutDirection:(long long)arg6 sizeClassHorizontal:(long long)arg7 sizeClassVertical:(long long)arg8;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 deviceIdiom:(long long)arg3 deviceSubtype:(unsigned long long)arg4 displayGamut:(long long)arg5 layoutDirection:(long long)arg6 sizeClassHorizontal:(long long)arg7 sizeClassVertical:(long long)arg8 appearanceName:(id)arg9;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 deviceIdiom:(long long)arg3 deviceSubtype:(unsigned long long)arg4 displayGamut:(long long)arg5 layoutDirection:(long long)arg6 sizeClassHorizontal:(long long)arg7 sizeClassVertical:(long long)arg8 memoryClass:(long long)arg9 graphicsClass:(long long)arg10;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 deviceIdiom:(long long)arg3 deviceSubtype:(unsigned long long)arg4 displayGamut:(long long)arg5 layoutDirection:(long long)arg6 sizeClassHorizontal:(long long)arg7 sizeClassVertical:(long long)arg8 memoryClass:(unsigned long long)arg9 graphicsClass:(unsigned long long)arg10 appearanceIdentifier:(long long)arg11 graphicsFallBackOrder:(id)arg12 deviceSubtypeFallBackOrder:(id)arg13;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 deviceIdiom:(long long)arg3 deviceSubtype:(unsigned long long)arg4 displayGamut:(long long)arg5 layoutDirection:(long long)arg6 sizeClassHorizontal:(long long)arg7 sizeClassVertical:(long long)arg8 memoryClass:(unsigned long long)arg9 graphicsClass:(unsigned long long)arg10 graphicsFallBackOrder:(id)arg11 deviceSubtypeFallBackOrder:(id)arg12;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 deviceIdiom:(long long)arg3 deviceSubtype:(unsigned long long)arg4 sizeClassHorizontal:(long long)arg5 sizeClassVertical:(long long)arg6;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 deviceIdiom:(long long)arg3 deviceSubtype:(unsigned long long)arg4 sizeClassHorizontal:(long long)arg5 sizeClassVertical:(long long)arg6 appearanceName:(id)arg7;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 deviceIdiom:(long long)arg3 layoutDirection:(long long)arg4 adjustRenditionKeyWithBlock:(id)arg5;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 displayGamut:(long long)arg3 layoutDirection:(long long)arg4;
- (CUINamedImage *)imageWithName:(id)arg1 scaleFactor:(double)arg2 displayGamut:(long long)arg3 layoutDirection:(long long)arg4 appearanceName:(id)arg5;
- (NSArray<CUINamedImage *> *)imagesWithName:(id)arg1;

- (NSArray<NSString *> *)allImageNames;
- (NSArray<NSString *> *)appearanceNames;

@end

