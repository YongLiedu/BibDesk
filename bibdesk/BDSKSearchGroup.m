//
//  BDSKSearchGroup.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/23/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BDSKSearchGroup.h"
#import "BDSKEntrezGroupServer.h"
#import "BDSKZoomGroupServer.h"
#import "BDSKMacroResolver.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKPublicationsArray.h"
#import "BDSKServerInfo.h"
#import "BDSKItemSearchIndexes.h"
#import "BDSKISIGroupServer.h"
#import "BDSKDBLPGroupServer.h"
#import "BDSKGroup+Scripting.h"
#import "BibItem.h"

NSString *BDSKSearchGroupEntrez = @"entrez";
NSString *BDSKSearchGroupZoom = @"zoom";
NSString *BDSKSearchGroupISI = @"isi";
NSString *BDSKSearchGroupDBLP = @"dblp";

@implementation BDSKSearchGroup

// old designated initializer
- (id)initWithName:(NSString *)aName count:(NSInteger)aCount;
{
    // ignore the name, because if this is called it's a dummy name anyway
    NSString *aType = BDSKSearchGroupEntrez;
    return [self initWithType:aType serverInfo:[BDSKServerInfo defaultServerInfoWithType:aType] searchTerm:nil];
}

// designated initializer
- (id)initWithType:(NSString *)aType serverInfo:(BDSKServerInfo *)info searchTerm:(NSString *)string;
{
    NSString *aName = (([info name] ?: [info database]) ?: string) ?: NSLocalizedString(@"Empty", @"Name for empty search group");
    if (self = [super initWithName:aName count:0]) {
        if (aType == nil || info == nil) {
            [self release];
            self = nil;
        } else {
            type = [aType copy];
            searchTerm = [string copy];
            history = nil;
            publications = nil;
            macroResolver = [[BDSKMacroResolver alloc] initWithOwner:self];
            searchIndexes = [[BDSKItemSearchIndexes alloc] init];
            [self resetServerWithInfo:info];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
        }
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)groupDict {
    NSString *aType = [groupDict objectForKey:@"type"];
    NSString *aSearchTerm = [groupDict objectForKey:@"search term"];
    NSArray *aHistory = [groupDict objectForKey:@"history"];
    BDSKServerInfo *serverInfo = [[BDSKServerInfo alloc] initWithType:aType dictionary:groupDict];
    
    if (self = [self initWithType:aType serverInfo:serverInfo searchTerm:aSearchTerm]) {
        [self setHistory:aHistory];
    }
    [serverInfo release];

    NSAssert2([groupDict objectForKey:@"class"] == nil || [NSClassFromString([groupDict objectForKey:@"class"]) isSubclassOfClass:[self class]], @"attempt to instantiate %@ instead of %@", [self class], [groupDict objectForKey:@"class"]);
    return self;
}

- (id)initWithURL:(NSURL *)bdsksearchURL {
    BDSKPRECONDITION([[bdsksearchURL scheme] isEqualToString:@"x-bdsk-search"]);
    
    NSString *aHost = [[bdsksearchURL host] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *aPort = [[bdsksearchURL port] stringValue];
    NSString *path = [bdsksearchURL path];
    NSString *aDatabase = [([path hasPrefix:@"/"] ? [path substringFromIndex:1] : path ?: @"") stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *aName = [[bdsksearchURL parameterString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ?: aDatabase;
    NSString *query = [bdsksearchURL query];
    NSString *aSearchTerm = nil;
    NSString *aType = BDSKSearchGroupZoom;
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    
    [options setValue:[bdsksearchURL password] forKey:@"password"];
    [options setValue:[bdsksearchURL user] forKey:@"username"];
   
    if (aPort == nil) {
        if ([aHost caseInsensitiveCompare:BDSKSearchGroupEntrez])
            aType = BDSKSearchGroupEntrez;
        else if ([aHost caseInsensitiveCompare:BDSKSearchGroupISI])
            aType = BDSKSearchGroupISI;
        else if ([aHost caseInsensitiveCompare:BDSKSearchGroupDBLP])
            aType = BDSKSearchGroupDBLP;
    }
    
    for (query in [query componentsSeparatedByString:@"&"]) {
        NSUInteger idx = [query rangeOfString:@"="].location;
        if (idx != NSNotFound && idx > 0) {
            NSString *key = [query substringToIndex:idx];
            NSString *value = [[query substringFromIndex:idx + 1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            if ([key caseInsensitiveCompare:@"searchTerm"] == NSOrderedSame || [key caseInsensitiveCompare:@"term"] == NSOrderedSame) {
                aSearchTerm = value;
            } else if ([key caseInsensitiveCompare:@"name"] == NSOrderedSame) {
                aName = value;
            } else if ([key caseInsensitiveCompare:@"database"] == NSOrderedSame || [key caseInsensitiveCompare:@"db"] == NSOrderedSame) {
                aDatabase = value;
            } else {
                if ([key caseInsensitiveCompare:@"password"] == NSOrderedSame) {
                    key = @"password";
                } else if ([key caseInsensitiveCompare:@"username"] == NSOrderedSame || [key caseInsensitiveCompare:@"user"] == NSOrderedSame) {
                    key = @"username";
                } else if ([key caseInsensitiveCompare:@"recordSyntax"] == NSOrderedSame || [key caseInsensitiveCompare:@"syntax"] == NSOrderedSame) {
                    key = @"recordSyntax";
                } else if ([key caseInsensitiveCompare:@"resultEncoding"] == NSOrderedSame || [key caseInsensitiveCompare:@"encoding"] == NSOrderedSame) {
                    key = @"resultEncoding";
                } else if ([key caseInsensitiveCompare:@"removeDiacritics"] == NSOrderedSame) {
                    key = @"removeDiacritics";
                    if ([value boolValue])
                        value = @"YES";
                    else continue;
                }
                [options setValue:value forKey:key];
            }
        }
    }
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:7];
    [dictionary setValue:aType forKey:@"type"];
    [dictionary setValue:aName forKey:@"name"];
    [dictionary setValue:aDatabase forKey:@"database"];
    [dictionary setValue:aSearchTerm forKey:@"search term"];
    if ([aType isEqualToString:BDSKSearchGroupZoom]) {
        [dictionary setValue:aHost forKey:@"host"];
        [dictionary setValue:aPort forKey:@"port"];
        [dictionary setValue:options forKey:@"options"];
    }
    
    return [self initWithDictionary:dictionary];
}

- (NSDictionary *)dictionaryValue {
    NSMutableDictionary *groupDict = [[[self serverInfo] dictionaryValue] mutableCopy];
    
    [groupDict setValue:[self type] forKey:@"type"];
    [groupDict setValue:[self searchTerm] forKey:@"search term"];
    [groupDict setValue:[self history] forKey:@"history"];
    [groupDict setValue:NSStringFromClass([self class]) forKey:@"class"];
    
    return [groupDict autorelease];
}


- (id)copyWithZone:(NSZone *)aZone {
	return [[[self class] allocWithZone:aZone] initWithType:type serverInfo:[self serverInfo] searchTerm:searchTerm];
}

- (void)dealloc
{
    [server terminate];
    [server release];
    server = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [publications makeObjectsPerformSelector:@selector(setOwner:) withObject:nil];
    [publications release];
    publications = nil;
    [type release];
    type = nil;
    [searchTerm release];
    searchTerm = nil;
    [searchIndexes release];
    searchIndexes = nil;
    [super dealloc];
}

- (BOOL)isEqual:(id)other { return self == other; }

- (NSUInteger)hash {
    return( ((NSUInteger) self >> 4) | (NSUInteger) self << (32 - 4));
}

// Logging

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@ %p>: {\n\tis downloading: %@\n\tname: %@\ntype: %@\nserverInfo: %@\n }", [self class], self, ([self isRetrieving] ? @"yes" : @"no"), [self name], [self type], [self serverInfo]];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification{
    [server terminate];
    [server release];
    server = nil;
}

#pragma mark BDSKGroup overrides

// note that pointer equality is used for these groups, so names can overlap, and users can have duplicate searches

- (NSImage *)icon { return [NSImage imageNamed:@"searchGroup"]; }

- (NSString *)name {
    return [NSString isEmptyString:[self searchTerm]] ? NSLocalizedString(@"Empty", @"Name for empty search group") : [self searchTerm];
}

- (void)setName:(NSString *)newName {}

- (NSString *)toolTip {
    return [NSString stringWithFormat:@"%@: %@", [[self serverInfo] name] ?: @"", [self name]];
}

- (BOOL)isSearch { return YES; }

- (BOOL)isExternal { return YES; }

- (BOOL)isEditable { return YES; }

- (BOOL)hasEditableName { return NO; }

- (BOOL)isRetrieving { return [server isRetrieving]; }

- (BOOL)failedDownload { return [server failedDownload]; }

- (NSString *)errorMessage { return [server errorMessage]; }

- (BOOL)containsItem:(BibItem *)item {
    return [publications containsObject:item];
}

#pragma mark BDSKOwner protocol

- (BDSKPublicationsArray *)publicationsWithoutUpdating { return publications; }
 
- (BDSKPublicationsArray *)publications;
{
    if([self isRetrieving] == NO && publications == nil && [NSString isEmptyString:[self searchTerm]] == NO){
        // get initial batch of publications
        [server retrievePublications];
        
        // use this to notify the tableview to start the progress indicators
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"succeeded"];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSearchGroupUpdatedNotification object:self userInfo:userInfo];
    }
    // this posts a notification that the publications of the group changed, forcing a redisplay of the table cell
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
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSearchGroupUpdatedNotification object:self userInfo:userInfo];
}

- (void)addPublications:(NSArray *)newPublications;
{    
    if(newPublications != publications && newPublications != nil){
        
        if (publications == nil)
            publications = [[BDSKPublicationsArray alloc] initWithArray:newPublications];
        else 
            [publications addObjectsFromArray:newPublications];
        [newPublications makeObjectsPerformSelector:@selector(setOwner:) withObject:self];
        [searchIndexes addPublications:newPublications];
    }
    
    [self setCount:[publications count]];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:(newPublications != nil)] forKey:@"succeeded"];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSearchGroupUpdatedNotification object:self userInfo:userInfo];
}

