//
//  FVIcon_Private.m
//  FileView
//
//  Created by Adam Maxwell on 2/26/08.
/*
 This software is Copyright (c) 2007-2009
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
 contributors may be used to endorse or promote products derived
 from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "FVIcon_Private.h"
#import "FVPlaceholderImage.h"

@implementation FVIcon (Private)

+ (void)_initializeCategory;
{
    static bool didInit = false;
    NSAssert(false == didInit, @"attempt to initialize category again");
    didInit = true;
}

+ (BOOL)_shouldDrawBadgeForURL:(NSURL *)aURL copyTargetURL:(NSURL **)linkTarget;
{
    NSParameterAssert([aURL isFileURL]);
    NSParameterAssert(NULL != linkTarget);
    
    uint8_t stackBuf[PATH_MAX];
    uint8_t *fsPath = stackBuf;
    CFStringRef absolutePath = CFURLCopyFileSystemPath((CFURLRef)aURL, kCFURLPOSIXPathStyle);
    NSUInteger maxLen = CFStringGetMaximumSizeOfFileSystemRepresentation(absolutePath);
    if (maxLen > sizeof(stackBuf))
        fsPath = NSZoneMalloc([self zone], maxLen);
    CFStringGetFileSystemRepresentation(absolutePath, (char *)fsPath, maxLen);
        
    OSStatus err;
    FSRef fileRef;
    err = FSPathMakeRefWithOptions(fsPath, kFSPathMakeRefDoNotFollowLeafSymlink, &fileRef, NULL);   
    if (fsPath != stackBuf)
        NSZoneFree([self zone], fsPath);
    if (absolutePath) CFRelease(absolutePath);
    
    // kLSItemContentType returns a CFStringRef, according to the header
    CFStringRef theUTI = NULL;
    if (noErr == err)
        err = LSCopyItemAttribute(&fileRef, kLSRolesAll, kLSItemContentType, (CFTypeRef *)&theUTI);
    
    BOOL drawBadge = (NULL != theUTI && UTTypeConformsTo(theUTI, kUTTypeResolvable));
    
    if (theUTI) CFRelease(theUTI);
    
    if (drawBadge) {
        // replace the URL with the resolved URL in case it was an alias
        Boolean isFolder, wasAliased;
        err = FSResolveAliasFileWithMountFlags(&fileRef, TRUE, &isFolder, &wasAliased, kARMNoUI);
        
        // wasAliased is false for symlinks, but use the resolved alias anyway
        if (noErr == err)
            *linkTarget = (id)CFURLCreateFromFSRef(NULL, &fileRef);
        else
            *linkTarget = [aURL retain];
    }
    else {
        *linkTarget = [aURL retain];
    }
    
    return drawBadge;
}

- (BOOL)tryLock { [self doesNotRecognizeSelector:_cmd]; return NO; }
- (void)lock { [self doesNotRecognizeSelector:_cmd]; }
- (void)unlock { [self doesNotRecognizeSelector:_cmd]; }

- (NSSize)size { [self doesNotRecognizeSelector:_cmd]; return NSZeroSize; }

- (void)_badgeIconInRect:(NSRect)dstRect ofContext:(CGContextRef)context;
{
    IconRef linkBadge;
    OSStatus err;
    err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kAliasBadgeIcon, &linkBadge);
    
    // rect needs to be a square, or else the aspect ratio of the arrow is wrong
    // rect needs to be the same size as the full icon, or the scale of the arrow is wrong
    
    // We don't know the size of the actual link arrow (and it changes with the size of dstRect), so fine-tuning the drawing isn't really possible as far as I can see.
    if (noErr == err) {
        PlotIconRefInContext(context, (CGRect *)&dstRect, kAlignBottomLeft, kTransformNone, NULL, kPlotIconRefNormalFlags, linkBadge);
        ReleaseIconRef(linkBadge);
    }
}

// handles centering and aspect ratio, since most of our icons have weird sizes, but they'll be drawn in a square box
- (CGRect)_drawingRectWithRect:(NSRect)iconRect;
{
    // lockless classes return NO specifically to avoid hitting this assertion
    NSAssert1([self tryLock] == NO, @"%@ failed to acquire lock before calling -size", [self class]);
    NSSize s = [self size];
    
    NSParameterAssert(s.width > 0);
    NSParameterAssert(s.height > 0);
    
    // for release builds with assertions disabled, use a 1:1 aspect
    if (s.width <= 0 || s.height <= 0) s = (NSSize) { 1, 1 };
    
    CGFloat ratio = MIN(NSWidth(iconRect) / s.width, NSHeight(iconRect) / s.height);
    CGRect dstRect = *(CGRect *)&iconRect;
    dstRect.size.width = ratio * s.width;
    dstRect.size.height = ratio * s.height;
    
    CGFloat dx = (iconRect.size.width - dstRect.size.width) / 2;
    CGFloat dy = (iconRect.size.height - dstRect.size.height) / 2;
    dstRect.origin.x += dx;
    dstRect.origin.y += dy;
    
    // The view uses centerScanRect:, which should be correct for resolution independence.  It's just annoying to return lots of decimals here.
    return CGRectIntegral(dstRect);
}

- (void)_drawPlaceholderInRect:(NSRect)dstRect ofContext:(CGContextRef)context
{
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, CGSizeZero, 0, NULL);
    CGContextDrawLayerInRect(context, *(CGRect *)&dstRect, [FVPlaceholderImage placeholderWithSize:dstRect.size]);
    CGContextRestoreGState(context);
}

@end

const size_t FVMaxThumbnailDimension = 200;
const size_t FVMaxImageDimension = 512;

// used to constrain thumbnail size for huge pages
bool FVIconLimitThumbnailSize(NSSize *size)
{
    CGFloat dimension = MIN(size->width, size->height);
    if (dimension <= FVMaxThumbnailDimension)
        return false;
    
    while (dimension > FVMaxThumbnailDimension) {
        size->width *= 0.9;
        size->height *= 0.9;
        dimension = MIN(size->width, size->height);
    }
    return true;
}

bool FVIconLimitFullImageSize(NSSize *size)
{
    CGFloat dimension = MIN(size->width, size->height);
    if (dimension <= FVMaxImageDimension)
        return false;
    
    while (dimension > FVMaxImageDimension) {
        size->width *= 0.9;
        size->height *= 0.9;
        dimension = MIN(size->width, size->height);
    }
    return true;
}

static CGImageRef __FVCreateResampledImageOfSize(CGImageRef image, const NSSize size, const bool useContextCache)
{
    CGContextRef ctxt;
    if (useContextCache)
        ctxt = [FVBitmapContextCache newBitmapContextOfWidth:size.width height:size.height];
    else
        ctxt = FVIconBitmapContextCreateWithSize(size.width, size.height);
    
    CGContextSaveGState(ctxt);
    CGContextSetInterpolationQuality(ctxt, kCGInterpolationHigh);
    CGContextDrawImage(ctxt, CGRectMake(0, 0, CGBitmapContextGetWidth(ctxt), CGBitmapContextGetHeight(ctxt)), image);
    CGContextRestoreGState(ctxt);
    
    CGImageRef toReturn = CGBitmapContextCreateImage(ctxt);
    if (useContextCache)
        [FVBitmapContextCache disposeOfBitmapContext:ctxt];
    else
        FVIconBitmapContextDispose(ctxt);
    return toReturn;
}

CGImageRef FVCreateResampledThumbnail(CGImageRef image, bool useContextCache)
{
    NSSize size = FVCGImageSize(image);
    return (FVIconLimitThumbnailSize(&size)) ? __FVCreateResampledImageOfSize(image, size, useContextCache) : CGImageRetain(image);
}

CGImageRef FVCreateResampledFullImage(CGImageRef image, bool useContextCache)
{
    NSSize size = FVCGImageSize(image);
    return (FVIconLimitFullImageSize(&size)) ? __FVCreateResampledImageOfSize(image, size, useContextCache) : CGImageRetain(image);    
}
