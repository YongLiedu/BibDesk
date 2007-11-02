//
//  FVBitmapContextCache.h
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

FV_PRIVATE_EXTERN CGContextRef FVIconBitmapContextCreateWithSize(size_t width, size_t height);
FV_PRIVATE_EXTERN CGContextRef FVIconBitmapContextCreateGrayNoAlphaWithSize(size_t width, size_t height);
FV_PRIVATE_EXTERN void FVIconBitmapContextDispose(CGContextRef ctxt);

@interface FVBitmapContextCache : NSObject

// ARGB cache
+ (CGContextRef)newBitmapContextOfWidth:(CGFloat)w height:(CGFloat)h;
+ (void)disposeOfBitmapContext:(CGContextRef)ctxt;

// Grayscale cache
+ (void)disposeOf8BitGrayBitmapContext:(CGContextRef)ctxt;
+ (CGContextRef)new8BitGrayBitmapContextOfWidth:(CGFloat)w height:(CGFloat)h;

@end