- (BDSKMacroResolver *)macroResolver { return macroResolver; }

// search groups are not saved, so we don't register undo with the document's undo manager
- (NSUndoManager *)undoManager { return nil; }

- (NSURL *)fileURL { return nil; }

- (NSString *)documentInfoForKey:(NSString *)key { return nil; }

- (BOOL)isDocument { return NO; }

- (BDSKItemSearchIndexes *)searchIndexes { return searchIndexes; }

#pragma mark Searching

- (void)resetServerWithInfo:(BDSKServerInfo *)info {
    [server terminate];
    [server release];
    Class serverClass = Nil;
    if ([type isEqualToString:BDSKSearchGroupEntrez])
        serverClass = [BDSKEntrezGroupServer class];
    else if ([type isEqualToString:BDSKSearchGroupZoom])
        serverClass = [BDSKZoomGroupServer class];
    else if ([type isEqualToString:BDSKSearchGroupISI])
        serverClass = [BDSKISIGroupServer class];
    else if ([type isEqualToString:BDSKSearchGroupDBLP])
        serverClass = [BDSKDBLPGroupServer class];
    else
        BDSKASSERT_NOT_REACHED("unknown search group type");
    server = [[serverClass alloc] initWithGroup:self serverInfo:info];
}

- (void)search;
{
    if ([self isRetrieving])
        return;
    
    // call this also for empty searchTerm, so the server can reset itself
    [server retrievePublications];
    
    // use this to notify the tableview to start the progress indicators and disable the button
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"succeeded"];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSearchGroupUpdatedNotification object:self userInfo:userInfo];
}

