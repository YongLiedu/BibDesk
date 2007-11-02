//
//  FVBitmapContextCache.m
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "FVBitmapContextCache.h"

// this is really a struct that we can use as a dictionary key
@interface FVBitmapSize : NSObject <NSCopying>
{
@public
    NSUInteger _width;
    NSUInteger _height;
}
+ (id)newSizeWithWidth:(NSUInteger)w height:(NSUInteger)h;
@end

@implementation FVBitmapContextCache

/*
 An underlying assumption here is that we'll be displaying many items of the same size.  This is valid for pages of text (PDF/PS/RTF/etc), where we'll typically have a mix of letter/a4 pages with a few bastard ones thrown in.  Update: journal pages are entirely bastard sizes, so we now create and destroy those contexts as needed.  Scaling each page to paper size isn't right, but we could possibly check the aspect ratio and scale to a cached size.
 
 This cache is also used for file icons.  Since the FileView requests icons at widely varying sizes with floating point precision if the icon scale changes, the caller is responsible for ensuring a reasonable granularity of sizes (e.g. 16, 32, 64, 128, 256, 512) using bestIntegralSizeForIconSize().
 
 General image files are processed with ImageIO, since they can vary widely in pixel size.
 
 */

static NSLock *__cacheLock = nil;
static NSMutableDictionary *__contextCache = nil;
static NSMutableDictionary *__gray8bitContextCache = nil;

+ (void)initialize
{
    static BOOL didInit = NO;
    if (NO == didInit) {
        // lock is shared between both caches; since this class is generally accessed from the rendering thread, there's no real contention to deal with
        __cacheLock = [[NSLock alloc] init];
        __contextCache = [[NSMutableDictionary alloc] init];
        __gray8bitContextCache = [[NSMutableDictionary alloc] init];
        didInit = YES;
    }
}

FV_PRIVATE_EXTERN CGContextRef FVIconBitmapContextCreateGrayNoAlphaWithSize(size_t width, size_t height)
{
    size_t bitsPerComponent = 8;
    size_t nComponents = 1;
    size_t bytesPerRow = bitsPerComponent * nComponents * width;
    
    //Widen bytesPerRow out to a integer multiple of 16 bytes
    bytesPerRow = (bytesPerRow + 15) & ~15;
    
    //Make sure we are not an even power of 2 wide.
    //Will loop a few times for bytesPerRow <= 16.
    while( 0 == (bytesPerRow & (bytesPerRow - 1) ) )
        bytesPerRow += 16;                 //grow bytesPerRow
    
    size_t requiredDataSize = bytesPerRow * height;
    
    // see comments in FVIconBitmapContextCreateWithSize()
    CGColorSpaceRef cspace = CGColorSpaceCreateDeviceGray();
    void *bitmapData = NSZoneMalloc(NSDefaultMallocZone(), requiredDataSize);
    
    CGContextRef ctxt;
    // we're using kCGImageAlphaNone instead of kCGImageAlphaNoneSkipFirst since it lets us maintain a smaller memory footprint
    ctxt = CGBitmapContextCreate(bitmapData, width, height, bitsPerComponent, bytesPerRow, cspace, kCGImageAlphaNone);
    CGColorSpaceRelease(cspace);
    
    CGContextSetRenderingIntent(ctxt, kCGRenderingIntentAbsoluteColorimetric);
    
    // note that bitmapData and the context itself are allocated and not freed here
    
    return ctxt;
}

