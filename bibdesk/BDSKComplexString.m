// BDSKComplexString.m
// Created by Michael McCracken, 2004
/*
 This software is Copyright (c) 2004-2009
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BDSKComplexString.h"
#import "NSString_BDSKExtensions.h"
#import "CFString_BDSKExtensions.h"
#import "BDSKStringNode.h"
#import "BDSKMacroResolver.h"
#import "NSError_BDSKExtensions.h"
#import "NSCharacterSet_BDSKExtensions.h"

static NSCharacterSet *macroCharSet = nil;
static NSZone *complexStringExpansionZone = NULL;
static Class BDSKComplexStringClass = Nil;

static BDSKMacroResolver *macroResolverForUnarchiving = nil;

/* BDSKComplexString is a string that may be a concatenation of strings, 
    some of which are macros.
   It's a concrete subclass of NSString, which means it can be used 
    anywhere an NSString can.
   The string always has an expandedValue, which is treated as the 
    actual value if you treat it as an NSString. That value
    is either the expanded value or the value of the macro itself. */

@interface BDSKComplexString : NSString {
  NSArray *nodes;			/* an array of BDSKStringNodes. */

  BDSKMacroResolver *macroResolver;
  
  BOOL isComplex;
  BOOL isInherited;
  
  NSString *expandedString;
  unsigned long long modification;
  unsigned long long defaultModification;
}

@end

#pragma mark -
#pragma mark Private complex string expansion

#define STACK_BUFFER_SIZE 256

static inline
NSString *__BDStringCreateByCopyingExpandedValue(NSArray *nodes, BDSKMacroResolver *macroResolver)
{
	BDSKStringNode *node = nil;
    BDSKStringNode **stringNodes, *stackBuffer[STACK_BUFFER_SIZE];
    
    NSInteger iMax = nil == nodes ? 0 : CFArrayGetCount((CFArrayRef)nodes);
    
    if(0 == iMax) return nil;
        
    if (iMax > STACK_BUFFER_SIZE) {
        stringNodes = (BDSKStringNode **)NSZoneMalloc(complexStringExpansionZone, sizeof(BDSKStringNode *) * iMax);
        if (NULL == stringNodes)
            [NSException raise:NSInternalInconsistencyException format:@"Unable to malloc memory in zone %@", NSZoneName(complexStringExpansionZone)];
    } else {
        stringNodes = stackBuffer;
    }

    // This avoids the overhead of calling objectAtIndex: or using an enumerator, since we can now just increment a pointer to traverse the contents of the array.
    CFArrayGetValues((CFArrayRef)nodes, (CFRange){0, iMax}, (const void **)stringNodes);
    
    // Resizing can be a performance hit, but we can't safely use a fixed-size mutable string
    CFMutableStringRef mutStr = CFStringCreateMutable(CFAllocatorGetDefault(), 0);
    CFStringRef nodeVal, expandedValue;
    
    // Increment a different pointer, in case we need to free stringNodes later
    BDSKStringNode **stringNodeIdx = stringNodes;
    
    while(iMax--){
        node = *stringNodeIdx++;
        nodeVal = (CFStringRef)(node->value);
        if(node->type == BDSKStringNodeMacro){
            expandedValue = (CFStringRef)[macroResolver valueOfMacro:(NSString *)nodeVal];
            if(expandedValue == nil && macroResolver != [BDSKMacroResolver defaultMacroResolver])
                expandedValue = (CFStringRef)[[BDSKMacroResolver defaultMacroResolver] valueOfMacro:(NSString *)nodeVal];
            if(expandedValue)
                nodeVal = expandedValue;
        }
        CFStringAppend(mutStr, nodeVal);
    }
    
    BDSKPOSTCONDITION(!BDIsEmptyString(mutStr));
    
    if(stackBuffer != stringNodes) NSZoneFree(complexStringExpansionZone, stringNodes);
    
    return (NSString *)mutStr;
}

@implementation BDSKComplexString

