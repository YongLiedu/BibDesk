#import "BDSKComplexString.h"
#import "NSSTring_BDSKExtensions.h"

static AGRegex *unquotedHashRegex = nil;
static NSCharacterSet *macroCharSet = nil;

@implementation BDSKStringNode

+ (BDSKStringNode *)nodeWithQuotedString:(NSString *)s{
    BDSKStringNode *node = [[BDSKStringNode alloc] init];
	[node setType:BSN_STRING];
	[node setValue:[[BDSKConverter sharedConverter] stringByDeTeXifyingString:s]];
	return [node autorelease];
}

+ (BDSKStringNode *)nodeWithNumberString:(NSString *)s{
    BDSKStringNode *node = [[BDSKStringNode alloc] init];
	[node setType:BSN_NUMBER];
	[node setValue:s];
	return [node autorelease];
}

+ (BDSKStringNode *)nodeWithMacroString:(NSString *)s{
    BDSKStringNode *node = [[BDSKStringNode alloc] init];
	[node setType:BSN_MACRODEF];
	[node setValue:s];
	return [node autorelease];
}

+ (BDSKStringNode *)nodeWithBibTeXString:(NSString *)s{
    BDSKStringNode *node = [[BDSKStringNode alloc] init];

    // a single string - may be a macro or a quoted string.
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // check that there isn't an unquoted hash mark in there.
    // it's really a latex error, but it's likely to happen here so we check for it.
    if(!unquotedHashRegex) unquotedHashRegex = [[AGRegex alloc] initWithPattern:@"[^\\\\]#"];

    // check for unquoted hash marks:
    //@@todo
    
    // other errors to check for - unbalanced brackets are always an error, even if the quote style is quotes!
    
    unichar startChar = [s characterAtIndex:0];
    unichar endChar;
    if(startChar == '{' || startChar == '"'){        // if it's quoted, strip that and call it a simple string
        if(startChar == '{') endChar = '}';
        else endChar = '"';
        
        s = [s substringFromIndex:1]; // ignore startChar.
        
        if([s characterAtIndex:([s length] - 1)] == endChar){
            s = [s substringToIndex:([s length] - 1)];
        }else{
            // it's an unbalanced string, so we raise
            [NSException raise:@"BDSKComplexStringException" 
                        format:@"Unbalanced string: [%@]", s];
        }
        [node setType:BSN_STRING];
        [node setValue:[[BDSKConverter sharedConverter] stringByDeTeXifyingString:s]];
        return [node autorelease];
        
    }else{
        
        // it doesn't start with a quote, but 
        
        // a single macro
        
        NSCharacterSet *nonDigitCharset = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
        if([s rangeOfCharacterFromSet:nonDigitCharset].location != NSNotFound){
            // if it contains characters that are not digits, it must be a string
            [node setType:BSN_MACRODEF];
        }else{
            // if it doesn't contain characters that are not digits, it is a number.
            [node setType:BSN_NUMBER];
        }
        [node setValue:s];
        return [node autorelease];
    }
    
}