FV_PRIVATE_EXTERN CGContextRef FVIconBitmapContextCreateWithSize(size_t width, size_t height)
{
    size_t bitsPerComponent = 8;
    size_t nComponents = 4;
    size_t bytesPerRow = bitsPerComponent * nComponents * width;
    
    //Widen bytesPerRow out to a integer multiple of 16 bytes
    bytesPerRow = (bytesPerRow + 15) & ~15;
    
    //Make sure we are not an even power of 2 wide.
    //Will loop a few times for bytesPerRow <= 16.
    while( 0 == (bytesPerRow & (bytesPerRow - 1) ) )
        bytesPerRow += 16;                 //grow bytesPerRow
    
    size_t requiredDataSize = bytesPerRow * height;
    
    // CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB) gives us a device independent colorspace, but we don't care in this case, since we're just drawing to the screen, and color conversion when blitting the CGImageRef is a pretty big hit.  See http://www.cocoabuilder.com/archive/message/cocoa/2002/10/31/56768 for additional details, including a recommendation to use alpha in the highest 8 bits (ARGB) and use kCGRenderingIntentAbsoluteColorimetric for rendering intent.
    CGColorSpaceRef cspace = CGColorSpaceCreateDeviceRGB();
    void *bitmapData = NSZoneMalloc(NSDefaultMallocZone(), requiredDataSize);
    
    CGContextRef ctxt;
    ctxt = CGBitmapContextCreate(bitmapData, width, height, bitsPerComponent, bytesPerRow, cspace, kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(cspace);
    
    CGContextSetRenderingIntent(ctxt, kCGRenderingIntentAbsoluteColorimetric);
    
    // note that bitmapData and the context itself are allocated and not freed here
    
    return ctxt;
}

FV_PRIVATE_EXTERN void FVIconBitmapContextDispose(CGContextRef ctxt)
{
    void *bitmapData = CGBitmapContextGetData(ctxt);
    if (bitmapData) NSZoneFree(NSZoneFromPointer(bitmapData), bitmapData);
    CGContextRelease(ctxt);
}

+ (CGContextRef)new8BitGrayBitmapContextOfWidth:(CGFloat)w height:(CGFloat)h;
{
    NSUInteger width = w, height = h;
    FVBitmapSize *key = [FVBitmapSize newSizeWithWidth:width height:height];
    [__cacheLock lock];
    CGContextRef ctxt = (CGContextRef)[__gray8bitContextCache objectForKey:key];
    if (NULL == ctxt) {
        // create a new context; the caller can then release it or push it into the cache
        ctxt = FVIconBitmapContextCreateGrayNoAlphaWithSize(w, h);
    }
    else {
        // remove from the cache so another thread/caller doesn't get it
        CGContextRetain(ctxt);
        [__gray8bitContextCache removeObjectForKey:key];
    }
    [key release];
    [__cacheLock unlock];
    return ctxt;
}

+ (void)disposeOf8BitGrayBitmapContext:(CGContextRef)ctxt;
{
    // This only allows us to cache a single context for any given size; however, 
    // we'll generally be using them from a single thread (serially), so I don't expect that to be a problem
    FVBitmapSize *key = [FVBitmapSize newSizeWithWidth:CGBitmapContextGetWidth(ctxt) height:CGBitmapContextGetHeight(ctxt)];
    [__cacheLock lock];
    if ([__gray8bitContextCache objectForKey:key]) {
        // we already have one of this size, so get rid of this instance
        void *bitmapData = CGBitmapContextGetData(ctxt);
        if (bitmapData) NSZoneFree(NSZoneFromPointer(bitmapData), bitmapData);
    }
    else {
        // push it into the cache
        [__gray8bitContextCache setObject:(id)ctxt forKey:key];
    }
    [key release];
    // always decrement the retain count, since we either retained it in the cache or got rid of it
    CGContextRelease(ctxt);
    [__cacheLock unlock];
}

+ (CGContextRef)newBitmapContextOfWidth:(CGFloat)w height:(CGFloat)h;
{
    NSUInteger width = w, height = h;
    FVBitmapSize *key = [FVBitmapSize newSizeWithWidth:width height:height];
    [__cacheLock lock];
    CGContextRef ctxt = (CGContextRef)[__contextCache objectForKey:key];
    if (NULL == ctxt) {
        // create a new context; the caller can then release it or push it into the cache
        ctxt = FVIconBitmapContextCreateWithSize(w, h);
    }
    else {
        // remove from the cache so another thread/caller doesn't get it
        CGContextRetain(ctxt);
        [__contextCache removeObjectForKey:key];
    }
    [key release];
    [__cacheLock unlock];
    return ctxt;
}

+ (void)disposeOfBitmapContext:(CGContextRef)ctxt;
{
    // This only allows us to cache a single context for any given size; however, 
    // we'll generally be using them from a single thread (serially), so I don't expect that to be a problem
    FVBitmapSize *key = [FVBitmapSize newSizeWithWidth:CGBitmapContextGetWidth(ctxt) height:CGBitmapContextGetHeight(ctxt)];
    [__cacheLock lock];
    if ([__contextCache objectForKey:key]) {
        // we already have one of this size, so get rid of this instance
        void *bitmapData = CGBitmapContextGetData(ctxt);
        if (bitmapData) NSZoneFree(NSZoneFromPointer(bitmapData), bitmapData);
    }
    else {
        // push it into the cache
        [__contextCache setObject:(id)ctxt forKey:key];
    }
    [key release];
    // always decrement the retain count, since we either retained it in the cache or got rid of it
    CGContextRelease(ctxt);
    [__cacheLock unlock];
}

@end

@implementation FVBitmapSize

+ (id)newSizeWithWidth:(NSUInteger)w height:(NSUInteger)h;
{
    FVBitmapSize *aSize = [self allocWithZone:[self zone]];
    aSize->_width = w;
    aSize->_height = h;
    return aSize;
}

- (id)copyWithZone:(NSZone *)aZone { return [self retain]; }

// this is a dangerous implementation of isEqual, but only objects of this class will be used as dictionary keys
- (BOOL)isEqual:(FVBitmapSize *)other
{
    return (_width == other->_width && _height == other->_height);
}

- (NSUInteger)hash { return _width; }

@end
