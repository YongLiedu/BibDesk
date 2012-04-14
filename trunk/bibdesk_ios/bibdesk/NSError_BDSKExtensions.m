//
//  NSError_BDSKExtensions.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/15/06.
/*
 This software is Copyright (c) 2006-2012
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

#import "NSError_BDSKExtensions.h"

#define BDSKErrorDomain @"net.sourceforge.bibdesk.errors"

NSString *BDSKFailedDocumentErrorKey = @"BDSKFailedDocument";
NSString *BDSKTemporaryCiteKeyErrorKey = @"BDSKTemporaryCiteKey";

@interface BDSKMutableError : NSError
{
    @private
    NSMutableDictionary *mutableUserInfo;
}
@end

@implementation BDSKMutableError

- (id)initWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)dict;
{
    self = [super initWithDomain:domain code:code userInfo:nil];
    if (self) {
        mutableUserInfo = [[NSMutableDictionary alloc] initWithDictionary:dict];
        // we override code with our own storage so it can be set
        [self setCode:code];
    }
    return self;
}

- (id)initLocalErrorWithCode:(NSInteger)code localizedDescription:(NSString *)description;
{
    self = [self initWithDomain:[NSError localErrorDomain] code:code userInfo:nil];
    if (self) {
        [self setValue:description forKey:NSLocalizedDescriptionKey];
    }
    return self;
}

- (void)dealloc
{
    BDSKDESTROY(mutableUserInfo);
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)aZone
{
    return [[NSError allocWithZone:aZone] initWithDomain:[self domain] code:[self code] userInfo:[self userInfo]];
}

- (NSDictionary *)userInfo
{
    return mutableUserInfo;
}

- (id)valueForUndefinedKey:(NSString *)aKey
{
    return [[self userInfo] valueForKey:aKey];
}

// allow setting nil values
- (void)setValue:(id)value forUndefinedKey:(NSString *)key;
{
    if (value)
        [mutableUserInfo setValue:value forKey:key];
}

- (void)embedError:(NSError *)underlyingError;
{
    [self setValue:underlyingError forKey:NSUnderlyingErrorKey];
}

- (void)setCode:(NSInteger)code;
{
    [self setValue:[NSNumber numberWithInteger:code] forKey:@"__BDSKErrorCode"];
}

- (NSInteger)code;
{
    return [[self valueForKey:@"__BDSKErrorCode"] integerValue];
}

- (BOOL)isMutable;
{
    return YES;
}

@end

@implementation NSError (BDSKExtensions)

+ (NSString *)localErrorDomain { return BDSKErrorDomain; }

- (BOOL)isLocalError;
{
    return [[self domain] isEqualToString:[NSError localErrorDomain]];
}

- (BOOL)isLocalErrorWithCode:(NSInteger)code;
{
    return [self isLocalError] && [self code] == code;
}

+ (id)localErrorWithCode:(NSInteger)code localizedDescription:(NSString *)description;
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, nil];
    return [[[self alloc] initWithDomain:[NSError localErrorDomain] code:code userInfo:userInfo] autorelease];
}

+ (id)localErrorWithCode:(NSInteger)code localizedDescription:(NSString *)description underlyingError:(NSError *)underlyingError;
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, underlyingError, NSUnderlyingErrorKey, nil];
    return [[[self alloc] initWithDomain:[NSError localErrorDomain] code:code userInfo:userInfo] autorelease];
}

+ (id)mutableLocalErrorWithCode:(NSInteger)code localizedDescription:(NSString *)description;
{
    return [[[BDSKMutableError alloc] initLocalErrorWithCode:code localizedDescription:description] autorelease];
}

+ (id)mutableErrorWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)dict;
{
    return [[[BDSKMutableError alloc] initWithDomain:domain code:code userInfo:dict] autorelease];
}

+ (id)mutableLocalErrorWithCode:(NSInteger)code localizedDescription:(NSString *)description underlyingError:(NSError *)underlyingError;
{
    id error = [NSError mutableLocalErrorWithCode:code localizedDescription:description];
    [error embedError:underlyingError];
    return error;
}

- (id)mutableCopyWithZone:(NSZone *)aZone;
{
    return [[BDSKMutableError allocWithZone:aZone] initWithDomain:[self domain] code:[self code] userInfo:[self userInfo]];
}

- (void)embedError:(NSError *)underlyingError;
{
    [NSException raise:NSInternalInconsistencyException format:@"Mutating method sent to immutable NSError instance"];
}

- (void)setCode:(NSInteger)code;
{
    [NSException raise:NSInternalInconsistencyException format:@"Mutating method sent to immutable NSError instance"];
}

- (id)valueForUndefinedKey:(NSString *)aKey
{
    return [[self userInfo] valueForKey:aKey];
}

- (BOOL)isMutable;
{
    return NO;
}

@end
