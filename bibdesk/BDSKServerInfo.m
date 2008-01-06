//
//  BDSKServerInfo.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 12/30/06.
/*
 This software is Copyright (c) 2006-2008
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

@implementation BDSKServerInfo

+ (id)defaultServerInfoWithType:(NSString *)aType;
{
    BOOL isEntrez = [aType isEqualToString:BDSKSearchGroupEntrez];
    BOOL isZoom = [aType isEqualToString:BDSKSearchGroupZoom];
    BOOL isISI = [aType isEqualToString:BDSKSearchGroupISI];
    
    return [[[[self class] alloc] initWithType:aType 
                                          name:NSLocalizedString(@"New Server", @"")
                                          host:(isEntrez || isISI) ? nil : @"host.domain.com"
                                          port:isZoom ? @"0" : nil 
                                      database:@"database" 
                                       options:isZoom ? [NSDictionary dictionary] : nil] autorelease];
}

- (id)initWithType:(NSString *)aType name:(NSString *)aName host:(NSString *)aHost port:(NSString *)aPort database:(NSString *)aDbase options:(NSDictionary *)opts;
{
    if (self = [super init]) {
        type = [aType copy];
        name = [aName copy];
        if ([self isEntrez] || [self isISI]) {
            host = nil;
            port = nil;
            database = [aDbase copy];
            options = nil;
        } else if ([self isZoom]) {
            host = [aHost copy];
            port = [aPort copy];
            database = [aDbase copy];
            options = [opts mutableCopy];
        } else {
            host = [aHost copy];
            // unknown type; you'll get a surprise if these are set to nil, so maybe we should just raise here...
            OBPRECONDITION(nil == aDbase);
            OBPRECONDITION(nil == opts);
            OBPRECONDITION(nil == aPort);
            port = nil;
            database = nil;
            options = nil;
        }
    }
    return self;
}

- (id)initWithType:(NSString *)aType name:(NSString *)aName host:(NSString *)aHost port:(NSString *)aPort database:(NSString *)aDbase;
{
    return [self initWithType:aType name:aName host:aHost port:aPort database:aDbase options:[NSDictionary dictionary]];
}

- (id)initWithType:(NSString *)aType dictionary:(NSDictionary *)info;
{    
    self = [self initWithType:aType ? aType : [info objectForKey:@"type"]
                         name:[info objectForKey:@"name"]
                         host:[info objectForKey:@"host"]
                         port:[info objectForKey:@"port"]
                     database:[info objectForKey:@"database"]
                      options:[info objectForKey:@"options"]];
    return self;
}

- (id)copyWithZone:(NSZone *)aZone {
    id copy = [[BDSKServerInfo allocWithZone:aZone] initWithType:[self type] name:[self name] host:[self host] port:[self port] database:[self database] options:[self options]];
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)aZone {
    id copy = [[BDSKMutableServerInfo allocWithZone:aZone] initWithType:[self type] name:[self name] host:[self host] port:[self port] database:[self database] options:[self options]];
    return copy;
}

- (void)dealloc {
    [type release];
    [name release];
    [host release];
    [port release];
    [database release];
    [options release];
    [super dealloc];
}

- (BOOL)isEqual:(id)other {
    BOOL isEqual = NO;
    // we don't compare the name, as that is just a label
    if ([self isMemberOfClass:[other class]] == NO || [[self type] isEqualToString:[(BDSKServerInfo *)other type]] == NO)
        isEqual = NO;
    else if ([self isEntrez] || [self isISI])
        isEqual = OFISEQUAL([self database], [other database]);
    else if ([self isZoom])
        isEqual = OFISEQUAL([self host], [other host]) && 
                  OFISEQUAL([self port], [(BDSKServerInfo *)other port]) && 
                  OFISEQUAL([self database], [other database]) && 
                  OFISEQUAL([self password], [other password]) && 
                  OFISEQUAL([self username], [other username]) && 
                  (OFISEQUAL([self options], [(BDSKServerInfo *)other options]) || ([[self options] count] == 0 && [[(BDSKServerInfo *)other options] count] == 0));
    else
        isEqual = OFISEQUAL([self host], [other host]);
    return isEqual;
}

- (NSDictionary *)dictionaryValue {
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:7];
    [info setValue:[self type] forKey:@"type"];
    [info setValue:[self name] forKey:@"name"];
    [info setValue:[self database] forKey:@"database"];
    if ([self isZoom]) {
        [info setValue:[self host] forKey:@"host"];
        [info setValue:[self port] forKey:@"port"];
        [info setValue:[self password] forKey:@"password"];
        [info setValue:[self username] forKey:@"username"];
        [info setValue:[self options] forKey:@"options"];
    }
    return info;
}

- (NSString *)type { return type; }

- (NSString *)name { return name; }

- (NSString *)host { return host; }

- (NSString *)port { return port; }

- (NSString *)database { return database; }

- (NSString *)password { return [options objectForKey:@"password"]; }

- (NSString *)username { return [options objectForKey:@"username"]; }

- (NSString *)recordSyntax { return [options objectForKey:@"recordSyntax"]; }

- (NSString *)resultEncoding { return [options objectForKey:@"resultEncoding"]; }

- (BOOL)removeDiacritics { return [[options objectForKey:@"removeDiacritics"] boolValue]; }

- (NSDictionary *)options { return options; }

- (BOOL)isEntrez { return [[self type] isEqualToString:BDSKSearchGroupEntrez]; }
- (BOOL)isZoom { return [[self type] isEqualToString:BDSKSearchGroupZoom]; }
- (BOOL)isISI { return [[self type] isEqualToString:BDSKSearchGroupISI]; }

@end


@implementation BDSKMutableServerInfo

- (void)setDelegate:(id)newDelegate { delegate = newDelegate; }

- (id)delegate { return delegate; }

- (void)setName:(NSString *)newName;
{
    [name autorelease];
    name = [newName copy];
}

- (void)setPort:(NSString *)newPort;
{
    [port autorelease];
    port = [newPort copy];
}

- (void)setHost:(NSString *)newHost;
{
    [host autorelease];
    host = [newHost copy];
}

- (void)setDatabase:(NSString *)newDbase;
{
    [database autorelease];
    database = [newDbase copy];
}

- (void)setPassword:(NSString *)newPassword;
{
    if (options)
        [options setValue:newPassword forKey:@"password"];
    else if (newPassword)
        [self setOptions:[NSDictionary dictionaryWithObjectsAndKeys:newPassword, @"password", nil]];
}

- (void)setUsername:(NSString *)newUser;
{
    if (options)
        [options setValue:newUser forKey:@"username"];
    else if (newUser)
        [self setOptions:[NSDictionary dictionaryWithObjectsAndKeys:newUser, @"username", nil]];
}

- (void)setRecordSyntax:(NSString *)newSyntax;
{
    if (options)
        [options setValue:newSyntax forKey:@"recordSyntax"];
    else if (newSyntax)
        [self setOptions:[NSDictionary dictionaryWithObjectsAndKeys:newSyntax, @"recordSyntax", nil]];
}

- (void)setResultEncoding:(NSString *)newEncoding;
{
    if (options)
        [options setValue:newEncoding forKey:@"resultEncoding"];
    else if (newEncoding)
        [self setOptions:[NSDictionary dictionaryWithObjectsAndKeys:newEncoding, @"resultEncoding", nil]];
}

- (void)setRemoveDiacritics:(BOOL)flag;
{
    if (flag) {
        if (options)
            [options setValue:@"YES" forKey:@"removeDiacritics"];
        else
            [self setOptions:[NSDictionary dictionaryWithObjectsAndKeys:@"YES", @"removeDiacritics", nil]];
    } else if (options) {
        [options setValue:nil forKey:@"removeDiacritics"];
    }
}

- (void)setOptions:(NSDictionary *)newOptions;
{
    [options autorelease];
    options = [newOptions mutableCopy];
}

- (BOOL)validateHost:(id *)value error:(NSError **)error {
    NSString *string = *value;
    NSRange range = [string rangeOfString:@"://"];
    if ([self isZoom]) {
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
    *value = [NSString stringWithFormat:@"%i", [*value intValue]];
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

- (void)objectDidBeginEditing:(id)editor {
    if ([delegate respondsToSelector:@selector(objectDidBeginEditing:)])
        [delegate objectDidBeginEditing:editor];
}

- (void)objectDidEndEditing:(id)editor {
    if ([delegate respondsToSelector:@selector(objectDidEndEditing:)])
        [delegate objectDidEndEditing:editor];
}

@end