- (void)dealloc{
    [value release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone{
    BDSKStringNode *copy = [[BDSKStringNode allocWithZone:zone] init];
    [copy setType:type];
    [copy setValue:value];
    return copy;
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super init]) {
		[self setType:[coder decodeIntForKey:@"type"]];
		[self setValue:[coder decodeObjectForKey:@"value"]];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder{
	[encoder encodeInt:type forKey:@"type"];
    [encoder encodeObject:value forKey:@"value"];
}

- (BOOL)isEqual:(BDSKStringNode *)other{
    if(type == [other type] &&
       [value isEqualToString:[other value]])
        return YES;
    return NO;
}

- (bdsk_stringnodetype)type {
    return type;
}

- (void)setType:(bdsk_stringnodetype)newType {
    type = newType;
}


- (NSString *)value {
    return [[value retain] autorelease];
}

- (void)setValue:(NSString *)newValue {
    if (value != newValue) {
        [value release];
        value = [newValue copy];
    }
}

- (NSString *)description{
    return [NSString stringWithFormat:@"type: %d, %@", type, value];
}

@end

// stores system-defined macros for the months.
// we grab their localized versions for display.
static NSDictionary *globalMacroDefs; 

@implementation BDSKComplexString

+ (void)initialize{
    if (globalMacroDefs == nil){
        globalMacroDefs = [[NSMutableDictionary alloc] initWithObjects:[[NSUserDefaults standardUserDefaults] objectForKey:NSMonthNameArray]
                                                               forKeys:[NSArray arrayWithObjects:@"jan", @"feb", @"mar", @"apr", @"may", @"jun", @"jul", @"aug", @"sep", @"oct", @"nov", @"dec", nil]];
    }
}

+ (BDSKComplexString *)complexStringWithBibTeXString:(NSString *)btstring macroResolver:(id<BDSKMacroResolver>)theMacroResolver{
    BDSKComplexString *cs = nil;
    NSMutableArray *returnNodes = [NSMutableArray array];
    
    btstring = [btstring stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if([btstring length] == 0){
        // if the string was whitespace only, it becomes empty.
        // empty strings are a special case, they are not complex.
        return [NSString stringWithString:@""];
    }
    
    NSScanner *sc = [NSScanner scannerWithString:btstring];
	[sc setCharactersToBeSkipped:nil];
    NSString *s = nil;
	int nesting;
	unichar ch;
	NSCharacterSet *bracesCharSet = [NSCharacterSet characterSetWithCharactersInString:@"{}"];
	
	if (!macroCharSet) {
		NSMutableCharacterSet *tmpSet = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy] autorelease];
		[tmpSet addCharactersInString:@"\"#%'(),={}"];
		[tmpSet invert];
		macroCharSet = [tmpSet copy];
	}
	
	while (![sc isAtEnd]) {
		ch = [btstring characterAtIndex:[sc scanLocation]];
		if (ch == '{') {
			// a brace-quoted string, we look for the corresponding closing brace
			NSMutableString *nodeStr = [NSMutableString string];
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
				[NSException raise:@"BDSKComplexStringException" 
							format:@"Unbalanced string: [%@]", nodeStr];
			}
			[returnNodes addObject:[BDSKStringNode nodeWithQuotedString:nodeStr]];
		} 
		else if (ch == '"') {
			// a doublequote-quoted string
			NSMutableString *nodeStr = [NSMutableString string];
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
				[NSException raise:@"BDSKComplexStringException" 
							format:@"Unbalanced string: [%@]", nodeStr];
			}
			[returnNodes addObject:[BDSKStringNode nodeWithQuotedString:nodeStr]];
		} 
		else if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:ch]) {
			// this should be all numbers
			[sc scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&s];
			[returnNodes addObject:[BDSKStringNode nodeWithNumberString:s]];
		} 
		else if ([macroCharSet characterIsMember:ch]) {
			// a macro
			if ([sc scanCharactersFromSet:macroCharSet intoString:&s])
				[returnNodes addObject:[BDSKStringNode nodeWithMacroString:s]];
		}
		else if (ch == '#') {
			// we found 2 # or a # at the beginning
			[NSException raise:@"BDSKComplexStringException" 
						format:@"Missing component"];
		} 
		else {
			[NSException raise:@"BDSKComplexStringException" 
						format:@"Invalid first character in component"];
		}
		
		// look for the next #-character, removing spaces around it
		[sc scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
		if (![sc isAtEnd]) {
			if (![sc scanString:@"#" intoString:NULL]) {
				[NSException raise:@"BDSKComplexStringException" 
							format:@"Missing # character"];
			}
			[sc scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
			if ([sc isAtEnd]) {
				// we found a # at the end
				[NSException raise:@"BDSKComplexStringException" 
							format:@"Empty component"];
			}
		}
	}
	
	// if we have a single string-type node, we return an NSString
	if ([returnNodes count] == 1 && [(BDSKStringNode*)[returnNodes objectAtIndex:0] type] == BSN_STRING) {
		return [[returnNodes objectAtIndex:0] value];
	}
	return [BDSKComplexString complexStringWithArray:returnNodes macroResolver:theMacroResolver];
}