+ (void)initialize{
    
    BDSKINITIALIZE;
    
    NSMutableCharacterSet *tmpSet = [[NSMutableCharacterSet alloc] init];
    [tmpSet addCharactersInRange:NSMakeRange(48,10)]; // 0-9
    [tmpSet addCharactersInRange:NSMakeRange(65,26)]; // A-Z
    [tmpSet addCharactersInRange:NSMakeRange(97,26)]; // a-z
    [tmpSet addCharactersInString:@"!$&*+-./:;<>?[]^_`|"]; // see the btparse documentation
    macroCharSet = [tmpSet copy];
    [tmpSet release];
    
    // This zone will automatically be resized as necessary, but won't free the underlying memory; we could statically allocate memory for stringNodes with NSZoneMalloc and then realloc as needed, but then we run into multithreading problems writing to the same memory location.  Using NSZoneMalloc/NSZoneFree allows us to avoid the overhead of malloc/free doing their own zone lookups.
    if(complexStringExpansionZone == NULL){
        complexStringExpansionZone = NSCreateZone(1024, 1024, NO);
        NSSetZoneName(complexStringExpansionZone, @"BDSKComplexStringExpansionZone");
    } 
    
    BDSKComplexStringClass = self;

}

/* designated initializer */
- (id)initWithNodes:(NSArray *)nodesArray macroResolver:(BDSKMacroResolver *)aMacroResolver{
    BDSKASSERT([nodesArray count] > 0);
    if (self = [super init]) {
        nodes = [nodesArray copyWithZone:[self zone]];
        // we don't retain, as the macroResolver might retain us as a macro value
        macroResolver = (aMacroResolver == [BDSKMacroResolver defaultMacroResolver]) ? nil : aMacroResolver;
        isComplex = YES;
		isInherited = NO;
        expandedString = nil;
        modification = 0;
        defaultModification = 0;
	}		
    return self;
}

- (id)initWithInheritedValue:(NSString *)aValue {
    BDSKASSERT(aValue != nil);
    if (self = [self initWithNodes:[aValue nodes] macroResolver:[aValue macroResolver]]) {
        isComplex = [aValue isComplex];
		isInherited = YES;
	}
	return self;
}