- (void)reset;
{
    if ([self isRetrieving])
        [server stop];
    
    [server setNumberOfAvailableResults:0];
    [server setNumberOfFetchedResults:0];
    [self setPublications:[NSArray array]];
}

- (NSFormatter *)searchStringFormatter { return [server searchStringFormatter]; }

#pragma mark Accessors

- (NSString *)type { return type; }

- (BDSKServerInfo *)serverInfo { return [server serverInfo]; }

- (void)setServerInfo:(BDSKServerInfo *)info;
{
    [(BDSKSearchGroup *)[[self undoManager] prepareWithInvocationTarget:self] setServerInfo:[self serverInfo]];
    NSString *newType = [info type];
    if([newType isEqualToString:type] == NO){
        [type release];
        type = [newType copy];
        [self resetServerWithInfo:info];
    } else
        [server setServerInfo:info];
    [self reset];
}

- (void)setSearchTerm:(NSString *)aTerm;
{
    // should this be undoable?
    
    if ([aTerm isEqualToString:searchTerm] == NO) {
        [searchTerm autorelease];
        searchTerm = [aTerm copy];
        
        [self reset];
        [self search];
    }
}

- (NSString *)searchTerm { return searchTerm; }

- (void)setHistory:(NSArray *)newHistory;
{
    if (history != newHistory) {
        [history release];
        history = [newHistory copy];
    }
}

- (NSArray *)history {return history; }

- (void)setNumberOfAvailableResults:(NSInteger)value;
{
    [server setNumberOfAvailableResults:value];
}

- (NSInteger)numberOfAvailableResults { return [server numberOfAvailableResults]; }

- (BOOL)hasMoreResults;
{
    return [server numberOfAvailableResults] > [server numberOfFetchedResults];
}

- (NSURL *)bdsksearchURL {
    NSMutableString *string = [NSMutableString stringWithString:@"x-bdsk-search://"];
    BDSKServerInfo *serverInfo = [self serverInfo];
    NSString *password = [serverInfo password];
    NSString *username = [serverInfo username];
    if ([serverInfo isZoom]) {
        if (username) {
            [string appendString:[username stringByAddingPercentEscapesIncludingReserved]];
            if (password)
                [string appendFormat:@":%@", [password stringByAddingPercentEscapesIncludingReserved]];
           [string appendString:@"@"];
        }
        [string appendFormat:@"%@:%@", [[serverInfo host] stringByAddingPercentEscapesIncludingReserved], [serverInfo port]];
    } else {
        [string appendString:type];
    }
    [string appendFormat:@"/%@", [[serverInfo database] stringByAddingPercentEscapesIncludingReserved]];
    [string appendFormat:@";%@", [[serverInfo name] stringByAddingPercentEscapesIncludingReserved]];
    if ([serverInfo isZoom]) {
        for (NSString *key in [serverInfo options]) {
            NSString *value = [[serverInfo options] objectForKey:key];
            if ([key isEqualToString:@"removeDiacritics"])
                value = [serverInfo removeDiacritics] ? @"1" : @"0";
            else if (username && ([key isEqualToString:@"username"] || [key isEqualToString:@"password"]))
                continue;
            [string appendFormat:@"&%@=%@", key, [value stringByAddingPercentEscapesIncludingReserved]];
        }
    }
    return [NSURL URLWithString:string];
}

@end
