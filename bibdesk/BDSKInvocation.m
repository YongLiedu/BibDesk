//
//  BDSKInvocation.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 2/19/09.
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
/*
 Omni Source License 2007

 OPEN PERMISSION TO USE AND REPRODUCE OMNI SOURCE CODE SOFTWARE

 Omni Source Code software is available from The Omni Group on their 
 web site at http://www.omnigroup.com/www.omnigroup.com. 

 Permission is hereby granted, free of charge, to any person obtaining 
 a copy of this software and associated documentation files (the 
 "Software"), to deal in the Software without restriction, including 
 without limitation the rights to use, copy, modify, merge, publish, 
 distribute, sublicense, and/or sell copies of the Software, and to 
 permit persons to whom the Software is furnished to do so, subject to 
 the following conditions:

 Any original copyright notices and this permission notice shall be 
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "BDSKInvocation.h"


static inline NSUInteger BDSKHashUIntptr(uintptr_t v) {
#if __LP64__ || NS_BUILD_32_LIKE_64
    return (NSUInteger)v;
#else
    return (NSUInteger)(v >> (8*(sizeof(uintptr_t)-sizeof(NSUInteger)))) ^ (NSUInteger)v;
#endif
}

@interface BDSKPlaceholderInvocation : BDSKInvocation
@end


@interface BDSKConcreteInvocation : BDSKInvocation {
    id target;
    SEL selector;
}
@end


@interface BDSKConcreteInvocation1 : BDSKConcreteInvocation {
    id object1;
}
@end


@interface BDSKConcreteInvocation2 : BDSKConcreteInvocation1 {
    id object2;
}
@end

#pragma mark -

@implementation BDSKInvocation

static BDSKPlaceholderInvocation *placeholderInvocation = nil;

+ (void)initialize {
    if (placeholderInvocation == nil)
        placeholderInvocation = (BDSKPlaceholderInvocation *)NSAllocateObject([BDSKPlaceholderInvocation class], 0, NSDefaultMallocZone());
}

+ (id)allocWithZone:(NSZone *)aZone {
    return self == [BDSKInvocation class] ? placeholderInvocation : [super allocWithZone:aZone];
}

- (id)target {
    return nil;
}

- (SEL)selector {
    [self doesNotRecognizeSelector:_cmd];
    return (SEL)0;
}

- (NSUInteger)numberOfArguments {
    [self doesNotRecognizeSelector:_cmd];
    return 0;
}

- (id)argumentAtIndex:(NSUInteger)anIndex {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (NSInvocation *)nsInvocation {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)invoke {
    [[self nsInvocation] invoke];
}

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector withObject:(id)anObject {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector withObject:(id)object1 withObject:(id)object2 {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

@end

#pragma mark -

@implementation BDSKPlaceholderInvocation

- (id)init {
    return nil;
}

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector {
    return [[BDSKConcreteInvocation alloc] initWithTarget:aTarget selector:aSelector];
}

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector withObject:(id)anObject {
    return [[BDSKConcreteInvocation1 alloc] initWithTarget:aTarget selector:aSelector withObject:anObject];
}

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector withObject:(id)anObject1 withObject:(id)anObject2 {
    return [[BDSKConcreteInvocation2 alloc] initWithTarget:aTarget selector:aSelector withObject:anObject1 withObject:anObject2];
}

- (id)retain { return self; }

- (id)autorelease { return self; }

- (void)release {}

- (unsigned)retainCount { return UINT_MAX; }

@end

#pragma mark -

@implementation BDSKConcreteInvocation

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector {
    if (self = [super init]) {
        target = [aTarget retain];
        selector = aSelector;
    }
    return self;
}

- (void)dealloc {
    [target release];
    [super dealloc];
}

- (NSUInteger)hash {
    return BDSKHashUIntptr((uintptr_t)target + (uintptr_t)(void *)selector);
}

- (BOOL)isEqual:(id)other {
    if ([[other class] isMemberOfClass:[self class]] == NO)
        return NO;
    return selector == [other selector] && target == [other target];
}

- (id)target {
    return target;
}

- (SEL)selector {
    return selector;
}

- (NSUInteger)numberOfArguments {
    return 0;
}

- (id)argumentAtIndex:(NSUInteger)anIndex {
    return nil;
}

- (NSInvocation *)nsInvocation {
    NSMethodSignature *ms = [target methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:ms];
    [invocation setTarget:target];
    [invocation setSelector:selector];
    return invocation;
}

- (void)invoke {
    [[self nsInvocation] invoke];
}

@end

#pragma mark -

@implementation BDSKConcreteInvocation1

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector withObject:(id)anObject {
    if (self = [super initWithTarget:aTarget selector:aSelector]) {
        object1 = [anObject retain];
    }
    return self;
}

- (void)dealloc {
    [object1 release];
    [super dealloc];
}

- (NSUInteger)hash {
    return [super hash] + BDSKHashUIntptr((uintptr_t)object1);
}

- (NSUInteger)numberOfArguments {
    return 1;
}

- (id)argumentAtIndex:(NSUInteger)anIndex {
    return anIndex == 0 ? object1 : nil;
}

- (BOOL)isEqual:(id)other {
    return [super isEqual:other] && object1 == [other argumentAtIndex:0];
}

- (NSInvocation *)nsInvocation {
    NSInvocation *invocation = [super nsInvocation];
    [invocation setArgument:&object1 atIndex:2];
    return invocation;
}

@end

#pragma mark -

@implementation BDSKConcreteInvocation2

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector withObject:(id)anObject1 withObject:(id)anObject2 {
    if (self = [super initWithTarget:aTarget selector:aSelector withObject:anObject1]) {
        object2 = [anObject2 retain];
    }
    return self;
}

- (void)dealloc {
    [object2 release];
    [super dealloc];
}

- (NSUInteger)hash {
    return [super hash] + BDSKHashUIntptr((uintptr_t)object2);
}

- (NSUInteger)numberOfArguments {
    return 2;
}

- (id)argumentAtIndex:(NSUInteger)anIndex {
    return anIndex == 0 ? object1 : anIndex == 1 ? object2 : nil;
}

- (BOOL)isEqual:(id)other {
    return [super isEqual:other] && object2 == [other argumentAtIndex:1];
}

- (NSInvocation *)nsInvocation {
    NSInvocation *invocation = [super nsInvocation];
    [invocation setArgument:&object2 atIndex:3];
    return invocation;
}

@end
