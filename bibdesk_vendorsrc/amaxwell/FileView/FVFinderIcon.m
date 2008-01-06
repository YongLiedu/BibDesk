//
//  FVFinderIcon.m
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
/*
 This software is Copyright (c) 2007,2008
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

#import "FVFinderIcon.h"

@interface FVSingletonFinderIcon : FVFinderIcon
+ (id)sharedIcon;
@end
@interface FVMissingFinderIcon : FVSingletonFinderIcon
{
    IconRef _questionIcon;
}
@end
@interface FVHTTPURLIcon : FVSingletonFinderIcon
@end
@interface FVGenericURLIcon : FVSingletonFinderIcon
@end
@interface FVFTPURLIcon : FVSingletonFinderIcon
@end

@implementation FVFinderIcon

- (BOOL)needsRenderForSize:(NSSize)size
{
    return NO;
}

- (void)renderOffscreen
{
    // no-op
}

- (id)initWithURLScheme:(NSString *)scheme;
{
    NSParameterAssert(nil != scheme);
    [self release];
        
    if ([scheme isEqualToString:@"http"])
        self = [FVHTTPURLIcon sharedIcon];
    else if ([scheme isEqualToString:@"ftp"])
        self = [FVFTPURLIcon sharedIcon];
    else
        self = [FVGenericURLIcon sharedIcon];
    return self;
}

// nil URL will draw the missing file
- (id)initWithFinderIconOfURL:(NSURL *)theURL;
{
    self = [super init];
    if (self) {
        _iconType = FVFinderIconType;
        _iconRef = NULL;
        
        _drawsLinkBadge = theURL ? [[self class] _shouldDrawBadgeForURL:theURL] : NO;
        if (_drawsLinkBadge)
            theURL = [[self class] _resolvedURLWithURL:theURL];
        
        if (theURL) {
            OSStatus err;
            FSRef fileRef;
            if (FALSE == CFURLGetFSRef((CFURLRef)theURL, &fileRef))
                err = fnfErr;
            else
                err = noErr;
            err = GetIconRefFromFileInfo(&fileRef, 0, NULL, kFSCatInfoNone, NULL, kIconServicesNoBadgeFlag, &_iconRef, NULL);
            if (noErr != err) {
                // this will indicate that we should plot the question mark icon
                _iconRef = NULL;
            }
            
            // !!! docs don't say we own the reference from GetIconRefFromFileInfo
            
        }
        else {
            _iconRef = NULL;
        }
    }
    return self;   
}

- (void)releaseResources
{
    // do nothing
}

- (void)dealloc
{
    if (_iconRef) ReleaseIconRef(_iconRef);
    [super dealloc];
}

- (NSSize)size { return NSMakeSize(128, 128); }

- (void)drawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;
{
    CGRect rect = [self _drawingRectWithRect:dstRect];
    
    if (NULL == _iconRef) {
        [[FVMissingFinderIcon sharedIcon] drawInRect:dstRect inCGContext:context];       
    }
    else {
        PlotIconRefInContext(context, &rect, kAlignAbsoluteCenter, kTransformNone, NULL, kIconServicesNoBadgeFlag, _iconRef);
    }
    // We could use Icon Services to draw the badge, but it draws pure alpha with a centered badge at large sizes.  It also results in an offset image relative to the grid.
    if (_drawsLinkBadge)
        [self _drawBadgeInContext:context forIconInRect:dstRect withDrawingRect:rect];
}

- (BOOL)needsShadow { return NO; }

@end

#pragma mark Base singleton

@implementation FVSingletonFinderIcon

+ (id)sharedIcon {  NSAssert(0, @"subclasses must implement +sharedIcon and provide static storage"); return nil; }

- (void)dealloc
{
#if DEBUG
    NSLog(@"*** memory error *** dealloc of %@", [self class]);
#endif
    // stop compiler warning about missing [super dealloc]
    if (0) [super dealloc];
}

- (id)retain { return self; }
- (oneway void)release { }
- (NSUInteger)retainCount { return NSUIntegerMax; }

@end

#pragma mark Missing file icon

@implementation FVMissingFinderIcon

+ (id)sharedIcon
{
    static id sharedInstance = nil;
    if (nil == sharedInstance)
        sharedInstance = [[self allocWithZone:[self zone]] init];
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _iconType = FVFinderIconType;
        _drawsLinkBadge = NO;
        OSStatus err;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kQuestionMarkIcon, &_questionIcon);
        if (err) _questionIcon = NULL;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kGenericDocumentIcon, &_iconRef);
        if (err) _iconRef = NULL;
    }
    return self;
}

- (void)drawInRect:(NSRect)dstRect inCGContext:(CGContextRef)context;
{
    CGRect rect = [self _drawingRectWithRect:dstRect];            
    if (_iconRef)
        PlotIconRefInContext(context, &rect, kAlignAbsoluteCenter, kTransformNone, NULL, kIconServicesNoBadgeFlag, _iconRef);
    rect = CGRectInset(rect, rect.size.width/4, rect.size.height/4);
    if (_questionIcon)
        PlotIconRefInContext(context, &rect, kAlignCenterBottom, kTransformNone, NULL, kIconServicesNoBadgeFlag, _questionIcon);          
}


@end

#pragma mark HTTP URL icon

@implementation FVHTTPURLIcon

+ (id)sharedIcon
{
    static id sharedInstance = nil;
    if (nil == sharedInstance)
        sharedInstance = [[self allocWithZone:[self zone]] init];
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _iconType = FVFinderIconType;
        _drawsLinkBadge = NO;
        OSStatus err;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kInternetLocationHTTPIcon, &_iconRef);
        if (err) _iconRef = NULL;
    }
    return self;
}

@end

#pragma mark Generic URL icon

@implementation FVGenericURLIcon

+ (id)sharedIcon
{
    static id sharedInstance = nil;
    if (nil == sharedInstance)
        sharedInstance = [[self allocWithZone:[self zone]] init];
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _iconType = FVFinderIconType;
        _drawsLinkBadge = NO;
        OSStatus err;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kGenericURLIcon, &_iconRef);
        if (err) _iconRef = NULL;
    }
    return self;
}

@end

#pragma mark FTP URL icon

@implementation FVFTPURLIcon 

+ (id)sharedIcon
{
    static id sharedInstance = nil;
    if (nil == sharedInstance)
        sharedInstance = [[self allocWithZone:[self zone]] init];
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _iconType = FVFinderIconType;
        _drawsLinkBadge = NO;
        OSStatus err;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kInternetLocationFTPIcon, &_iconRef);
        if (err) _iconRef = NULL;
    }
    return self;
}

@end
