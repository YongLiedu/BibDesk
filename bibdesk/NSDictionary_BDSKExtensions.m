//
//  NSDictionary_BDSKExtensions.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 8/5/06.
/*
 This software is Copyright (c) 2006-2011
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
 Some methods in this category are copied from OmniFoundation 
 and are subject to the following licence:
 
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

#import "NSDictionary_BDSKExtensions.h"
#import "BDSKCFCallBacks.h"


@implementation NSDictionary (BDSKExtensions)

- (id)initWithObjects:(id *)objects forCaseInsensitiveKeys:(NSString **)keys count:(NSUInteger)count {
    [[self init] release];
    return (id)CFDictionaryCreate(CFAllocatorGetDefault(), (const void **)keys, (const void **)objects, count, &kBDSKCaseInsensitiveStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

- (id)initForCaseInsensitiveKeysWithDictionary:(NSDictionary *)aDictionary{
    CFIndex count = [aDictionary count];
    BDSKASSERT(count < 256);
    NSString *keys[count];
    id values[count];
    if (count)
        CFDictionaryGetKeysAndValues((CFDictionaryRef)aDictionary, (const void **)keys, (const void **)values);
    return [self initWithObjects:values forCaseInsensitiveKeys:keys count:count];
}

// The rest of these methods are copied from NSData-OFExtensions.m

// This seems more convenient than having to write your own if statement a zillion times

// Returns YES iff the value is YES, Y, yes, y, or 1.
- (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)defaultValue {
    id value = [self objectForKey:key];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : defaultValue;
}

// Just to make life easier
- (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)defaultValue {
    id value = [self objectForKey:key];
    return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : defaultValue;
}

- (NSUInteger)unsignedIntegerForKey:(NSString *)key defaultValue:(NSUInteger)defaultValue {
    id value = [self objectForKey:key];
    return [value respondsToSelector:@selector(unsignedIntegerValue)] ? [value unsignedIntegerValue] : [value respondsToSelector:@selector(integerValue)] ? (NSUInteger)[value integerValue] : defaultValue;
}

- (double)doubleForKey:(NSString *)key defaultValue:(double)defaultValue {
    id value = [self objectForKey:key];
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : defaultValue;
}

- (NSPoint)pointForKey:(NSString *)key defaultValue:(NSPoint)defaultValue {
    id value = [self objectForKey:key];
    if ([value respondsToSelector:@selector(pointValue)])
        return [value pointValue];
    else if ([value isKindOfClass:[NSString class]] && NO == [NSString isEmptyString:value])
        return NSPointFromString(value);
    else
        return defaultValue;
}

- (NSRect)rectForKey:(NSString *)key defaultValue:(NSRect)defaultValue {
    id value = [self objectForKey:key];
    if ([value respondsToSelector:@selector(rectValue)])
        return [value rectValue];
    else if ([value isKindOfClass:[NSString class]] && NO == [NSString isEmptyString:value])
        return NSRectFromString(value);
    else
        return defaultValue;
}

@end

#pragma mark -

@implementation NSMutableDictionary (BDSKExtensions)

- (id)initForCaseInsensitiveKeys{
	[[self init] release];
    return (NSMutableDictionary *)CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kBDSKCaseInsensitiveStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

// The rest of these methods are copied from NSMutableData-OFExtensions.m

- (void)setBool:(BOOL)value forKey:(NSString *)key {
    NSNumber *number = [[NSNumber alloc] initWithBool:value];
    [self setObject:number forKey:key];
    [number release];
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)key {
    NSNumber *number = [[NSNumber alloc] initWithInteger:value];
    [self setObject:number forKey:key];
    [number release];
}

- (void)setUnsignedInteger:(NSUInteger)value forKey:(NSString *)key {
    NSNumber *number = [[NSNumber alloc] initWithUnsignedInteger:value];
    [self setObject:number forKey:key];
    [number release];
}

- (void)setDouble:(double)value forKey:(NSString *)key {
    NSNumber *number = [[NSNumber alloc] initWithDouble:value];
    [self setObject:number forKey:key];
    [number release];
}

- (void)setPoint:(NSPoint)value forKey:(NSString *)key {
    [self setObject:NSStringFromPoint(value) forKey:key];
}

- (void)setRect:(NSRect)value forKey:(NSString *)key {
    [self setObject:NSStringFromRect(value) forKey:key];
}

@end
