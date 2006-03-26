//
//  BDSKGroup.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/11/05.
/*
 This software is Copyright (c) 2005,2006
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

#import "BDSKGroup.h"
#import "BDSKFilter.h"
#import "NSString_BDSKExtensions.h"
#import "NSImage+Toolbox.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import <OmniBase/OBUtilities.h>


// a private subclass for the All Publication group
@interface BDSKAllPublicationsGroup : BDSKGroup {
} 
@end

// a private subclass for the Empty ... group
@interface BDSKEmptyGroup : BDSKGroup @end


@implementation BDSKGroup

- (id)init {
	self = [self initWithName:NSLocalizedString(@"Group", @"Group") key:nil count:0];
    return self;
}

- (id)initWithAllPublications {
	NSZone *zone = [self zone];
	[[super init] release];
	self = [[BDSKAllPublicationsGroup allocWithZone:zone] init];
	return self;
}

- (id)initEmptyGroupWithClass:(Class)aClass key:(NSString *)aKey count:(int)aCount {
    NSZone *zone = [self zone];
    [self release];
    NSParameterAssert([aClass isEqual:[BibAuthor class]] || [aClass isEqual:[NSString class]]);
    id aName = [aClass isEqual:[BibAuthor class]] ? [BibAuthor emptyAuthor] : @"";
    return [[BDSKEmptyGroup allocWithZone:zone] initWithName:aName key:aKey count:aCount];
}

// designated initializer
- (id)initWithName:(id)aName key:(NSString *)aKey count:(int)aCount {
    if (self = [super init]) {
        key = [aKey copy];
        name = [aName copy];
        count = aCount;
        hasEditableName = YES;
    }
    return self;
}

// NSCoding protocol

- (id)initWithCoder:(NSCoder *)decoder {
	if (self = [super init]) {
		name = [[decoder decodeObjectForKey:@"name"] retain];
		key = [[decoder decodeObjectForKey:@"key"] retain];
		count = [decoder decodeIntForKey:@"count"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:name forKey:@"name"];
	[coder encodeObject:key forKey:@"key"];
	[coder encodeInt:count forKey:@"count"];
}

// NSCopying protocol

- (id)copyWithZone:(NSZone *)aZone {
	id copy = [[[self class] allocWithZone:aZone] initWithName:name key:key count:count];
	return copy;
}

- (void)dealloc {
    [key release];
    [name release];
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
	if (self == other)
		return YES;
	if (![other isMemberOfClass:[self class]]) 
		return NO;
	// we don't care about the count for identification
	return (([[self key] isEqualToString:[other key]] || ([self key] == nil && [other key] == nil)) &&
			[[self name] isEqual:[(BDSKGroup *)other name]]);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@\tname=\"%@\"\t key=\"%@\"\t count=%d", [super description], name, key, count];
}

// accessors

- (id)name {
    return [[name retain] autorelease];
}

- (NSString *)key {
    return [[key retain] autorelease];
}

- (int)count {
    return count;
}

- (void)setCount:(int)newCount {
	count = newCount;
}

// "static" accessors

- (NSImage *)icon {
	return [NSImage smallImageNamed:@"genericFolderIcon"];
}

- (BOOL)isSmart {
	return NO;
}

- (BOOL)isShared {
	return NO;
}

// custom accessors

- (NSString *)stringValue {
    return [[self name] description];
}

- (NSNumber *)numberValue {
	return [NSNumber numberWithInt:count];
}

// comparisons

- (NSComparisonResult)nameCompare:(BDSKGroup *)otherGroup {
    return [[self name] sortCompare:[otherGroup name]];
}

- (NSComparisonResult)countCompare:(BDSKGroup *)otherGroup {
	return [[self numberValue] compare:[otherGroup numberValue]];
}

- (BOOL)containsItem:(BibItem *)item {
	if (key == nil)
		return YES;
	return [item isContainedInGroupNamed:name forField:key];
}

- (BOOL)hasEditableName {
    return hasEditableName;
}

- (void)setEditableName:(BOOL)flag {
    hasEditableName = flag;
}

@end


@implementation BDSKAllPublicationsGroup

static NSString *BDSKAllPublicationsLocalizedString = nil;

+ (void)initialize{
    OBINITIALIZE;
    BDSKAllPublicationsLocalizedString = [NSLocalizedString(@"All Publications", @"group name for all pubs") copy];
}

- (id)init {
	self = [super initWithName:BDSKAllPublicationsLocalizedString key:nil count:0];
    return self;
}

- (NSImage *)icon {
    // this icon looks better than the one we get from +[NSImage imageNamed:@"FolderPenIcon"] or smallImageNamed:
    static NSImage *image = nil;
    if(nil == image)
        image = [[[NSWorkspace sharedWorkspace] iconForFile:[[NSBundle mainBundle] bundlePath]] copy];
    
	return image;
}

- (BOOL)hasEditableName {
    return NO;
}
 
@end

@implementation BDSKEmptyGroup

- (NSImage *)icon {
    static NSImage *image = nil;
    if(image == nil){
        image = [[NSImage alloc] initWithSize:NSMakeSize(16, 16)];
        NSImage *genericImage = [NSImage smallImageNamed:@"genericFolderIcon"];
        NSImage *questionMark = [NSImage iconWithSize:NSMakeSize(12, 12) forToolboxCode:kQuestionMarkIcon];
        unsigned i;
        [image lockFocus];
        [genericImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:1];
        // hack to make the question mark dark enough to be visible
        for(i = 0; i < 3; i++)
            [questionMark compositeToPoint:NSMakePoint(3, 1) operation:NSCompositeSourceOver];
        [image unlockFocus];
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

- (BOOL)hasEditableName {
    return NO;
}

@end

@implementation BDSKSmartGroup

// old designated initializer
- (id)initWithName:(id)aName count:(int)aCount {
    BDSKFilter *aFilter = [[BDSKFilter alloc] init];
	self = [self initWithName:aName count:aCount filter:aFilter];
	[aFilter release];
    return self;
}

// designated initializer
- (id)initWithName:(id)aName count:(int)aCount filter:(BDSKFilter *)aFilter {
    if (self = [super initWithName:aName key:nil count:aCount]) {
        filter = [aFilter copy];
		undoManager = nil;
		[filter setUndoManager:nil];
    }
    return self;
}

- (id)initWithFilter:(BDSKFilter *)aFilter {
	NSString *aName = nil;
	if ([[aFilter conditions] count] > 0)
		aName = [[[aFilter conditions] objectAtIndex:0] value];
	if ([NSString isEmptyString:aName])
		aName = NSLocalizedString(@"Smart Group", @"Smart group");
	self = [self initWithName:aName count:0 filter:aFilter];
	return self;
}

// NSCoding protocol

- (id)initWithCoder:(NSCoder *)decoder {
	if (self = [super initWithCoder:decoder]) {
		filter = [[decoder decodeObjectForKey:@"filter"] retain];
		undoManager = nil;
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[super encodeWithCoder:coder];
	[coder encodeObject:filter forKey:@"filter"];
}

// NSCopying protocol

- (id)copyWithZone:(NSZone *)aZone {
	id copy = [[[self class] allocWithZone:aZone] initWithName:name count:count filter:filter];
	return copy;
}

- (void)dealloc {
	[[self undoManager] removeAllActionsWithTarget:self];
    [undoManager release];
    [filter release];
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
	if ([super isEqual:other])
		return [[self filter] isEqual:[(BDSKSmartGroup *)other filter]];
	else return NO;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ filter={ %@ }", [super description], filter];
}

// "static" properties

- (BOOL)isSmart {
	return YES;
}

- (NSImage *)icon {
	return [NSImage smallImageNamed:@"smartFolderIcon"];
}

// accessors

- (void)setName:(id)newName {
    if (name != newName) {
		[(BDSKSmartGroup *)[[self undoManager] prepareWithInvocationTarget:self] setName:name];
        [name release];
        name = [newName retain];
    }
}

- (BDSKFilter *)filter {
    return [[filter retain] autorelease];
}

- (void)setFilter:(BDSKFilter *)newFilter {
    if (filter != newFilter) {
		[[[self undoManager] prepareWithInvocationTarget:self] setFilter:filter];
        [filter release];
        filter = [newFilter copy];
		[filter setUndoManager:undoManager];
    }
}

- (NSUndoManager *)undoManager {
    return undoManager;
}

- (void)setUndoManager:(NSUndoManager *)newUndoManager {
    if (undoManager != newUndoManager) {
        [undoManager release];
        undoManager = [newUndoManager retain];
		[filter setUndoManager:undoManager];
    }
}

- (BOOL)containsItem:(BibItem *)item {
	return [filter testItem:item];
}

- (NSArray *)filterItems:(NSArray *)items {
	NSArray *filteredItems = [filter filterItems:items];
	[self setCount:[filteredItems count]];
	return filteredItems;
}

@end

@implementation BDSKSharedGroup

- (id)initWithService:(NSNetService *)aService;
{
    NSParameterAssert(aService != nil);
    if(self = [super initWithName:@"" key:@"" count:0]){
        service = [aService retain];
        [service resolveWithTimeout:5.0];

        data = [[NSMutableData alloc] initWithCapacity:10^6];
        publications = nil;
        downloadComplete = NO;
        
        NSInputStream *istream;
        [service getInputStream:&istream outputStream:NULL];
        [istream setDelegate:self];
        [istream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [istream open];
    }
    
    return self;
}

- (void)dealloc
{
    [service release];
    [data release];
    [publications release];
    [super dealloc];
}

- (NSString *)name
{
    NSString *theName = [service name];
    return theName ? theName : [NSString stringWithFormat:@"<%@ %p>", [self class], self];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p>: {\n\tdownload complete: %@\n\tdata length: %d\n\tname: %@\nservice: %@\n }", [self class], self, (downloadComplete ? @"yes" : @"no"), [data length], [self name], service];
}

- (NSArray *)publications
{
    if (publications == nil && downloadComplete == YES && [data length] != 0)
        publications = [[NSKeyedUnarchiver unarchiveObjectWithData:data] retain];
    return publications;
}


- (BOOL)containsItem:(BibItem *)item {
    return [[self publications] containsObject:item];
}

- (NSNetService *)service { return service; }

- (BOOL)isShared { return YES; }

- (BOOL)hasEditableName { return NO; }

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)event
{
    switch(event){
        case NSStreamEventHasBytesAvailable:
            // compiler barfs on the next line
            [(id)nil release];
            uint8_t readBuffer[4096];
            int amountRead = 0;
            NSInputStream *is = (NSInputStream *)aStream;
            amountRead = [is read:readBuffer maxLength:4096];
            [data appendBytes:readBuffer length:amountRead];
            break;
        case NSStreamEventEndEncountered:
            [(NSInputStream *)aStream close];
            downloadComplete = YES;
            [self setCount:[[self publications] count]];
            break;
        default:
            break;
    }
}

@end



#pragma mark NSString category for KVC

@interface NSString (BDSKGroup) @end

// this exists so we can use valueForKey: in the BDSKGroupCell
@implementation NSString (BDSKGroup)
- (NSString *)stringValue { return self; }
- (id)icon { return nil; }
// OmniFoundation implements numberValue for us
- (int)count { return [[self numberValue] intValue]; }
@end

