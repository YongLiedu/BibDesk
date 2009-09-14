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
static NSMutableDictionary *_fallbackTable = nil;
static NSLock *_fallbackTableLock = nil;
static Class FVMIMEIconClass = Nil;
static FVMIMEIcon *defaultPlaceholderIcon = nil;

+ (void)initialize
{
    FVINITIALIZE(FVMIMEIcon);
    
    if ([FVMIMEIcon class] == self) {
        FVMIMEIconClass = self;
        GetIconRef(kOnSystemDisk, kSystemIconsCreator, kGenericNetworkIcon, &_networkIcon);
        _fallbackTable = [NSMutableDictionary new];
        _fallbackTableLock = [[NSLock alloc] init];
        defaultPlaceholderIcon = (FVMIMEIcon *)NSAllocateObject(FVMIMEIconClass, 0, [self zone]);
    }
    
}

+ (id)allocWithZone:(NSZone *)aZone
{
    return defaultPlaceholderIcon;
}

- (id)_initWithMIMEType:(NSString *)type;
{
    NSParameterAssert(defaultPlaceholderIcon != self);
    self = [super init];
    if (self) {
        OSStatus err;
        err = GetIconRefFromTypeInfo(0, 0, NULL, (CFStringRef)type, kIconServicesNormalUsageFlag, &_icon);
        if (err) _icon = NULL;
    }
    return self;
}

+ (void)_addNewItemInLockedTableWithMIMEType:(NSString *)type;
{
    NSAssert2(pthread_main_np() != 0, @"*** threading violation *** +[%@ %@] requires main thread", self, NSStringFromSelector(_cmd));
    NSAssert([_fallbackTableLock tryLock] == NO, @"caller failed to acquire lock first");
    
    id icon = (FVMIMEIcon *)NSAllocateObject(FVMIMEIconClass, 0, [self zone]);
    icon = [icon _initWithMIMEType:type];
    // should only return nil if NSAllocateObject fails
    if (icon) {
        [_fallbackTable setObject:icon forKey:type];
        [icon release];
    }
}

- (void)dealloc
{
#if DEBUG
    NSLog(@"*** memory error *** dealloc of %@", [self class]);
#endif
    // stop compiler warning about missing [super dealloc]
    if (0) [super dealloc];
}

- (BOOL)tryLock { return NO; }
- (void)lock { /* do nothing */ }
- (void)unlock { /* do nothing */ }

// we always return a cached object owned solely by the _fallbackTable, which should never be deallocated
- (id)retain { return self; }
- (oneway void)release { }
- (NSUInteger)retainCount { return NSUIntegerMax; }

- (void)renderOffscreen
{
    // no-op
}

- (NSSize)size { return (NSSize){ FVMaxThumbnailDimension, FVMaxThumbnailDimension }; }

// self here is the placeholder; we always discard the result of +allocWithZone: here, since the actual +alloc has to occur on the main thread in _addNewItemInLockedTableWithMIMEType, or we're just returning a previously allocated instance.
- (id)initWithMIMEType:(NSString *)type;
{
    NSParameterAssert(nil != type);
    NSParameterAssert(defaultPlaceholderIcon == self);
    [_fallbackTableLock lock];
    self = [_fallbackTable objectForKey:type];
    if (nil == self) {
        [FVMIMEIconClass performSelectorOnMainThread:@selector(_addNewItemInLockedTableWithMIMEType:) withObject:type waitUntilDone:YES modes:[NSArray arrayWithObject:(id)kCFRunLoopCommonModes]];
        self = [_fallbackTable objectForKey:type];
    }
    [_fallbackTableLock unlock];    
    return self;
}

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
