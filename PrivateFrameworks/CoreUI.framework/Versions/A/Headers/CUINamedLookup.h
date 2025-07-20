#import <Foundation/Foundation.h>

@class CUIRenditionKey;

@interface CUINamedLookup: NSObject <NSLocking> {
    unsigned int  _distilledInVersion;
    CUIRenditionKey * _key;
    NSString * _name;
    unsigned int  _odContent;
    NSString * _signature;
    unsigned long long  _storageRef;
}

- (id)initWithName:(id)arg1 usingRenditionKey:(id)arg2 fromTheme:(unsigned long long)arg3;

@end
