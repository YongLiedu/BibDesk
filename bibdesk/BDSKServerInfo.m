//
//  BDSKServerInfo.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/30/06.
/*
 This software is Copyright (c) 2006-2009
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

#import "BDSKServerInfo.h"
#import "BDSKSearchGroup.h"
#import "NSString_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"

#define DEFAULT_NAME     NSLocalizedString(@"New Server", @"")
#define DEFAULT_DATABASE @"database" 
#define DEFAULT_HOST     @"host.domain.com"
#define DEFAULT_PORT     @"0"

// IMPORTANT WARNING:
// When anything changes about server infos, e.g. a new type is added, this should be carefully considered, as it has many consequences for data integrity and and the editing sheet.
// Assumptions are made in BDSKSearchGroup and BDSKSearchGroupSheetController.
// Currently, anything other than zoom is expected to have just a type, name, and database.
// Also when other validations are necessary, changing the type must make sure that the data validates properly for the new type, if necessary adding missing values.

@implementation BDSKServerInfo

+ (id)defaultServerInfoWithType:(NSString *)aType;
{
    BOOL isZoom = [aType isEqualToString:BDSKSearchGroupZoom];
    
    return [[[[self class] alloc] initWithType:aType
                                          name:DEFAULT_NAME
                                      database:DEFAULT_DATABASE
                                          host:isZoom ? DEFAULT_HOST : nil
                                          port:isZoom ? DEFAULT_PORT : nil
                                       options:isZoom ? [NSDictionary dictionary] : nil] autorelease];
}

- (id)initWithType:(NSString *)aType name:(NSString *)aName database:(NSString *)aDbase host:(NSString *)aHost port:(NSString *)aPort options:(NSDictionary *)opts;
{
    if (self = [super init]) {
        type = [aType copy];
        name = [aName copy];
        database = [aDbase copy];
        if ([self isEntrez] || [self isISI] || [self isDBLP]) {
            host = nil;
            port = nil;
            options = nil;
        } else if ([self isZoom]) {
            host = [aHost copy];
            port = [aPort copy];
            options = [opts mutableCopy];
        } else {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (id)initWithType:(NSString *)aType dictionary:(NSDictionary *)info;
{    
    self = [self initWithType:aType ?: [info objectForKey:@"type"]
                         name:[info objectForKey:@"name"]
                     database:[info objectForKey:@"database"]
                         host:[info objectForKey:@"host"]
                         port:[info objectForKey:@"port"]
                      options:[info objectForKey:@"options"]];
    return self;
}

- (id)copyWithZone:(NSZone *)aZone {
    id copy = [[BDSKServerInfo allocWithZone:aZone] initWithType:[self type] name:[self name] database:[self database] host:[self host] port:[self port] options:[self options]];
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)aZone {
    id copy = [[BDSKMutableServerInfo allocWithZone:aZone] initWithType:[self type] name:[self name] database:[self database] host:[self host] port:[self port] options:[self options]];
    return copy;
}

- (void)dealloc {
    [type release];
    [name release];
    [database release];
    [host release];
    [port release];
    [options release];
    [super dealloc];
}

static inline BOOL isEqualOrBothNil(id object1, id object2) {
    return (object1 == nil && object2 == nil) || [object1 isEqual:object2];
}

- (BOOL)isEqual:(id)other {
    BOOL isEqual = YES;
    // we don't compare the name, as that is just a label
    if ([self isKindOfClass:[BDSKServerInfo self]] == NO ||
        [[self type] isEqualToString:[(BDSKServerInfo *)other type]] == NO ||
        isEqualOrBothNil([self database], [other database]) == NO)
        isEqual = NO;
    else if ([self isZoom])
        isEqual = isEqualOrBothNil([self host], [other host]) && 
                  isEqualOrBothNil([self port], [(BDSKServerInfo *)other port]) && 
                  (isEqualOrBothNil([self options], [(BDSKServerInfo *)other options]) || ([[self options] count] == 0 && [[(BDSKServerInfo *)other options] count] == 0));
    return isEqual;
}

- (NSUInteger)hash {
    NSUInteger hash = [[self type] hash] + [[self database] hash];
    if ([self isZoom]) {
        hash += [[self host] hash] + [[self port] hash] + [[self password] hash];
        if ([options count])
            hash += [[self options] hash];
    }
    return hash;
}

- (NSDictionary *)dictionaryValue {
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:7];
    [info setValue:[self type] forKey:@"type"];
    [info setValue:[self name] forKey:@"name"];
    [info setValue:[self database] forKey:@"database"];
    if ([self isZoom]) {
        [info setValue:[self host] forKey:@"host"];
        [info setValue:[self port] forKey:@"port"];
        [info setValue:[self options] forKey:@"options"];
    }
    return info;
}

- (NSString *)type { return type; }

- (NSString *)name { return name; }

- (NSString *)database { return database; }

- (NSString *)host { return [self isZoom] ? host : nil; }

- (NSString *)port { return [self isZoom] ? port : nil; }

- (NSString *)password { return [[self options] objectForKey:@"password"]; }

- (NSString *)username { return [[self options] objectForKey:@"username"]; }

- (NSString *)recordSyntax { return [[self options] objectForKey:@"recordSyntax"]; }

- (NSString *)resultEncoding { return [[self options] objectForKey:@"resultEncoding"]; }

- (BOOL)removeDiacritics { return [[[self options] objectForKey:@"removeDiacritics"] boolValue]; }

- (NSDictionary *)options { return [self isZoom] ? options : nil; }

- (BOOL)isEntrez { return [[self type] isEqualToString:BDSKSearchGroupEntrez]; }
- (BOOL)isZoom { return [[self type] isEqualToString:BDSKSearchGroupZoom]; }
- (BOOL)isISI { return [[self type] isEqualToString:BDSKSearchGroupISI]; }
- (BOOL)isDBLP { return [[self type] isEqualToString:BDSKSearchGroupDBLP]; }

- (NSInteger)serverType {
    if ([self isEntrez])
        return BDSKServerTypeEntrez;
    if ([self isZoom])
        return BDSKServerTypeZoom;
    if ([self isISI])
        return BDSKServerTypeISI;
    if ([self isDBLP])
        return BDSKServerTypeDBLP;
    BDSKASSERT_NOT_REACHED("Unknown search type");
    return BDSKServerTypeEntrez;
}

@end


@implementation BDSKMutableServerInfo

+ (NSSet *)keyPathsForValuesAffectingServerType {
    return [NSSet setWithObjects:@"type", nil];
}

+ (NSSet *)keyPathsForValuesAffectingHost {
    return [NSSet setWithObjects:@"type", nil];
}

+ (NSSet *)keyPathsForValuesAffectingPort {
    return [NSSet setWithObjects:@"type", nil];
}

+ (NSSet *)keyPathsForValuesAffectingOptions {
    return [NSSet setWithObjects:@"type", nil];
}

+ (NSSet *)keyPathsForValuesAffectingPassword {
    return [NSSet setWithObjects:@"options", nil];
}

+ (NSSet *)keyPathsForValuesAffectingUsername {
    return [NSSet setWithObjects:@"options", nil];
}

+ (NSSet *)keyPathsForValuesAffectingRecordSyntax {
    return [NSSet setWithObjects:@"options", nil];
}

+ (NSSet *)keyPathsForValuesAffectingResultEncoding {
    return [NSSet setWithObjects:@"options", nil];
}

+ (NSSet *)keyPathsForValuesAffectingRemoveDiacritics {
    return [NSSet setWithObjects:@"options", nil];
}

// When changing the type, all data must be properly updated to be valid, taking into account the condition implict in the validation methods
- (void)setType:(NSString *)newType {
    if ([type isEqualToString:newType] == NO) {
        [type release];
        type = [newType retain];
        if ([self isZoom]) {
            if (host == nil)
                [self setHost:DEFAULT_HOST];
            if (port == nil)
                [self setPort:DEFAULT_PORT];
        }
    }
}

- (void)setName:(NSString *)newName;
{
    [name autorelease];
    name = [newName copy];
}

- (void)setDatabase:(NSString *)newDbase;
{
    [database autorelease];
    database = [newDbase copy];
}

- (void)setHost:(NSString *)newHost;
{
    [host autorelease];
    host = [newHost copy];
}

- (void)setPort:(NSString *)newPort;
{
    [port autorelease];
    port = [newPort copy];
}

- (void)setOptionValue:(id)value forKey:(NSString *)key {
    if (options)
        [options setValue:value forKey:key];
    else if (value)
        [self setOptions:[NSDictionary dictionaryWithObjectsAndKeys:value, key, nil]];
}

- (void)setPassword:(NSString *)newPassword;
{
    [self setOptionValue:newPassword forKey:@"password"];
}

- (void)setUsername:(NSString *)newUser;
{
    [self setOptionValue:newUser forKey:@"username"];
}

- (void)setRecordSyntax:(NSString *)newSyntax;
{
    [self setOptionValue:newSyntax forKey:@"recordSyntax"];
}

- (void)setResultEncoding:(NSString *)newEncoding;
{
    [self setOptionValue:newEncoding forKey:@"resultEncoding"];
}

- (void)setRemoveDiacritics:(BOOL)flag;
{
    [self setOptionValue:(flag ? @"YES" : nil) forKey:@"removeDiacritics"];
}

- (void)setOptions:(NSDictionary *)newOptions;
{
    [options autorelease];
    options = [newOptions mutableCopy];
}

- (BOOL)validateHost:(id *)value error:(NSError **)error {
    NSString *string = *value;
    if ([self isZoom]) {
        NSRange range = [string rangeOfString:@"://"];
        if(range.location != NSNotFound){
            // ZOOM gets confused when the host has a protocol
            string = [string substringFromIndex:NSMaxRange(range)];
        }
        // split address:port/dbase in components
        range = [string rangeOfString:@"/"];
        if(range.location != NSNotFound){
            [self setDatabase:[string substringFromIndex:NSMaxRange(range)]];
            string = [string substringToIndex:range.location];
        }
        range = [string rangeOfString:@":"];
        if(range.location != NSNotFound){
            [self setPort:[string substringFromIndex:NSMaxRange(range)]];
            string = [string substringToIndex:range.location];
        }
    }
    *value = string;
    return YES;
}

- (BOOL)validatePort:(id *)value error:(NSError **)error {
    if (nil != *value)
    *value = [NSString stringWithFormat:@"%ld", (long)[*value integerValue]];
    return YES;
}

- (BOOL)validateResultEncoding:(id *)value error:(NSError **)error {
    BOOL isValid = NO;
    if (*value) {
        CFStringRef charsetName = (CFStringRef)*value;
        CFStringEncoding enc = CFStringConvertIANACharSetNameToEncoding(charsetName);
        isValid = enc != kCFStringEncodingInvalidId;
        
        // ZOOMConnection will consider any unrecognized string to be marc-8, but check here
        if (NO == isValid) {
            if ([[*value stringByRemovingString:@"-"] caseInsensitiveCompare:@"marc8"] == NSOrderedSame || 
                [[*value stringByRemovingString:@"-"] caseInsensitiveCompare:@"ansel"] == NSOrderedSame)
                isValid = YES;
        }
    }
    
    if (NO == isValid && error) {
        *error = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Not a recognized IANA character set name", @"error title for setting zoom result encoding")];
        [*error setValue:NSLocalizedString(@"See http://www.iana.org/assignments/character-sets for recognized values.", @"error suggestion for setting zoom result encoding") forKey:NSLocalizedRecoverySuggestionErrorKey];
    }
    return isValid;
}

@end
