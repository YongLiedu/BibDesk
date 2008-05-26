//
//  BDSKSharedGroup.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/03/06.
/*
 This software is Copyright (c) 2006-2008
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

#import "BDSKSharedGroup.h"
#import "BDSKSharingClient.h"
#import "BDSKOwnerProtocol.h"
#import "BDSKPasswordController.h"
#import "NSArray_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKMacroResolver.h"
#import "BDSKItemSearchIndexes.h"


@implementation BDSKSharedGroup

#pragma mark Class methods

// Cached icons

static NSImage *lockedIcon = nil;
static NSImage *unlockedIcon = nil;

+ (NSImage *)icon{
    return [NSImage imageNamed:@"sharedFolderIcon"];
}

+ (NSImage *)lockedIcon {
    if(lockedIcon == nil){
        NSRect iconRect = NSMakeRect(0.0, 0.0, 16.0, 16.0);
        NSRect badgeRect = NSMakeRect(7.0, 0.0, 11.0, 11.0);
        NSImage *image = [[NSImage alloc] initWithSize:iconRect.size];
        NSImage *badge = [NSImage imageNamed:@"SmallLock_Locked"];
        NSSize srcSize = [[self icon] size];
        
        [image lockFocus];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [[self icon] drawInRect:iconRect fromRect:NSMakeRect(0, 0, srcSize.width, srcSize.height) operation:NSCompositeSourceOver  fraction:1.0];
        [badge drawInRect:badgeRect fromRect:iconRect operation:NSCompositeSourceOver  fraction:1.0];
        [image unlockFocus];
        
        lockedIcon = image;
    }
    return lockedIcon;
}

+ (NSImage *)unlockedIcon {
    if(unlockedIcon == nil){
        NSRect iconRect = NSMakeRect(0.0, 0.0, 16.0, 16.0);
        NSRect badgeRect = NSMakeRect(6.0, 0.0, 11.0, 11.0);
        NSImage *image = [[NSImage alloc] initWithSize:iconRect.size];
        NSImage *badge = [NSImage imageNamed:@"SmallLock_Unlocked"];
        NSSize srcSize = [[self icon] size];
        
        [image lockFocus];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [[self icon] drawInRect:iconRect fromRect:NSMakeRect(0, 0, srcSize.width, srcSize.height) operation:NSCompositeSourceOver  fraction:1.0];
        [badge drawInRect:badgeRect fromRect:iconRect operation:NSCompositeSourceOver  fraction:1.0];
        [image unlockFocus];
        
        unlockedIcon = image;
    }
    return unlockedIcon;
}

#pragma mark Init and dealloc

- (id)initWithClient:(BDSKSharingClient *)aClient;
{
    NSParameterAssert(aClient != nil);
    if(self = [super initWithName:[aClient name] count:0]){

        publications = nil;
        macroResolver = [[BDSKMacroResolver alloc] initWithOwner:self];
        needsUpdate = YES;
        searchIndexes = [[BDSKItemSearchIndexes alloc] init];
        client = [aClient retain];
        
        [self handleClientUpdatedNotification:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
               selector:@selector(handleClientUpdatedNotification:)
	               name:BDSKSharingClientUpdatedNotification
                 object:client];
    }
    
    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [client release];
    [publications release];
    [macroResolver release];
    [searchIndexes release];
    [super dealloc];
}

- (id)initWithCoder:(NSCoder *)aCoder
{
    [NSException raise:BDSKUnimplementedException format:@"Instances of %@ do not conform to NSCoding", [self class]];
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [NSException raise:BDSKUnimplementedException format:@"Instances of %@ do not conform to NSCoding", [self class]];
}

// Logging

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@ %p>: {\n\tneeds update: %@\n\tname: %@\n }", [self class], self, (needsUpdate ? @"yes" : @"no"), name];
}

#pragma mark Accessors

- (BDSKSharingClient *)client {
    return client;
}

- (BDSKPublicationsArray *)publications;
{
    if([self isRetrieving] == NO && ([self needsUpdate] == YES || publications == nil)){
        // let the server get the publications asynchronously
        [client retrievePublications]; 
        
        // use this to notify the tableview to start the progress indicators
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"succeeded"];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharedGroupUpdatedNotification object:self userInfo:userInfo];
    }
    // this will likely be nil the first time
    return publications;
}

- (void)setPublications:(NSArray *)newPublications;
{
    if(newPublications != publications){
        [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:nil];
        [publications release];
        publications = newPublications == nil ? nil : [[BDSKPublicationsArray alloc] initWithArray:newPublications];
        [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:self];
        [searchIndexes resetWithPublications:publications];
        if (publications == nil)
            [macroResolver removeAllMacros];
    }
    
    [self setCount:[publications count]];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:(publications != nil)] forKey:@"succeeded"];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSharedGroupUpdatedNotification object:self userInfo:userInfo];
}


- (BDSKMacroResolver *)macroResolver { return macroResolver; }

- (NSUndoManager *)undoManager { return nil; }

- (NSURL *)fileURL { return nil; }

- (NSString *)documentInfoForKey:(NSString *)key { return nil; }

- (BOOL)isDocument { return NO; }

- (BOOL)isRetrieving { return [client isRetrieving]; }

- (BOOL)failedDownload { return [client failedDownload]; }

- (BOOL)needsUpdate { return [client needsUpdate]; }

- (void)setNeedsUpdate:(BOOL)flag { needsUpdate = flag; }

// BDSKGroup overrides

- (NSImage *)icon {
    if([client needsAuthentication])
        return (publications == nil) ? [[self class] lockedIcon] : [[self class] unlockedIcon];
    else
        return [[self class] icon];
}

- (BOOL)isShared { return YES; }

- (BOOL)isExternal { return YES; }

- (BOOL)containsItem:(BibItem *)item {
    // calling [self publications] will repeatedly reschedule a retrieval, which is undesirable if the user canceled a password; containsItem is called very frequently
    NSArray *pubs = [publications retain];
    BOOL rv = [pubs containsObject:item];
    [pubs release];
    return rv;
}

- (BOOL)isEqual:(id)other { return self == other; }

- (unsigned int)hash {
    return( ((unsigned int) self >> 4) | (unsigned int) self << (32 - 4));
}

- (BDSKItemSearchIndexes *)searchIndexes {
    return searchIndexes;
}

#pragma mark notification handlers

- (void)handleClientUpdatedNotification:(NSNotification *)notification {
    NSString *key = [[notification userInfo] objectForKey:@"key"];
    if ([key isEqualToString:@"archivedPublications"] || notification == nil) {
        NSData *archive = [client archivedPublications];
        NSArray *pubs = nil;
        if (archive) {
            [BDSKComplexString setMacroResolverForUnarchiving:[self macroResolver]];
            pubs = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
            [BDSKComplexString setMacroResolverForUnarchiving:nil];
        }
        [self setPublications:pubs];
    } else if ([key isEqualToString:@"archivedMacros"]) {
        NSData *archive = [client archivedMacros];
        NSDictionary *macros = nil;
        if (archive) {
            [BDSKComplexString setMacroResolverForUnarchiving:[self macroResolver]];
            macros = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
            [BDSKComplexString setMacroResolverForUnarchiving:nil];
        }
        NSEnumerator *macroEnum = [macros keyEnumerator];
        NSString *macro;
        while(macro = [macroEnum nextObject])
            [[self macroResolver] setMacroDefinition:[macros objectForKey:macro] forMacro:macro];
    }
}

@end
