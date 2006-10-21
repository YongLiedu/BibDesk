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
#import "BibItem.h"
#import "NSString_BDSKExtensions.h"
#import <OmniBase/OBUtilities.h>


// a private subclass for the All Publication group
@interface BDSKAllPublicationsGroup : BDSKGroup @end


@implementation BDSKGroup

static unsigned currentUniqueID = 0;

// super's designated initializer
- (id)init {
	self = [self initWithName:NSLocalizedString(@"Group", @"Group") count:0];
    return self;
}

- (id)initWithAllPublications {
	NSZone *zone = [self zone];
	[[super init] release];
	self = [[BDSKAllPublicationsGroup allocWithZone:zone] init];
	return self;
}

// designated initializer
- (id)initWithName:(id)aName count:(int)aCount {
    if (self = [super init]) {
        uniqueID = ++currentUniqueID;
        name = [aName copy];
        count = aCount;
    }
    return self;
}

// NSCoding protocol, should never be used

- (id)initWithCoder:(NSCoder *)decoder {
    [NSException raise:NSInternalInconsistencyException format:@"Instances of %@ do not support NSCoding", [self class]];
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [NSException raise:NSInternalInconsistencyException format:@"Instances of %@ do not support NSCoding", [self class]];
}

// NSCopying protocol, may be used in -[NSCell setObjectValue:] at some point

- (id)copyWithZone:(NSZone *)aZone {
	return [self retain];
}

- (void)dealloc {
    [name release];
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
	if (self == other)
		return YES;
	if (![other isMemberOfClass:[self class]]) 
		return NO;
	// we don't care about the count for identification
	return [[self name] isEqual:[(BDSKGroup *)other name]];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@: name=\"%@\",count=%d", [self class], name, count];
}

// accessors

- (NSNumber *)uniqueID {
    return [NSNumber numberWithUnsignedInt:uniqueID];
}

- (id)name {
    return [[name retain] autorelease];
}

- (int)count {
    return count;
}

- (void)setCount:(int)newCount {
	count = newCount;
}

// "static" accessors

- (NSImage *)icon {
    OBRequestConcreteImplementation(self, _cmd);
	return nil;
}

- (BOOL)isStatic { return NO; }

- (BOOL)isSmart { return NO; }

- (BOOL)isCategory { return NO; }

- (BOOL)isShared { return NO; }

- (BOOL)isURL { return NO; }

- (BOOL)isScript { return NO; }

- (BOOL)isExternal { return NO; }

- (BOOL)isValidDropTarget { return YES; }

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
    return YES;
}

- (BOOL)hasEditableName {
    return YES;
}

- (BOOL)isEditable {
    return NO;
}

- (BOOL)failedDownload {
    return NO;
}


- (BOOL)isRetrieving {
    return NO;
}

@end

#pragma mark -

@implementation BDSKAllPublicationsGroup

static NSString *BDSKAllPublicationsLocalizedString = nil;

+ (void)initialize{
    OBINITIALIZE;
    BDSKAllPublicationsLocalizedString = [NSLocalizedString(@"Library", @"group name for all pubs") copy];
}

- (id)init {
	self = [super initWithName:BDSKAllPublicationsLocalizedString count:0];
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

#pragma mark NSString category for KVC

@interface NSString (BDSKGroup) @end

// this exists so we can use valueForKey: in the BDSKGroupCell
@implementation NSString (BDSKGroup)
- (NSString *)stringValue { return self; }
// OmniFoundation implements numberValue for us
- (int)count { return [[self numberValue] intValue]; }
@end

