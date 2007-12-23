//
//  FVFinderIcon.m
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
/*
 This software is Copyright (c) 2007
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

@implementation FVFinderIcon

static IconRef __genericDocIcon;
static IconRef __questionIcon;
static IconRef __httpIcon;
static IconRef __ftpIcon;
static IconRef __genericURLIcon;

+ (void)initialize
{
    static BOOL didInit = NO;
    if (NO == didInit) {
        OSStatus err;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kGenericDocumentIcon, &__genericDocIcon);
        if (err) __genericDocIcon = NULL;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kQuestionMarkIcon, &__questionIcon);
        if (err) __questionIcon = NULL;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kInternetLocationHTTPIcon, &__httpIcon);
        if (err) __httpIcon = NULL;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kInternetLocationFTPIcon, &__ftpIcon);
        if (err) __ftpIcon = NULL;
        err = GetIconRef(kOnSystemDisk, kSystemIconsCreator, kGenericURLIcon, &__genericURLIcon);
        if (err) __genericURLIcon = NULL;
        didInit = YES;
    }
}

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
    self = [super init];
    if (self) {
        _iconType = FVFinderIconType;
        
        if ([scheme isEqualToString:@"http"])
            _iconRef = __httpIcon;
        else if ([scheme isEqualToString:@"ftp"])
            _iconRef = __ftpIcon;
        else
            _iconRef = __genericURLIcon;
        // increment retain count of the shared instance
        if (_iconRef) AcquireIconRef(_iconRef);
    }
    return self;
}

- (id)initWithFinderIconOfURL:(NSURL *)theURL;
{
    self = [super init];
    if (self) {
        _iconType = FVFinderIconType;
        _iconRef = NULL;
        
        if (theURL) {
            OSStatus err;
            FSRef fileRef;
            if (FALSE == CFURLGetFSRef((CFURLRef)theURL, &fileRef))
                err = fnfErr;
            else
                err = noErr;
            err = GetIconRefFromFileInfo(&fileRef, 0, NULL, kFSCatInfoNone, NULL, kIconServicesNormalUsageFlag, &_iconRef, NULL);
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
        
        if (__genericDocIcon)
            PlotIconRefInContext(context, &rect, kAlignAbsoluteCenter, kTransformNone, NULL, kPlotIconRefNormalFlags, __genericDocIcon);
        rect = CGRectInset(rect, rect.size.width/4, rect.size.height/4);
        if (__questionIcon)
            PlotIconRefInContext(context, &rect, kAlignCenterBottom, kTransformNone, NULL, kPlotIconRefNormalFlags, __questionIcon);          
    }
    else {
        PlotIconRefInContext(context, &rect, kAlignAbsoluteCenter, kTransformNone, NULL, kPlotIconRefNormalFlags, _iconRef);
    }
}

- (BOOL)needsShadow { return NO; }

@end
