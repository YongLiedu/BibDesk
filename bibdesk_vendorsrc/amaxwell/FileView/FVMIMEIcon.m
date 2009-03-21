//
//  FVMIMEIcon.m
//  FileView
//
//  Created by Adam Maxwell on 02/12/08.
/*
 This software is Copyright (c) 2008-2009
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

#import "FVMIMEIcon.h"

@implementation FVMIMEIcon

static IconRef _networkIcon = NULL;
static NSMutableDictionary *_iconTable = nil;

+ (void)initialize
{
    FVINITIALIZE(FVMIMEIcon);
    
    GetIconRef(kOnSystemDisk, kSystemIconsCreator, kGenericNetworkIcon, &_networkIcon);
    _iconTable = [NSMutableDictionary new];
}

+ (id)newIconWithMIMEType:(NSString *)type;
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** +[%@ %@] requires main thread", self, NSStringFromSelector(_cmd));
    NSParameterAssert(nil != type);
    FVMIMEIcon *icon = [[_iconTable objectForKey:type] retain];
    if (nil == icon) {
        icon = [[[self class] allocWithZone:[self zone]] initWithMIMEType:type];
        if (icon)
            [_iconTable setObject:icon forKey:type];
    }
    return icon;
}

- (id)initWithMIMEType:(NSString *)type;
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** +[%@ %@] requires main thread", self, NSStringFromSelector(_cmd));
    if (self = [super init]) {
        OSStatus err;
        err = GetIconRefFromTypeInfo(0, 0, NULL, (CFStringRef)type, kIconServicesNormalUsageFlag, &_icon);
        if (err) _icon = NULL;
        // don't return nil; we'll just draw the network icon
    }
    return self;
}

- (void)dealloc
{
    FVAPIAssert1(0, @"attempt to deallocate %@", self);
    [super dealloc];
}

- (BOOL)tryLock { return NO; }
- (void)lock { /* do nothing */ }
- (void)unlock { /* do nothing */ }

- (void)renderOffscreen { /* no-op */ }

- (NSSize)size { return (NSSize){ FVMaxThumbnailDimension, FVMaxThumbnailDimension }; }   

- (void)drawInRect:(NSRect)dstRect ofContext:(CGContextRef)context;
{
    CGRect rect = [self _drawingRectWithRect:dstRect];            
    CGContextSaveGState(context);
    // get rid of any shadow, as the image draws it
    CGContextSetShadowWithColor(context, CGSizeZero, 0, NULL);
    
    if (_icon)
        PlotIconRefInContext(context, &rect, kAlignAbsoluteCenter, kTransformNone, NULL, kIconServicesNoBadgeFlag, _icon);
    
    // slight inset and draw partially transparent
    CGRect networkRect = CGRectInset(rect, CGRectGetWidth(rect) / 7, CGRectGetHeight(rect) / 7);
    CGContextSetAlpha(context, 0.6);
    if (_networkIcon)
        PlotIconRefInContext(context, &networkRect, kAlignAbsoluteCenter, kTransformNone, NULL, kIconServicesNoBadgeFlag, _networkIcon);  
    
    CGContextRestoreGState(context);
}

@end
