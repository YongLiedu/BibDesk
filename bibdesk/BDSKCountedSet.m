//
//  BDSKCountedSet.m
//  Bibdesk
//
//  Created by Adam Maxwell on 10/31/05.
/*
 This software is Copyright (c) 2005-2009
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

#import "BDSKCountedSet.h"
#import "CFString_BDSKExtensions.h"
#import "BDSKCFCallBacks.h"

@implementation BDSKCountedSet

// designated initializer
- (id)initWithCallBacks:(const CFSetCallBacks *)callBacks{
    
    if(self = [super init]) {
        set = CFSetCreateMutable(CFAllocatorGetDefault(), 0, callBacks);
        bag = CFBagCreateMutable(CFAllocatorGetDefault(), 0, (const CFBagCallBacks *)callBacks); // CFSetCallBacks and CFBagCallBacks are compatible
    }
    return self;
}

- (id)initWithCountedSet:(BDSKCountedSet *)countedSet {
    
    if(self = [super init]) {
        set = CFSetCreateMutableCopy(CFAllocatorGetDefault(), 0, countedSet->set);
        bag = CFBagCreateMutableCopy(CFAllocatorGetDefault(), 0, countedSet->bag);
    }
    return self;
}

- (id)initCaseInsensitive:(BOOL)caseInsensitive {
    // used only for debug logging at present
    keysAreStrings = YES;

    if(caseInsensitive)
        return [self initWithCallBacks:&kBDSKCaseInsensitiveStringSetCallBacks];
    else
        return [self initWithCallBacks:&kCFTypeSetCallBacks];

}

- (id)copyWithZone:(NSZone *)zone
{
    return [(NSSet *)set copyWithZone:zone];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithCountedSet:self];
}

// if we ever need this, we could encode only for specific callbacks (see OFMultiValueDictionary)
- (void)encodeWithCoder:(NSCoder *)coder
{
    [NSException raise:NSGenericException format:@"Cannot serialize an %@ with custom key callbacks", [(id)isa name]];
}

- (void)dealloc
{
    if(set) CFRelease(set);
    if(bag) CFRelease(bag);
    [super dealloc];
}

#pragma mark NSCountedSet methods

- (unsigned)countForObject:(id)object;
{
    return CFBagGetCountOfValue(bag, (const void *)object);
}

#pragma mark NSSet primitive methods

- (unsigned)count;
{
    return CFSetGetCount(set);
}

- (id)member:(id)object;
{
    return (id)CFSetGetValue(set, (void *)object);
}

- (NSEnumerator *)objectEnumerator;
{
    return [(NSSet *)set objectEnumerator];
}

#pragma mark NSMutableSet primitive methods

- (void)addObject:(id)object;
{
    BDSKASSERT(keysAreStrings ? [object isKindOfClass:[NSString class]] : 1);
    
    CFSetAddValue(set, object);
    CFBagAddValue(bag, object);
}
    
- (void)removeObject:(id)object;
{
    BDSKASSERT(keysAreStrings ? [object isKindOfClass:[NSString class]] : 1);

    CFBagRemoveValue(bag, object);
    if(CFBagGetCountOfValue(bag, (void *)object) == 0)
        CFSetRemoveValue(set, object);
}

@end
