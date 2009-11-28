//
//  BDSKExternalGroup.m
//  Bibdesk
//
//  Created by Christiaan on 11/28/09.
/*
 This software is Copyright (c) 2009
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

#import "BDSKExternalGroup.h"
#import "BDSKOwnerProtocol.h"
#import "BibItem.h"
#import "BDSKPublicationsArray.h"
#import "BDSKMacroResolver.h"
#import "BDSKItemSearchIndexes.h"


@implementation BDSKExternalGroup

// old designated initializer
- (id)initWithName:(NSString *)aName count:(NSInteger)aCount {
    return [self initWithName:aName];
}

- (id)initWithName:(NSString *)aName {
    NSAssert(aName != nil, @"External group requires a name");

    if (self = [super initWithName:aName count:0]) {
        publications = nil;
        macroResolver = [[BDSKMacroResolver alloc] initWithOwner:self];
        searchIndexes = [BDSKItemSearchIndexes new];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aCoder {
    [NSException raise:BDSKUnimplementedException format:@"Instances of %@ do not conform to NSCoding", [self class]];
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [NSException raise:BDSKUnimplementedException format:@"Instances of %@ do not conform to NSCoding", [self class]];
}

- (id)copyWithZone:(NSZone *)aZone {
	return [[[self class] allocWithZone:aZone] initWithName:name];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:nil];
    [publications release];
    publications = nil;
    [macroResolver release];
    macroResolver = nil;
    [searchIndexes release];
    searchIndexes = nil;
    [super dealloc];
}

- (BOOL)isEqual:(id)other { return self == other; }

- (NSUInteger)hash { return BDSKHash(self); }

#pragma mark BDSKGroup overrides

- (BOOL)isExternal { return YES; }

- (BOOL)containsItem:(BibItem *)item { return [publications containsObject:item]; }

#pragma mark Publications

- (BDSKPublicationsArray *)publicationsWithoutUpdating { return publications; }
 
- (BDSKPublicationsArray *)publications {
    if ([self isRetrieving] == NO && [self shouldRetrievePublications]) {
        // get the publications asynchronously if remote, synchronously if local
        [self retrievePublications]; 
        
        // use this to notify the tableview to start the progress indicators
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"succeeded"];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKExternalGroupUpdatedNotification object:self userInfo:userInfo];
    }
    return publications;
}

- (void)setPublications:(NSArray *)newPublications {
    if ([self isRetrieving])
        [self terminate];
    
    if (newPublications != publications) {
        [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:nil];
        [publications release];
        publications = newPublications == nil ? nil : [[BDSKPublicationsArray alloc] initWithArray:newPublications];
        [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:self];
        [searchIndexes resetWithPublications:publications];
        if (publications == nil)
            [macroResolver removeAllMacros];
    }
    
    [self setCount:[publications count]];
    
    if (BDSKExternalGroupUpdatedNotification) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:(newPublications != nil)] forKey:@"succeeded"];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKExternalGroupUpdatedNotification object:self userInfo:userInfo];
    }
}

- (void)addPublications:(NSArray *)newPublications {
    if (newPublications != publications && newPublications != nil) {
        if (publications == nil)
            publications = [[BDSKPublicationsArray alloc] initWithArray:newPublications];
        else 
            [publications addObjectsFromArray:newPublications];
        [newPublications makeObjectsPerformSelector:@selector(setOwner:) withObject:self];
        [searchIndexes addPublications:newPublications];
    }
    
    [self setCount:[publications count]];
    
    if (BDSKExternalGroupUpdatedNotification) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:(newPublications != nil)] forKey:@"succeeded"];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKExternalGroupUpdatedNotification object:self userInfo:userInfo];
    }
}

- (BOOL)shouldRetrievePublications { return publications == nil; }

- (void)retrievePublications {}

- (void)terminate {}

#pragma mark BDSKOwner protocol

- (BDSKMacroResolver *)macroResolver { return macroResolver; }

- (NSUndoManager *)undoManager { return nil; }

- (NSURL *)fileURL { return nil; }

- (NSString *)documentInfoForKey:(NSString *)key { return nil; }

- (BOOL)isDocument { return NO; }

- (BDSKItemSearchIndexes *)searchIndexes{ return searchIndexes; }

@end

#pragma mark -

@implementation BDSKMutableExternalGroup

- (void)dealloc {
    [errorMessage release];
    [super dealloc];
}

- (void)addPublications:(NSArray *)newPublications { [self doesNotRecognizeSelector:_cmd]; }

- (void)setName:(id)newName {
    if (name != newName) {
		[(BDSKMutableExternalGroup *)[[self undoManager] prepareWithInvocationTarget:self] setName:name];
        [name release];
        name = [newName retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupNameChangedNotification object:self];
    }
}

- (NSString *)errorMessage {
    return errorMessage;
}

- (void)setErrorMessage:(NSString *)newErrorMessage {
    if (errorMessage != newErrorMessage) {
        [errorMessage release];
        errorMessage = [newErrorMessage retain];
    }
}

- (NSUndoManager *)undoManager {
    return [document undoManager];
}

- (BOOL)hasEditableName { return YES; }

- (BOOL)isEditable { return YES; }

@end