- (void)dealloc{
	BDSKDESTROY(nodes);
	BDSKDESTROY(expandedString);
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone{
    if (NSShouldRetainWithZone(self, zone))
        return [self retain];
    else if (isInherited)
        return [[BDSKComplexString allocWithZone:zone] initWithInheritedValue:self];
    else
        return [[BDSKComplexString allocWithZone:zone] initWithNodes:nodes macroResolver:macroResolver];

}

/* NSCoding protocol */

/* In fixing bug #1460089, experiment shows that we need to override -classForKeyedArchiver, since NSArchiver seems to encode NSString subclasses as NSStrings.  

With that change, our NSCoding methods get called, but calling -[super initWithCoder:] causes an NSInvalidArgumentException since it apparently calls -initWithCharactersNoCopy:length:freeWhenDone: on the abstract NSString class:

#2	0x92a6a208 in -[NSString initWithCharactersNoCopy:length:freeWhenDone:]
#3	0x92a69c8c in -[NSString initWithString:]
#4	0x929840d0 in -[NSString initWithCoder:]
#5	0x0002a16c in -[BDSKComplexString initWithCoder:] at StringCoder.m:35

Rather than relying on the same call sequence to be used, I think we should ignore super's implementation.
*/

- (Class)classForKeyedArchiver { return BDSKComplexStringClass; }

- (id)initWithCoder:(NSCoder *)coder{
    if([coder allowsKeyedCoding]){
        if (self = [super init]) {
            BDSKASSERT([coder isKindOfClass:[NSKeyedUnarchiver class]]);
            nodes = [[coder decodeObjectForKey:@"nodes"] retain];
            isComplex = [coder decodeBoolForKey:@"complex"];
            isInherited = [coder decodeBoolForKey:@"inherited"];
            macroResolver = [[self class] macroResolverForUnarchiving];
            expandedString = nil;
            modification = 0;
            defaultModification = 0;
        }
    } else {
        [[super init] release];
        self = [[NSKeyedUnarchiver unarchiveObjectWithData:[coder decodeDataObject]] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder{
    if([coder allowsKeyedCoding]){
        BDSKASSERT([coder isKindOfClass:[NSKeyedArchiver class]]);
        [coder encodeObject:nodes forKey:@"nodes"];
        [coder encodeBool:isComplex forKey:@"complex"];
        [coder encodeBool:isInherited forKey:@"inherited"];
    } else {
        [coder encodeDataObject:[NSKeyedArchiver archivedDataWithRootObject:self]];
    }
}

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder
{
    return [encoder isByref] ? (id)[NSDistantObject proxyWithLocal:self connection:[encoder connection]] : self;
}

#pragma mark overridden NSString Methods

/* A bunch of methods that have to be overridden in a concrete subclass of NSString */

- (NSUInteger)length{
    return [[self expandedString] length];
}

- (unichar)characterAtIndex:(NSUInteger)idx{
    return [[self expandedString] characterAtIndex:idx];
}

/* Overridden NSString performance methods */

- (void)getCharacters:(unichar *)buffer{
    return [[self expandedString] getCharacters:buffer];
}

- (void)getCharacters:(unichar *)buffer range:(NSRange)aRange{
    return [[self expandedString] getCharacters:buffer range:aRange];
}

/* do not override super's implementation of -isEqual:
- (BOOL)isEqual:(NSString *)other { return [super isEqual:other]; }
*/

#pragma mark overridden methods from the ComplexStringExtensions

- (id)copyUninheritedWithZone:(NSZone *)zone{
	
	if (isInherited == NO) 
        return [self copyWithZone:zone];
	else 
        return [[NSString allocWithZone:zone] initWithNodes:nodes macroResolver:macroResolver];
}

- (BOOL)isComplex {
    return isComplex;
}

- (BOOL)isInherited {
    return isInherited;
}

- (NSArray *)nodes{
    return nodes;
}

- (BOOL)isEqualAsComplexString:(NSString *)other{
	if ([self isComplex] != [other isComplex])
        return NO;
    else if ([self isComplex])
		return [[self nodes] isEqualToArray:[other nodes]];
	else
		return [self isEqualToString:other];
}

- (NSComparisonResult)compareAsComplexString:(NSString *)other options:(NSUInteger)mask{
	if ([self isComplex]) {
		if (NO == [other isComplex])
			return NSOrderedDescending;
		
		NSArray *otherNodes = [other nodes];
        NSUInteger i, count = MIN([nodes count], [otherNodes count]);
		
		for (i = 0; i < count; i++) {
			NSComparisonResult comp = [[nodes objectAtIndex:i] compareNode:[otherNodes objectAtIndex:i] options:mask];
			if (comp != NSOrderedSame)
				return comp;
		}
		if (count > [otherNodes count])
			return NSOrderedAscending;
		if (count > [nodes count])
			return NSOrderedDescending;
		return NSOrderedSame;
	}
	return [self compare:other options:mask];
}

- (NSString *)expandedString {
    if (expandedString == nil ||
        (macroResolver != nil && modification != [macroResolver modification]) ||
        (isComplex && defaultModification != [[BDSKMacroResolver defaultMacroResolver] modification])) {
        [expandedString release];
        expandedString = __BDStringCreateByCopyingExpandedValue(nodes, macroResolver);
        if (macroResolver)
            modification = [macroResolver modification];
        defaultModification = [[BDSKMacroResolver defaultMacroResolver] modification];
    }
    return expandedString;
}

// Returns the bibtex value of the string.
- (NSString *)stringAsBibTeXString{
    NSUInteger i = 0;
    NSMutableString *retStr = [NSMutableString string];
        
    for( i = 0; i < [nodes count]; i++){
        BDSKStringNode *valNode = [nodes objectAtIndex:i];
        if (i != 0){
            [retStr appendString:@" # "];
        }
        if([valNode type] == BDSKStringNodeString){
            [retStr appendString:[[valNode value] stringAsBibTeXString]];
        }else{
            [retStr appendString:[valNode value]];
        }
    }
    
    return retStr; 
}

- (BOOL)hasSubstring:(NSString *)target options:(NSUInteger)opts{
	if ([self isInherited] && ![self isComplex])
		return [[[nodes objectAtIndex:0] value] hasSubstring:target options:opts];
	
	NSArray *targetNodes = [target nodes];
	
	NSInteger tNum = [targetNodes count];
	NSInteger max = [nodes count] - tNum;
	BOOL back = (BOOL)(opts & NSBackwardsSearch);
	NSInteger i = (back ? max : 0);
	
	while (i <= max && i >= 0) {
		if ([(BDSKStringNode *)[nodes objectAtIndex:i] compareNode:[targetNodes objectAtIndex:0] options:opts] == NSOrderedSame) {
			NSInteger j = 1;
			while (j < tNum && [(BDSKStringNode *)[nodes objectAtIndex:i + j] compareNode:[targetNodes objectAtIndex:j] options:opts] == NSOrderedSame) 
				j++;
			if (j == tNum)
				return YES;
		}
		back ? i-- : i++;
	}
	
	return NO;
}

- (NSString *)stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)replacement options:(NSUInteger)opts replacements:(NSUInteger *)number{
	NSArray *targetNodes = [target nodes];
	NSArray *replNodes = [replacement nodes];
	NSMutableArray *newNodes;
	NSString *newString;
	
	NSUInteger num = 0;
	NSInteger tNum = [targetNodes count];
	NSInteger rNum = [replNodes count];
	NSInteger min = 0;
	NSInteger max = [nodes count] - tNum;
	BOOL back = (BOOL)(opts & NSBackwardsSearch);
	NSInteger i;
	
	if ([self isInherited] || max < min) {
		*number = 0;
		return [[self retain] autorelease];
	}
	
	if (opts & NSAnchoredSearch) {
		// replace at the beginning or the end of the string
		if (back) 
			min = max;
		else
			max = min;
	}
    
	newNodes = [nodes mutableCopy];
	i = (back ? max : min);
	while (i <= max && i >= min) {
		if ([(BDSKStringNode *)[newNodes objectAtIndex:i] compareNode:[targetNodes objectAtIndex:0] options:opts] == NSOrderedSame) {
			NSInteger j = 1;
			while (j < tNum && [(BDSKStringNode *)[newNodes objectAtIndex:i + j] compareNode:[targetNodes objectAtIndex:j] options:opts] == NSOrderedSame) 
				j++;
			if (j == tNum) {
				[newNodes replaceObjectsInRange:NSMakeRange(i, tNum) withObjectsFromArray:replNodes];
				if (!back) {
					i += rNum - 1;
					max += rNum - tNum;
				}
				num++;
			}
		}
		back ? i-- : i++;
	}
	
	if (num) {
        newString = [BDSKComplexString stringWithNodes:newNodes macroResolver:macroResolver];
	} else {
		newString = [[self retain] autorelease];
	} 
	[newNodes release];
	
	*number = num;
	return newString;
}

- (NSString *)complexStringByAppendingString:(NSString *)string{
	NSString *newString = nil;
    if ([self isComplex] == NO) {
        newString = [[nodes objectAtIndex:0] complexStringByAppendingString:string];
    } else if ([string isEqualAsComplexString:@""]) {
        newString = self;
    } else {
        NSMutableArray *mutableNodes = [nodes mutableCopy];
        NSArray *newNodes = nil;
        if ([string isComplex]) {
            newNodes = [[string nodes] mutableCopy];
        } else {
            BDSKStringNode *node = [[BDSKStringNode alloc] initWithQuotedString:string];
            newNodes = [[NSMutableArray alloc] initWithObjects:node, nil];
            [node release];
        }
        [mutableNodes addObjectsFromArray:newNodes];
        [newNodes release];
        newString = [BDSKComplexString stringWithNodes:mutableNodes macroResolver:macroResolver];
        [mutableNodes release];
    }
    return newString;
}

- (BDSKMacroResolver *)macroResolver{
    return (macroResolver == nil && isComplex) ? [BDSKMacroResolver defaultMacroResolver] : macroResolver;
}

@end

#pragma mark -

@implementation NSString (ComplexStringExtensions)

+ (BDSKMacroResolver *)macroResolverForUnarchiving{
    return macroResolverForUnarchiving;
}

+ (void)setMacroResolverForUnarchiving:(BDSKMacroResolver *)aMacroResolver{
    if (macroResolverForUnarchiving != aMacroResolver) {
        [macroResolverForUnarchiving release];
        macroResolverForUnarchiving = [aMacroResolver retain];
    }
}

- (id)initWithNodes:(NSArray *)nodesArray macroResolver:(BDSKMacroResolver *)aMacroResolver{
    if ([nodesArray count] == 1 && [(BDSKStringNode *)[nodesArray objectAtIndex:0] type] == BDSKStringNodeString) {
        self = [self initWithString:[(BDSKStringNode *)[nodesArray objectAtIndex:0] value]];
    } else { 
        [[self init] release];
        self = nil;
        if ([nodesArray count])
            self = [[BDSKComplexString alloc] initWithNodes:nodesArray macroResolver:aMacroResolver];
    }
    return self;
}

- (id)initWithInheritedValue:(NSString *)aValue{
    [[self init] release];
    self = nil;
    if (aValue)
        self = [[BDSKComplexString alloc] initWithInheritedValue:aValue];
    return self;
}

- (id)initWithBibTeXString:(NSString *)btstring macroResolver:(BDSKMacroResolver *)theMacroResolver error:(NSError **)outError {
	btstring = [btstring stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if([btstring length] == 0){
        // if the string was whitespace only, it becomes empty.
        // empty strings are a special case, they are not complex.
        // CMH: an empty bibtex string is really invalid, so shouldn't we return nil?
        return self = [self initWithString:@""];
    }
    
	NSMutableArray *returnNodes = [[NSMutableArray alloc] initWithCapacity:5];
	BDSKStringNode *node = nil;
    NSScanner *sc = [[NSScanner alloc] initWithString:btstring];
    [sc setCharactersToBeSkipped:nil];
    NSString *s = nil;
    NSInteger nesting;
    unichar ch;
    NSError *error = nil;
    
    NSCharacterSet *bracesCharSet = [NSCharacterSet curlyBraceCharacterSet];
	[BDSKComplexString class]; // make sure the class is initialized
    
    while (error == nil && NO == [sc isAtEnd]) {
        ch = [btstring characterAtIndex:[sc scanLocation]];
        if (ch == '{') {
            // a brace-quoted string, we look for the corresponding closing brace
            NSMutableString *nodeStr = [[NSMutableString alloc] initWithCapacity:10];
            [sc setScanLocation:[sc scanLocation] + 1];
            nesting = 1;
            while (nesting > 0 && ![sc isAtEnd]) {
                if ([sc scanUpToCharactersFromSet:bracesCharSet intoString:&s])
                    [nodeStr appendString:s];
                if ([sc isAtEnd]) break;
                if ([btstring characterAtIndex:[sc scanLocation] - 1] != '\\') {
                    // we found an unquoted brace
                    ch = [btstring characterAtIndex:[sc scanLocation]];
                    if (ch == '}') {
                        --nesting;
                    } else {
                        ++nesting;
                    }
                    if (nesting > 0) // we don't include the outer braces
                        [nodeStr appendFormat:@"%C",ch];
                }
                [sc setScanLocation:[sc scanLocation] + 1];
            }
            if (nesting > 0) {
                error = [NSError localErrorWithCode:kBDSKComplexStringError localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unbalanced string: [%@]", @"error description"), nodeStr]];
            } else {
                node = [[BDSKStringNode alloc] initWithQuotedString:nodeStr];
                [returnNodes addObject:node];
                [node release];
            }
            [nodeStr release];
        }
        else if (ch == '"') {
            // a doublequote-quoted string
            NSMutableString *nodeStr = [[NSMutableString alloc] initWithCapacity:10];
            [sc setScanLocation:[sc scanLocation] + 1];
            nesting = 1;
            while (nesting > 0 && ![sc isAtEnd]) {
                if ([sc scanUpToString:@"\"" intoString:&s])
                    [nodeStr appendString:s];
                if (![sc isAtEnd]) {
                    if ([btstring characterAtIndex:[sc scanLocation] - 1] == '\\')
                        [nodeStr appendString:@"\""];
                    else
                        nesting = 0;
                    [sc setScanLocation:[sc scanLocation] + 1];
                }
            }
            // we don't accept unbalanced braces, as we always quote with braces
            // do we want to be more permissive and try to use "-quoted fields?
            if (nesting > 0 || ![nodeStr isStringTeXQuotingBalancedWithBraces:YES connected:NO]) {
                error = [NSError localErrorWithCode:kBDSKComplexStringError localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"Unbalanced string: [%@]", @"error description"), nodeStr]];
            } else {
                node = [[BDSKStringNode alloc] initWithQuotedString:nodeStr];
                [returnNodes addObject:node];
                [node release];
            }
            [nodeStr release];
        }
        else if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:ch]) {
            // this should be all numbers
            [sc scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&s];
            node = [[BDSKStringNode alloc] initWithNumberString:s];
			[returnNodes addObject:node];
			[node release];
        }
        else if ([macroCharSet characterIsMember:ch]) {
            // a macro
            if ([sc scanCharactersFromSet:macroCharSet intoString:&s]) {
				node = [[BDSKStringNode alloc] initWithMacroString:s];
                [returnNodes addObject:node];
				[node release];
			}
        }
        else if (ch == '#') {
            // we found 2 # or a # at the beginning
            error = [NSError localErrorWithCode:kBDSKComplexStringError localizedDescription:NSLocalizedString(@"Invalid first character in component", @"error description")];
        }
        else {
            error = [NSError localErrorWithCode:kBDSKComplexStringError localizedDescription:NSLocalizedString(@"Invalid first character in component", @"error description")];
        }
        
        if (error == nil) {
            // look for the next #-character, removing spaces around it
            [sc scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
            if (![sc isAtEnd]) {
                if (![sc scanString:@"#" intoString:NULL]) {
                    error = [NSError localErrorWithCode:kBDSKComplexStringError localizedDescription:NSLocalizedString(@"Missing # character", @"error description")];
                } else {
                    [sc scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
                    if ([sc isAtEnd]) {
                        // we found a # at the end
                        error = [NSError localErrorWithCode:kBDSKComplexStringError localizedDescription:NSLocalizedString(@"Empty component", @"error description")];
                    }
                }
            }
        }
    }
    if (error == nil) {
        self = [self initWithNodes:returnNodes macroResolver:theMacroResolver];
    } else {
        [[self init] release];
        self = nil;
        if (outError != NULL) *outError = error;
    }
    [sc release];
    [returnNodes release];
    
    return self;
}

+ (id)stringWithBibTeXString:(NSString *)btstring macroResolver:(BDSKMacroResolver *)theMacroResolver error:(NSError **)outError{
    return [[[self alloc] initWithBibTeXString:btstring macroResolver:theMacroResolver error:outError] autorelease];
}

+ (id)stringWithNodes:(NSArray *)nodesArray macroResolver:(BDSKMacroResolver *)theMacroResolver{
    return [[[self alloc] initWithNodes:nodesArray macroResolver:theMacroResolver] autorelease];
}

+ (id)stringWithInheritedValue:(NSString *)aValue{
    return [[[self alloc] initWithInheritedValue:aValue] autorelease];
}

- (id)copyUninherited{
	return [self copyUninheritedWithZone:nil];
}

- (id)copyUninheritedWithZone:(NSZone *)zone{
	return [self copyWithZone:zone];
}

- (BOOL)isComplex{
	return NO;
}

- (BOOL)isInherited{
	return NO;
}

- (BDSKMacroResolver *)macroResolver{
    return nil;
}

- (NSArray *)nodes{
    BDSKStringNode *node = [[BDSKStringNode alloc] initWithQuotedString:self];
    NSArray *nodes = [NSArray arrayWithObject:node];
    [node release];
    return nodes;
}

+ (BOOL)isEmptyAsComplexString:(NSString *)aString{
    return aString == nil || [aString isEqualAsComplexString:@""];
}

- (BOOL)isEqualAsComplexString:(NSString *)other{
	// we can assume that we are not complex, as BDSKComplexString overrides this
	if ([other isComplex])
		return NO;
	return [self isEqualToString:other];
}

- (NSComparisonResult)compareAsComplexString:(NSString *)other{
	return [self compareAsComplexString:other options:0];
}

- (NSComparisonResult)compareAsComplexString:(NSString *)other options:(NSUInteger)mask{
	if ([other isComplex])
		return NSOrderedAscending;
	return [self compare:other options:mask];
}

- (NSString *)stringAsBibTeXString{
    NSMutableString *mutableString = [NSMutableString stringWithCapacity:[self length] + 2];
    [mutableString appendString:@"{"];
    [mutableString appendString:self];
    [mutableString appendString:@"}"];
	return mutableString;
}

- (NSString *)expandedString{
    return self;
}
        
- (BOOL)hasSubstring:(NSString *)target options:(NSUInteger)opts{
	if ([target isComplex])
		return NO;
	
	NSRange range = [self rangeOfString:target options:opts];
	
	return (range.location != NSNotFound);
}

- (NSString *)stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)replacement options:(NSUInteger)opts replacements:(NSUInteger *)number{
	if ([target isComplex] || [self length] < [target length]) {// we need this last check for anchored search
		*number = 0;
		return self;
	}
	if ([replacement isComplex]) {
		// only replace complete strings by a complex string
		if ([self compare:target options:opts] == NSOrderedSame) {
			*number = 1;
			return [[replacement copy] autorelease];
		} else {
			*number = 0;
			return self;
		}
	}
	
	NSRange searchRange;
	
	if (opts & NSAnchoredSearch) {
		// search at beginning or end of the string, force only a single replacement
		if (opts & NSBackwardsSearch) 
			searchRange = NSMakeRange([self length] - [target length], [target length]);
		else
			searchRange = NSMakeRange(0, [target length]);
	} else {
		searchRange = NSMakeRange(0, [self length]);
	}
	
	NSMutableString *newString = [self mutableCopy];
	*number = [newString replaceOccurrencesOfString:target withString:replacement options:opts range:searchRange];
	
	if (*number > 0) {
		return [newString autorelease];
	} else {
		[newString release];
		return self;
	}
}

- (NSString *)complexStringByAppendingString:(NSString *)string{
    NSString *newString = nil;
    if ([self isEqualToString:@""]) {
        newString = string;
    } else if ([string isComplex]) {
        BDSKStringNode *node = [[BDSKStringNode alloc] initWithQuotedString:self];
        NSMutableArray *nodes = [[NSMutableArray alloc] initWithObjects:node, nil];
        [nodes addObjectsFromArray:[string nodes]];
        newString = [BDSKComplexString stringWithNodes:nodes macroResolver:[string macroResolver]];
        [node release];
        [nodes release];
	} else {
        newString = [self stringByAppendingString:string];
    }
    return newString;
}

@end
