#import <Foundation/Foundation.h>
#import <CoreUI/CUINamedLookup.h>

@interface CUINamedImage: CUINamedLookup {
    struct _cuiniproperties { 
        unsigned int isVectorBased : 1; 
        unsigned int hasSliceInformation : 1; 
        unsigned int hasAlignmentInformation : 1; 
        unsigned int resizingMode : 2; 
        unsigned int templateRenderingMode : 3; 
        unsigned int exifOrientation : 4; 
        unsigned int isAlphaCropped : 1; 
        unsigned int isFlippable : 1; 
        unsigned int isTintable : 1; 
        unsigned int preservedVectorRepresentation : 1; 
        unsigned int _reserved : 16; 
    }  _imageProperties;
    double  _scale;
}

@property (readonly) CGRect NS_alignmentRect;
@property (nonatomic, readonly) NSEdgeInsets alignmentEdgeInsets;
@property (nonatomic, readonly) int blendMode;
@property (nonatomic, readonly) CGImageRef croppedImage;
@property (nonatomic, readonly) NSEdgeInsets edgeInsets;
@property (nonatomic, readonly) int exifOrientation;
@property (nonatomic, readonly) BOOL hasAlignmentInformation;
@property (nonatomic, readonly) BOOL hasSliceInformation;
@property (nonatomic, readonly) CGImageRef image;
@property (nonatomic, readonly) long long imageType;
@property (nonatomic, readonly) BOOL isAlphaCropped;
@property (nonatomic, readonly) BOOL isFlippable;
@property (nonatomic, readonly) BOOL isStructured;
@property (nonatomic, readonly) BOOL isTemplate;
@property (nonatomic, readonly) BOOL isVectorBased;
@property (nonatomic, readonly) double opacity;
@property (nonatomic, readonly) BOOL preservedVectorRepresentation;
@property (nonatomic, readonly) long long resizingMode;
@property (nonatomic, readonly) double scale;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) long long templateRenderingMode;

- (id)baseKey;
- (CGRect)alphaCroppedRect;
- (CGImageRef)createImageFromPDFRenditionWithScale:(double)arg1;
- (CGImageRef)croppedImage;

- (id)initWithName:(id)arg1 usingRenditionKey:(id)arg2 fromTheme:(unsigned long long)arg3;

- (CGSize)originalUncroppedSize;
- (double)positionOfSliceBoundary:(unsigned int)arg1;

@end
