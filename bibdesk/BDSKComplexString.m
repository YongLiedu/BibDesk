#import "BDSKComplexString.h"

@implementation BDSKStringNode

+ (BDSKStringNode *)nodeWithBibTeXString:(NSString *)s{
    BDSKStringNode *node = [[BDSKStringNode alloc] init];

    // a single string - may be a macro or a quoted string.
    s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if([s characterAtIndex:0] == '{'){
        // if it's quoted, strip that and call it a simple string
        s = [s substringFromIndex:1];
        if([s characterAtIndex:([s length] - 1)] == '}'){
            s = [s substringToIndex:([s length] - 1)];
        }
        [node setType:BSN_STRING];
        [node setValue:[[BDSKConverter sharedConverter] stringByDeTeXifyingString:s]];
        return [node autorelease];
        
    }else if([s characterAtIndex:0] == '"'){
        // if it's quoted, strip that and call it a simple string
        s = [s substringFromIndex:1];
        if([s characterAtIndex:([s length] - 1)] == '"'){
            s = [s substringToIndex:([s length] - 1)];
        }
        [node setType:BSN_STRING];
        [node setValue:[[BDSKConverter sharedConverter] stringByDeTeXifyingString:s]];
        return [node autorelease];
        
    }else{
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
	[encoder encodeBool:type forKey:@"type"];
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

// stores system-defined macros
// found in a config plist.
static NSDictionary *globalMacroDefs; 

@implementation BDSKComplexString

+ (void)initialize{
    if (globalMacroDefs == nil){
        NSString *applicationSupportPath = [[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"]
        stringByAppendingPathComponent:@"Application Support"]
        stringByAppendingPathComponent:@"BibDesk"];
        
        NSString *macroDefFile = [applicationSupportPath stringByAppendingPathComponent:@"macroDefinitions.plist"];

        globalMacroDefs = [NSDictionary dictionaryWithContentsOfFile:macroDefFile];
    }
}

+ (BDSKComplexString *)complexStringWithBibTeXString:(NSString *)btstring macroResolver:(id<BDSKMacroResolver>)theMacroResolver{
    BDSKComplexString *cs = nil;
    NSMutableArray *returnNodes = [NSMutableArray array];
    
    btstring = [btstring stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if([btstring length] == 0){
        // if the string was whitespace only, it becomes empty.
        // empty strings are a special case, they are not complex.
        return [BDSKComplexString complexStringWithString:@"" macroResolver:theMacroResolver];
    }
    
    NSScanner *sc = [NSScanner scannerWithString:btstring];    
    NSString *s = nil;
    BOOL scannedSomething = [sc scanUpToString:@"#" intoString:&s];
    if(scannedSomething){
        if([sc isAtEnd]){
            // a single string - may be a macro or a quoted string.

            if([s characterAtIndex:0] == '{'){
                // if it's quoted, strip that and call it a simple string
                s = [s substringFromIndex:1];
                if([s characterAtIndex:[s length] -1 ] == '}'){
                    s = [s substringToIndex:([s length] - 1)];
                }
                
                return [BDSKComplexString complexStringWithString:s macroResolver:theMacroResolver];

           }else if([s characterAtIndex:0] == '"'){
                // if it's quoted, strip that and call it a simple string
                s = [s substringFromIndex:1];
                if([s characterAtIndex:[s length] -1 ] == '"'){
                    s = [s substringToIndex:([s length] - 1)];
                }
                
                return [BDSKComplexString complexStringWithString:s macroResolver:theMacroResolver];

            }else{
                // s must be a single macro
                BDSKStringNode *node = [BDSKStringNode nodeWithBibTeXString:s];
                return [BDSKComplexString complexStringWithArray:[NSArray arrayWithObjects:node, nil] macroResolver:theMacroResolver];
            }
            
        }else{
            // not at end yet, need to build them up:
            BDSKStringNode *node = [BDSKStringNode nodeWithBibTeXString:s];
            [returnNodes addObject:node];
        }
    }else{
        // we found a # as the first char, ignore it.
    }
    
    // if we get to here, we've either added the first node or ignored a leading #.
    // either way, the char at scanLocation is '#' so we skip it:
    if(![sc isAtEnd]){
        [sc setScanLocation:([sc scanLocation] + 1)];
        
        while([sc scanUpToString:@"#" intoString:&s]){
            [returnNodes addObject:[BDSKStringNode nodeWithBibTeXString:s]];
            unsigned loc = [sc scanLocation];
            if(loc == [btstring length]){
                break;
            }
            [sc setScanLocation:([sc scanLocation] + 1)];
        }
    }

    cs = [[BDSKComplexString alloc] init];    
    cs->isComplex = YES;
    cs->nodes = [returnNodes copy];
	if(theMacroResolver)
		[cs setMacroResolver:theMacroResolver];
    else
        NSLog(@"Warning: complex string being created without macro resolver. Macros in it will not be resolved.");

    cs->expandedValue = [[cs expandedValueFromArray:[cs nodes]] retain];
    return [cs autorelease];
    
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
	if (macroResolver)
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
		[self setMacroResolver:[coder encodeConditionalObject:macroResolver forKey:@"macroResolver"]];
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
		if (macroResolver) {
			[[NSNotificationCenter defaultCenter] removeObserver:self];
		}
		macroResolver = newMacroResolver;
		if (isComplex) {
			[expandedValue autorelease];
			expandedValue = [[self expandedValueFromArray:nodes] retain];
		}
		if (newMacroResolver) {
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(handleMacroKeyChangedNotification:)
														 name:BDSKBibDocMacroKeyChangedNotification
													   object:newMacroResolver];
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(handleMacroDefinitionChangedNotification:)
														 name:BDSKBibDocMacroDefinitionChangedNotification
													   object:newMacroResolver];
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(handleMacroDefinitionChangedNotification:)
														 name:BDSKBibDocMacroAddedNotification
													   object:newMacroResolver];
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(handleMacroDefinitionChangedNotification:)
														 name:BDSKBibDocMacroRemovedNotification
													   object:newMacroResolver];
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
	NSString *oldKey = [userInfo objectForKey:@"oldKey"];
	NSString *newKey = [userInfo objectForKey:@"newKey"];
	
	if (isComplex && ([nodes containsObject:oldKey] || [nodes containsObject:newKey])) {
		[expandedValue autorelease];
		expandedValue = [[self expandedValueFromArray:nodes] retain];
	}
}

- (void)handleMacroDefinitionChangedNotification:(NSNotification *)notification{
	NSDictionary *userInfo = [notification userInfo];
	NSString *macroKey = [userInfo objectForKey:@"macroKey"];
	
	if (isComplex && [nodes containsObject:macroKey]) {
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
