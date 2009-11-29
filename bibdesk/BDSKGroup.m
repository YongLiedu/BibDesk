//
//  BDSKGroup.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/11/05.
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

#import "BDSKGroup.h"
#import "BDSKParentGroup.h"
#import "BibItem.h"
#import "NSString_BDSKExtensions.h"
#import "CFString_BDSKExtensions.h"
#import "BDSKOwnerProtocol.h"
#import "BibDocument.h"
#import "BDSKMacroResolver.h"
#import "BDSKRuntime.h"


@implementation BDSKGroup

static NSArray *cellValueKeys = nil;
static NSArray *noCountCellValueKeys = nil;

+ (void)initialize {
    BDSKINITIALIZE;
    cellValueKeys = [[NSArray alloc] initWithObjects:@"stringValue", @"editingStringValue", @"numberValue", @"icon", @"isRetrieving", @"failedDownload", nil];
    noCountCellValueKeys = [[NSArray alloc] initWithObjects:@"stringValue", @"editingStringValue", @"icon", @"isRetrieving", @"failedDownload", nil];
}

// super's designated initializer
- (id)init {
    return [self initWithName:NSLocalizedString(@"Group", @"Default group name")];
}

// designated initializer
- (id)initWithName:(id)aName {
    if (self = [super init]) {
        name = [aName copy];
        count = 0;
        document = nil;
        uniqueID = (id)BDCreateUniqueString();
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)groupDict {
    NSString *aName = [[groupDict objectForKey:@"group name"] stringByUnescapingGroupPlistEntities];
    self = [self initWithName:aName];
    return self;
}

- (NSDictionary *)dictionaryValue {
    NSString *aName = [[self stringValue] stringByEscapingGroupPlistEntities];
    return [NSDictionary dictionaryWithObjectsAndKeys:aName, @"group name", nil];
}

// NSCoding protocol, should never be used

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        name = [[decoder decodeObjectForKey:@"name"] retain];
        count = [decoder decodeIntegerForKey:@"count"];
        uniqueID = (id)BDCreateUniqueString();
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:name forKey:@"name"];
    [coder encodeInteger:count forKey:@"count"];
}

// NSCopying protocol, may be used by the duplicate script command

- (id)copyWithZone:(NSZone *)aZone {
	return [[[self class] allocWithZone:aZone] initWithName:name];
}

- (void)dealloc {
    [name release];
    [uniqueID release];
    [super dealloc];
}

- (NSUInteger)hash {
    return [name hash];
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
    return [NSString stringWithFormat:@"%@<%p>: name=\"%@\",count=%ld", [self class], self, name, (long)count];
}

// accessors

- (NSString *)uniqueID {
    return uniqueID;
}

- (id)name {
    return name;
}

- (NSInteger)count {
    return count;
}

- (void)setCount:(NSInteger)newCount {
	count = newCount;
}

// "static" accessors

- (NSImage *)icon {
    BDSKRequestConcreteImplementation(self, _cmd);
	return nil;
}

- (BOOL)isParent { return NO; }

- (BOOL)isStatic { return NO; }

- (BOOL)isSmart { return NO; }

- (BOOL)isCategory { return NO; }

- (BOOL)isShared { return NO; }

- (BOOL)isURL { return NO; }

- (BOOL)isScript { return NO; }

- (BOOL)isSearch { return NO; }

- (BOOL)isExternal { return NO; }

- (BOOL)isValidDropTarget { return NO; }

- (BOOL)isNameEditable { return NO; }

- (BOOL)isEditable { return NO; }

- (BOOL)failedDownload { return NO; }

- (BOOL)isRetrieving { return NO; }

// custom accessors

- (NSString *)stringValue {
    return [[self name] description];
}

- (NSNumber *)numberValue {
	return [NSNumber numberWithInteger:[self count]];
}

- (NSString *)editingStringValue {
    return [[self name] description];
}

- (id)cellValue {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BDSKHideGroupCountKey])
        return [self dictionaryWithValuesForKeys:noCountCellValueKeys];
    else
        return [self dictionaryWithValuesForKeys:cellValueKeys];
}

- (NSString *)toolTip {
    return [self stringValue];
}

- (NSString *)errorMessage {
    return nil;
}

- (BDSKParentGroup *)parent {
    return parent;
}

- (void)setParent:(BDSKParentGroup *)newParent {
    parent = newParent;
}

- (BibDocument *)document{
    return document;
}

- (void)setDocument:(BibDocument *)newDocument{
    document = newDocument;
}

- (BDSKMacroResolver *)macroResolver{
    return [[self document] macroResolver];
}

// comparisons

- (NSComparisonResult)nameCompare:(BDSKGroup *)otherGroup {
    return [[self name] sortCompare:[otherGroup name]];
}

- (NSComparisonResult)countCompare:(BDSKGroup *)otherGroup {
	return [[self numberValue] compare:[otherGroup numberValue]];
}

- (BOOL)containsItem:(BibItem *)item { return NO; }

@end

#pragma mark -

@implementation BDSKLibraryGroup

static NSString *BDSKLibraryLocalizedString = nil;

+ (void)initialize{
    BDSKINITIALIZE;
    BDSKLibraryLocalizedString = [NSLocalizedString(@"Library", @"Group name for library") copy];
}

- (id)init {
	self = [super initWithName:BDSKLibraryLocalizedString];
    return self;
}

- (NSImage *)icon {
	return [NSImage imageNamed:@"libraryGroup"];
}

- (BOOL)containsItem:(BibItem *)item {
    return [[item owner] isEqual:[self document]];
}

- (BOOL)isEqual:(id)other { return self == other; }

- (NSUInteger)hash {
    return BDSKHash(self);
}

- (BOOL)isValidDropTarget { return YES; }

@end

#pragma mark -

@implementation BDSKMutableGroup

- (void)setName:(id)newName {
    if (name != newName) {
		[(BDSKMutableGroup *)[[self undoManager] prepareWithInvocationTarget:self] setName:name];
        [name release];
        name = [newName retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupNameChangedNotification object:self];
    }
}

- (NSUndoManager *)undoManager {
    return [document undoManager];
}

- (BOOL)isNameEditable { return YES; }

@end