// todo: instead, should I override stringWithString?
// using this makes it explicit, which is probably good...
+ (BDSKComplexString *)complexStringWithString:(NSString *)s macroResolver:(id)theMacroResolver{
	BDSKComplexString *cs = [[BDSKComplexString alloc] init];
	cs->isComplex = NO;
	cs->nodes = nil;
	if(theMacroResolver)
		[cs setMacroResolver:theMacroResolver];
    else
        NSLog(@"Warning: complex string being created without macro resolver. Macros in it will not be resolved.");
    
	cs->expandedValue = [s copy]; 
	return [cs autorelease];
}

+ (BDSKComplexString *)complexStringWithArray:(NSArray *)a macroResolver:(id)theMacroResolver{
    BDSKComplexString *cs = [[BDSKComplexString alloc] init];
    cs->isComplex = YES;
    cs->nodes = [a copy];
    if(theMacroResolver)
        [cs setMacroResolver:theMacroResolver];
    else
        NSLog(@"Warning: complex string being created without macro resolver. Macros in it will not be resolved.");
    
    cs->expandedValue = [[cs expandedValueFromArray:[cs nodes]] retain];
        
    return [cs autorelease];

}

- (id)init{
    self = [super init];
    if(self){
        expandedValue = nil;
        isComplex = NO;
    }
    return self;
}

