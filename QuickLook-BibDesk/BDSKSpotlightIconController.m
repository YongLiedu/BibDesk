//
//  BDSKSpotlightIconController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 01/25/07.
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

#import "BDSKSpotlightIconController.h"

static id controller = nil;
static NSImage *applicationIcon = nil;

@interface BDSKSpotlightIconController (Private)
+ (void)freeStatics;
- (id)initWithBundle:(NSBundle *)bundle;
- (NSBitmapImageRep *)imageRepWithMetadataItem:(id)anItem;
- (void)loadValuesFromMetadataItem:(id)anItem;
@end

void BDSKSpotlightIconControllerFreeStatics()
{
    [BDSKSpotlightIconController freeStatics];
}

@implementation BDSKSpotlightIconController

+ (void)freeStatics
{
    @synchronized(self) {
        [controller release];
        controller = nil;
        [applicationIcon release];
        applicationIcon = nil;
    }
}

+ (NSBitmapImageRep *)imageRepWithMetadataItem:(id)anItem forBundle:(NSBundle *)bundle
{
    NSBitmapImageRep *imageRep = nil;
    @synchronized(self) {
        if (nil == controller)
            controller = [[self alloc] initWithBundle:bundle];
        if (applicationIcon == nil) {
            NSString *iconPath = [bundle pathForImageResource:@"FolderPenIcon"];
            applicationIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
            [applicationIcon setName:@"FolderPenIcon"];
            [applicationIcon setSize:NSMakeSize(128, 128)];
        }
        imageRep = [controller imageRepWithMetadataItem:anItem];
    }
    return imageRep;
}

- (id)initWithBundle:(NSBundle *)bundle
{
    if (self = [super init]) {
        // manually load the nib, since +[NSBundle loadNibName...] won't work
        if ([bundle loadNibFile:@"SpotlightFileIconController" externalNameTable:[NSDictionary dictionaryWithObject:self forKey:@"NSOwner"] withZone:[self zone]]) {
            values = [[NSMutableArray alloc] initWithCapacity:16];
            dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy"];
        } else {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (void)dealloc
{
    [values release];
    [dateFormatter release];
    [window release];
    [arrayController release];
    [super dealloc];
}

static void addDictionaryWithAttributeAndValue(NSMutableArray *array, NSString *attribute, id value)
{
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:attribute, @"attributeName", value ?: @"", @"attributeValue", nil];
    [array addObject:dict];
    [dict release];
}

static void addDictionariesFromMultivaluedAttribute(NSMutableArray *array, NSString *attribute, NSArray *values)
{
    for (id value in values) {
        addDictionaryWithAttributeAndValue(array, attribute, value);
        // empty attribute name for the rest
        attribute = @"";
    }
}

- (void)loadValuesFromMetadataItem:(id)anItem;
{
    [self willChangeValueForKey:@"values"];
    
    [values removeAllObjects];
    
    // anItem is key-value coding compliant
    addDictionaryWithAttributeAndValue(values, @"Container:", [anItem valueForKey:@"net_sourceforge_bibdesk_container"]);
    addDictionaryWithAttributeAndValue(values, @"Title:", [anItem valueForKey:(NSString *)kMDItemTitle]);
    addDictionaryWithAttributeAndValue(values, @"Year:", [dateFormatter stringFromDate:[anItem valueForKey:@"net_sourceforge_bibdesk_publicationdate"]]);
    addDictionariesFromMultivaluedAttribute(values, @"Authors:", [anItem valueForKey:(NSString *)kMDItemAuthors]);
    addDictionariesFromMultivaluedAttribute(values, @"Keywords:", [anItem valueForKey:(NSString *)kMDItemKeywords]);
    
    while ([values count] < 10)
        // empty lines for the rest
        addDictionaryWithAttributeAndValue(values, @"", @"");
    
    [self didChangeValueForKey:@"values"];
}

- (NSBitmapImageRep *)imageRepWithMetadataItem:(id)anItem;
{
    [self loadValuesFromMetadataItem:anItem];
    
    NSView *contentView = [window contentView];
    NSBitmapImageRep *imageRep = [contentView bitmapImageRepForCachingDisplayInRect:[contentView frame]];
    [contentView cacheDisplayInRect:[contentView frame] toBitmapImageRep:imageRep];
    return imageRep;
}

@end


@implementation BDSKSpotlightIconTableView

- (void)drawGridInClipRect:(NSRect)rect {    
    [super drawGridInClipRect:rect];
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(context);
    if ([self isFlipped]) {
        CGContextTranslateCTM(context, 0.0f, NSMaxY([self frame]));
        CGContextScaleCTM(context, 1.0f, -1.0f);
        rect.origin.y = 0.0f; // We've translated ourselves so it's zero
    }
    [applicationIcon drawAtPoint:NSMakePoint(10.0f, NSMaxY([self frame]) - 128.0f) fromRect:NSZeroRect operation:NSCompositeSourceAtop fraction:1.0f];
    CGContextRestoreGState(context);
}

@end

@implementation BDSKClearView

- (void)drawRect:(NSRect)r
{
    [[NSColor whiteColor] setFill];
    NSRectFill(r);
}

@end
