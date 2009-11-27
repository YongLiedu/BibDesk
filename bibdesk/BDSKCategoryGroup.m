//
//  BDSKCategoryGroup.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/21/06.
/*
 This software is Copyright (c) 2005-2009
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKCategoryGroup.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import "BDSKTypeManager.h"
#import "CIImage_BDSKExtensions.h"


// a private subclass for the Empty ... group
@interface BDSKEmptyGroup : BDSKCategoryGroup @end


@implementation BDSKCategoryGroup

// designated initializer
- (id)initWithName:(id)aName key:(NSString *)aKey count:(NSInteger)aCount {
    if (aName == nil) {
        NSZone *zone = [self zone];
        [self release];
        self = [BDSKEmptyGroup allocWithZone:zone];
        aName = [aKey isPersonField] ? [BibAuthor emptyAuthor] : @"";
    }
    if (self = [super initWithName:aName count:aCount]) {
        key = [aKey copy];
    }
    return self;
}

// super's designated initializer
- (id)initWithName:(id)aName count:(NSInteger)aCount {
    self = [self initWithName:aName key:nil count:aCount];
    return self;
}

- (id)initWithDictionary:(NSDictionary *)groupDict {
    NSString *aName = [[groupDict objectForKey:@"group name"] stringByUnescapingGroupPlistEntities];
    NSString *aKey = [[groupDict objectForKey:@"key"] stringByUnescapingGroupPlistEntities];
    self = [self initWithName:aName key:aKey count:0];
    return self;
}

- (NSDictionary *)dictionaryValue {
    NSString *aName = [[self stringValue] stringByEscapingGroupPlistEntities];
    NSString *aKey = [[self key] stringByEscapingGroupPlistEntities];
    return [NSDictionary dictionaryWithObjectsAndKeys:aName, @"group name", aKey, @"key", nil];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        key = [[decoder decodeObjectForKey:@"key"] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:key forKey:@"key"];
}

- (id)copyWithZone:(NSZone *)aZone {
	return [[[self class] allocWithZone:aZone] initWithName:name key:key count:count];
}

- (void)dealloc {
    [key release];
    [super dealloc];
}

// name can change, but key doesn't change, and it's also required for equality
- (NSUInteger)hash {
    return [key hash];
}

- (BOOL)isEqual:(id)other {
	if ([super isEqual:other] == NO) 
		return NO;
	return [[self key] isEqualToString:[other key]] || ([self key] == nil && [other key] == nil);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@, key=\"%@\"", [super description], key];
}

- (BOOL)containsItem:(BibItem *)item {
	if (key == nil)
		return YES;
	return [item isContainedInGroupNamed:name forField:key];
}

// accessors

- (NSString *)key {
    return [[key retain] autorelease];
}

- (NSImage *)icon {
    static NSImage *categoryGroupImage = nil;
    if (categoryGroupImage == nil) {
        categoryGroupImage = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
        [categoryGroupImage lockFocus];
        CIImage *ciImage = [CIImage imageWithData:[[NSImage imageNamed:NSImageNameFolderSmart] TIFFRepresentation]];
        ciImage = [ciImage imageWithAdjustedHueAngle:3.0 saturationFactor:1.3 brightnessBias:0.3];
        [ciImage drawInRect:NSMakeRect(0.0, 0.0, 32.0, 32.0) fromRect:NSMakeRect(0.0, 0.0, 32.0, 32.0) operation:NSCompositeSourceOver fraction:1.0];
        [categoryGroupImage unlockFocus];
        NSImage *tinyImage = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
        [tinyImage lockFocus];
        [[NSImage imageNamed:NSImageNameFolderSmart] drawInRect:NSMakeRect(0.0, 0.0, 16.0, 16.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [tinyImage unlockFocus];
        ciImage = [CIImage imageWithData:[tinyImage TIFFRepresentation]];
        ciImage = [ciImage imageWithAdjustedHueAngle:3.0 saturationFactor:1.3 brightnessBias:0.3];
        [tinyImage release];
        tinyImage = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
        [tinyImage lockFocus];
        [ciImage drawInRect:NSMakeRect(0.0, 0.0, 16.0, 16.0) fromRect:NSMakeRect(0.0, 0.0, 16.0, 16.0) operation:NSCompositeSourceOver fraction:1.0];
        [tinyImage unlockFocus];
        [categoryGroupImage addRepresentation:[[tinyImage representations] lastObject]];
        [tinyImage release];
    }
    return categoryGroupImage;
}

- (void)setName:(id)newName {
    if (name != newName) {
        [name release];
        name = [newName retain];
    }
}

- (NSString *)editingStringValue {
    return [name isKindOfClass:[BibAuthor class]] ? [name originalName] : [super editingStringValue];
}

- (BOOL)isCategory { return YES; }

- (BOOL)hasEditableName { return YES; }

- (BOOL)isEditable {
    return [key isPersonField];
}

- (BOOL)isValidDropTarget { return YES; }

- (BOOL)isEmpty { return NO; }

@end

#pragma mark -

@implementation BDSKEmptyGroup

- (NSImage *)icon {
    static NSImage *image = nil;
    if(image == nil){
        image = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
        NSImage *genericImage = [super icon];
        NSImage *questionMark = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kQuestionMarkIcon)];
        NSUInteger i;
        [image lockFocus];
        [genericImage drawInRect:NSMakeRect(0.0, 0.0, 32.0, 32.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
        // hack to make the question mark dark enough to be visible
        for(i = 0; i < 3; i++)
            [questionMark drawInRect:NSMakeRect(6.0, 4.0, 20.0, 20.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [image unlockFocus];
        NSImage *tinyImage = [[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)];
        [tinyImage lockFocus];
        [genericImage drawInRect:NSMakeRect(0.0, 0.0, 16.0, 16.0) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
        // hack to make the question mark dark enough to be visible
        for(i = 0; i < 3; i++)
            [questionMark drawInRect:NSMakeRect(3.0, 1.0, 10.0, 10.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [tinyImage unlockFocus];
        [image addRepresentation:[[tinyImage representations] lastObject]];
        [tinyImage release];
    }
    return image;
}

- (NSString *)stringValue {
    return [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Empty", @""), key];
}

- (BOOL)containsItem:(BibItem *)item {
	if (key == nil)
		return YES;
	return [[item groupsForField:key] count] == 0;
}

- (BOOL)hasEditableName { return NO; }

- (BOOL)isEditable { return NO; }

- (BOOL)isEmpty { return YES; }

@end