- (void)dealloc{
    [expandedValue release];
	[nodes release];
	if (isComplex && macroResolver)
		[[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone{
    BDSKComplexString *cs = [[BDSKComplexString allocWithZone:zone] init];
    cs->isComplex = isComplex;
    cs->expandedValue = [expandedValue copy];
    cs->nodes = [nodes copy];
	[cs setMacroResolver:macroResolver];
    return cs;
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super initWithCoder:coder]) {
		isComplex = [coder decodeBoolForKey:@"isComplex"];
		nodes = [[coder decodeObjectForKey:@"nodes"] retain];
		expandedValue = [[coder decodeObjectForKey:@"expandedValue"] retain];
		[self setMacroResolver:[coder decodeObjectForKey:@"macroResolver"]];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder{
	[super encodeWithCoder:coder];
    [coder encodeBool:isComplex forKey:@"isComplex"];
    [coder encodeObject:nodes forKey:@"nodes"];
    [coder encodeObject:expandedValue forKey:@"expandedValue"];
    [coder encodeConditionalObject:macroResolver forKey:@"macroResolver"];
}

#pragma mark overridden NSString Methods

- (unsigned int)length{
    return [expandedValue length];
}

- (unichar)characterAtIndex:(unsigned)index{
    return [expandedValue characterAtIndex:index];
}

- (void)getCharacters:(unichar *)buffer{
    [expandedValue getCharacters:buffer];
}

- (void)getCharacters:(unichar *)buffer range:(NSRange)aRange{
    [expandedValue getCharacters:buffer range:aRange];
}


#pragma mark complex string methods

- (BOOL)isComplex {
    return isComplex;
}

- (NSArray *)nodes{
    return nodes;
}

- (id <BDSKMacroResolver>)macroResolver{
    return macroResolver;
}

- (void)setMacroResolver:(id <BDSKMacroResolver>)newMacroResolver{
	if (newMacroResolver != macroResolver) {
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		if (isComplex && macroResolver) {
			[nc removeObserver:self];
		}
		macroResolver = newMacroResolver;
		if (isComplex) {
			[expandedValue autorelease];
			expandedValue = [[self expandedValueFromArray:nodes] retain];
			if (newMacroResolver) {
				[nc addObserver:self
					   selector:@selector(handleMacroKeyChangedNotification:)
						   name:BDSKBibDocMacroKeyChangedNotification
						 object:newMacroResolver];
				[nc addObserver:self
					   selector:@selector(handleMacroDefinitionChangedNotification:)
						   name:BDSKBibDocMacroDefinitionChangedNotification
						 object:newMacroResolver];
			}
		}
	}
}

// Returns the bibtex value of the string.
- (NSString *)nodesAsBibTeXString{
    BDSKConverter *conv = [BDSKConverter sharedConverter];
    int i = 0;
    NSMutableString *retStr = [NSMutableString string];
    if(!isComplex){
        [retStr appendFormat:@"{%@}", expandedValue];
        return [conv stringByTeXifyingString:retStr];
    }
        
    for( i = 0; i < [nodes count]; i++){
        BDSKStringNode *valNode = [nodes objectAtIndex:i];
        if (i != 0){
            [retStr appendString:@" # "];
        }
        
        if([valNode type] == BSN_STRING){
            [retStr appendFormat:@"{%@}", [conv stringByTeXifyingString:[valNode value]]];
        }else{
            [retStr appendString:[conv stringByTeXifyingString:[valNode value]]];
        }
    }
    
    return retStr; 
}

- (NSString *)expandedValueFromArray:(NSArray *)a{
    NSMutableString *s = [[NSMutableString alloc] initWithCapacity:10];
    int i =0;
    
    for(i = 0 ; i < [a count]; i++){
        BDSKStringNode *node = [a objectAtIndex:i];
        if([node type] == BSN_MACRODEF){
            NSString *exp = nil;
            if(macroResolver)
                exp = [macroResolver valueOfMacro:[node value]];
            if (exp){
                [s appendString:exp];
            }else{
                // there was no expansion. Check the system global dict first.
                NSString *globalExp = [globalMacroDefs objectForKey:[node value]];
                if(globalExp) 
                    [s appendString:globalExp];
                else 
                    [s appendString:[node value]];
            }
        }else{
            [s appendString:[node value]];
        }
    }
    [s autorelease];
    return [[s copy] autorelease];
}

- (void)handleMacroKeyChangedNotification:(NSNotification *)notification{
	NSDictionary *userInfo = [notification userInfo];
	BDSKStringNode *oldMacroNode = [BDSKStringNode nodeWithBibTeXString:[userInfo objectForKey:@"oldKey"]];
	BDSKStringNode *newMacroNode = [BDSKStringNode nodeWithBibTeXString:[userInfo objectForKey:@"newKey"]];
	
	if (isComplex && ([nodes containsObject:oldMacroNode] || [nodes containsObject:newMacroNode])) {
		[expandedValue autorelease];
		expandedValue = [[self expandedValueFromArray:nodes] retain];
	}
}

- (void)handleMacroDefinitionChangedNotification:(NSNotification *)notification{
	NSDictionary *userInfo = [notification userInfo];
	BDSKStringNode *macroNode = [BDSKStringNode nodeWithBibTeXString:[userInfo objectForKey:@"macroKey"]];
	
	if (isComplex && [nodes containsObject:macroNode]) {
		[expandedValue autorelease];
		expandedValue = [[self expandedValueFromArray:nodes] retain];
	}
}

@end

@implementation NSString (ComplexStringEquivalence)

- (BOOL)isEqualAsComplexString:(NSString *)other{
	// simple = NSString or not complex
	BOOL isSelfSimple = !([self isKindOfClass:[BDSKComplexString class]] &&
						  [(BDSKComplexString*)self isComplex]);
	BOOL isOtherSimple = !([other isKindOfClass:[BDSKComplexString class]] &&
						   [(BDSKComplexString*)other isComplex]);
	if (isSelfSimple != isOtherSimple)
		return NO; // really complex strings are never equivalent to simple strings
	if (isSelfSimple)
		return [self isEqualToString:other]; // this compares (expanded) values
	// now both have to be really complex
	return [[(BDSKComplexString*)self nodes] isEqualToArray:[(BDSKComplexString*)other nodes]];
}

@end
