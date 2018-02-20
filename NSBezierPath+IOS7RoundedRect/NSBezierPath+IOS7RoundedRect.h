//
//  NSBezierPath+IOS7RoundedRect.h
//
//  Created by Matej Dunik on 11/12/13.
//  Copyright (c) 2013 PixelCut. All rights reserved except as below:
//  This code is provided as-is, without warranty of any kind. You may use it in your projects as you wish.
//

#import <Cocoa/Cocoa.h>

@interface NSBezierPath (IOS7RoundedRect)

+ (NSBezierPath *)bezierPathWithIOS7RoundedRect:(NSRect)rect cornerRadius:(CGFloat)radius;

@end
