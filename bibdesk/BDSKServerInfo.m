//
//  BDSKServerInfo.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/30/06.
/*
 This software is Copyright (c) 2006-2010
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

#define TYPE_KEY             @"type"
#define NAME_KEY             @"name" 
#define DATABASE_KEY         @"database"
#define HOST_KEY             @"host"
#define PORT_KEY             @"port"
#define OPTIONS_KEY          @"options"
#define PASSWORD_KEY         @"password"
#define USERNAME_KEY         @"username"
#define RECORDSYNTAX_KEY     @"recordSyntax"
#define RESULTENCODING_KEY   @"resultEncoding"
#define REMOVEDIACRITICS_KEY @"removeDiacritics"

#define DEFAULT_NAME     NSLocalizedString(@"New Server", @"")
#define DEFAULT_DATABASE DATABASE_KEY 
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
    self = [self initWithType:aType ?: [info objectForKey:TYPE_KEY]
                         name:[info objectForKey:NAME_KEY]
                     database:[info objectForKey:DATABASE_KEY]
                         host:[info objectForKey:HOST_KEY]
                         port:[info objectForKey:PORT_KEY]
                      options:[info objectForKey:OPTIONS_KEY]];
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        type = [[decoder decodeObjectForKey:TYPE_KEY] retain];
        name = [[decoder decodeObjectForKey:NAME_KEY] retain];
        database = [[decoder decodeObjectForKey:DATABASE_KEY] retain];
        host = [[decoder decodeObjectForKey:HOST_KEY] retain];
        port = [[decoder decodeObjectForKey:PORT_KEY] retain];
        options = [[decoder decodeObjectForKey:OPTIONS_KEY] mutableCopy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:type forKey:TYPE_KEY];
    [coder encodeObject:name forKey:NAME_KEY];
    [coder encodeObject:database forKey:DATABASE_KEY];
    [coder encodeObject:host forKey:HOST_KEY];
    [coder encodeObject:port forKey:PORT_KEY];
    [coder encodeObject:options forKey:OPTIONS_KEY];
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
    BDSKDESTROY(type);
    BDSKDESTROY(name);
    BDSKDESTROY(database);
    BDSKDESTROY(host);
    BDSKDESTROY(port);
    BDSKDESTROY(options);
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
    [info setValue:[self type] forKey:TYPE_KEY];
    [info setValue:[self name] forKey:NAME_KEY];
    [info setValue:[self database] forKey:DATABASE_KEY];
    if ([self isZoom]) {
        [info setValue:[self host] forKey:HOST_KEY];
        [info setValue:[self port] forKey:PORT_KEY];
        [info setValue:[self options] forKey:OPTIONS_KEY];
    }
    return info;
}

- (NSString *)type { return type; }

- (NSString *)name { return name; }

- (NSString *)database { return database; }

- (NSString *)host { return [self isZoom] ? host : nil; }

- (NSString *)port { return [self isZoom] ? port : nil; }

- (NSString *)password { return [[self options] objectForKey:PASSWORD_KEY]; }

- (NSString *)username { return [[self options] objectForKey:USERNAME_KEY]; }

- (NSString *)recordSyntax { return [[self options] objectForKey:RECORDSYNTAX_KEY]; }

- (NSString *)resultEncoding { return [[self options] objectForKey:RESULTENCODING_KEY]; }

- (BOOL)removeDiacritics { return [[[self options] objectForKey:REMOVEDIACRITICS_KEY] boolValue]; }

- (NSDictionary *)options { return [self isZoom] ? [[options copy] autorelease] : nil; }

- (BOOL)isEntrez { return [[self type] isEqualToString:BDSKSearchGroupEntrez]; }
- (BOOL)isZoom { return [[self type] isEqualToString:BDSKSearchGroupZoom]; }
- (BOOL)isISI { return [[self type] isEqualToString:BDSKSearchGroupISI]; }
- (BOOL)isDBLP { return [[self type] isEqualToString:BDSKSearchGroupDBLP]; }

- (BDSKServerType)serverType {
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

static NSSet *keysAffectedByType = nil;
static NSSet *keysAffectedByOptions = nil;
static NSSet *typeSet = nil;
static NSSet *optionsSet = nil;

+ (void)initialize {
    BDSKINITIALIZE;
    keysAffectedByType = [[NSSet alloc] initWithObjects:@"serverType", HOST_KEY, PORT_KEY, OPTIONS_KEY, nil];
    keysAffectedByOptions = [[NSSet alloc] initWithObjects:PASSWORD_KEY, USERNAME_KEY, RECORDSYNTAX_KEY, RESULTENCODING_KEY, REMOVEDIACRITICS_KEY, nil];
    typeSet = [[NSSet alloc] initWithObjects:TYPE_KEY, nil];
    optionsSet = [[NSSet alloc] initWithObjects:OPTIONS_KEY, nil];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *set = [super keyPathsForValuesAffectingValueForKey:key];
    if ([keysAffectedByType containsObject:key])
        return [set count] > 0 ? [set setByAddingObjectsFromSet:typeSet] : typeSet;
    if ([keysAffectedByOptions containsObject:key])
        return [set count] > 0 ? [set setByAddingObjectsFromSet:optionsSet] : optionsSet;
    return set;
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
    [self setOptionValue:newPassword forKey:PASSWORD_KEY];
}

- (void)setUsername:(NSString *)newUser;
{
    [self setOptionValue:newUser forKey:USERNAME_KEY];
}

- (void)setRecordSyntax:(NSString *)newSyntax;
{
    [self setOptionValue:newSyntax forKey:RECORDSYNTAX_KEY];
}

- (void)setResultEncoding:(NSString *)newEncoding;
{
    [self setOptionValue:newEncoding forKey:RESULTENCODING_KEY];
}

- (void)setRemoveDiacritics:(BOOL)flag;
{
    [self setOptionValue:(flag ? @"YES" : nil) forKey:REMOVEDIACRITICS_KEY];
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
