//  BibItem.m
//  Created by Michael McCracken on Tue Dec 18 2001.
/*
 This software is Copyright (c) 2001,2002, Michael O. McCracken
 All rights reserved.

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


#import "BibItem.h"

#define addkey(s) if([pubFields objectForKey: s] == nil){[pubFields setObject:@"" forKey: s];} [removeKeys removeObject: s];

#define isEmptyField(s) ([[[pubFields objectForKey:s] stringValue] isEqualToString:@""])

/* Fonts and paragraph styles cached for efficiency. */
static NSDictionary* _cachedFonts = nil; // font cached across all BibItems for speed.
static NSParagraphStyle* _keyParagraphStyle = nil;
static NSParagraphStyle* _bodyParagraphStyle = nil;

// private function to get the cached Font.
void _setupFonts(){
    NSMutableParagraphStyle* defaultStyle = nil;
    if(_cachedFonts == nil){
        defaultStyle = [[NSMutableParagraphStyle alloc] init];
        [defaultStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
        if([NSFont fontWithName:@"Gill Sans" size:10.0] == nil){ // Gill Sans is our preferred font, but we'll fall back on the system font if Gill Sans isn't available
            _cachedFonts = [[NSDictionary dictionaryWithObjectsAndKeys:
                [NSFont boldSystemFontOfSize:14.0], @"Title",
                [NSFont systemFontOfSize:10.0], @"Type",
                [NSFont boldSystemFontOfSize:12.0], @"Key",
                [NSFont systemFontOfSize:12.0], @"Body",
                nil] retain]; // we'll never release this
        } else {
            _cachedFonts = [[NSDictionary dictionaryWithObjectsAndKeys:
                [NSFont fontWithName:@"Gill Sans Bold Italic" size:14.0], @"Title",
                [NSFont fontWithName:@"Gill Sans" size:10.0], @"Type",
                [NSFont fontWithName:@"Gill Sans Bold" size:12.0], @"Key",
                [NSFont fontWithName:@"Gill Sans" size:12.0], @"Body",
                nil] retain]; // we'll never release this
        }
        
// ?        [defaultStyle setAlignment:NSLeftTextAlignment];
        _keyParagraphStyle = [defaultStyle copy];
        [defaultStyle setHeadIndent:50];
        [defaultStyle setFirstLineHeadIndent:50];
        [defaultStyle setTailIndent:-30];
        _bodyParagraphStyle = [defaultStyle copy];
    }
}

@implementation BibItem

- (id)init
{
	OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
	self = [self initWithType:[pw stringForKey:BDSKPubTypeStringKey]
									  fileType:@"BibTeX" // Not Sure if this is good.
									   authors:[NSMutableArray arrayWithCapacity:0]];
	return self;
}

- (id)initWithType:(NSString *)type fileType:(NSString *)inFileType authors:(NSMutableArray *)authArray{ // this is the designated initializer.
    if (self = [super init]){
        pubFields = [[NSMutableDictionary alloc] init];
        requiredFieldNames = [[NSMutableArray alloc] init];
        pubAuthors = [authArray mutableCopy];     // copy, it's mutable
        document = nil;
        editorObj = nil;
        [self setFileType:inFileType];
        [self makeType:type];
        [self setCiteKeyString: @"cite-key"];
        [self setDate: nil];
        [self setDateCreated: nil];
        [self setDateModified: nil];
        [self setFileOrder:-1];
        _setupFonts();
    }

    //NSLog(@"bibitem init");
    return self;
}

- (id)copyWithZone:(NSZone *)zone{
    BibItem *theCopy = [[[self class] allocWithZone: zone] initWithType:pubType
                                                               fileType:fileType
                                                                authors:pubAuthors];
    [theCopy setCiteKeyString: citeKey];
    [theCopy setDate: pubDate];
	
    NSCalendarDate *currentDate = [NSCalendarDate calendarDate];
    [theCopy setDateModified:currentDate];
    [theCopy setDateCreated:currentDate];
	
    [theCopy setPubFields: pubFields];
    [theCopy setRequiredFieldNames: requiredFieldNames];
    return theCopy;
}

- (id)initWithCoder:(NSCoder *)coder{
    self = [super init];
    [self setFileType:[coder decodeObjectForKey:@"fileType"]];
    [self setCiteKey:[coder decodeObjectForKey:@"citeKey"]];
    [self setDate:[coder decodeObjectForKey:@"pubDate"]];
    [self setDateCreated:[coder decodeObjectForKey:@"dateCreated"]];
    [self setDateModified:[coder decodeObjectForKey:@"dateModified"]];
    [self setType:[coder decodeObjectForKey:@"pubType"]];
    pubFields = [[coder decodeObjectForKey:@"pubFields"] retain];
    pubAuthors = [[coder decodeObjectForKey:@"pubAuthors"] retain];
    requiredFieldNames = [[coder decodeObjectForKey:@"requiredFieldNames"] retain];
    [self setFileOrder:[coder decodeIntForKey:@"fileOrder"]];
    // set by the document, which we don't archive
    document = nil;
    editorObj = nil;
    if(_cachedFonts == nil)
        _setupFonts();
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder{
    [coder encodeObject:fileType forKey:@"fileType"];
    [coder encodeObject:citeKey forKey:@"citeKey"];
    [coder encodeObject:pubDate forKey:@"pubDate"];
    [coder encodeObject:dateCreated forKey:@"dateCreated"];
    [coder encodeObject:dateModified forKey:@"dateModified"];
    [coder encodeObject:pubType forKey:@"pubType"];
    [coder encodeObject:pubFields forKey:@"pubFields"];
    [coder encodeObject:pubAuthors forKey:@"pubAuthors"];
    [coder encodeObject:requiredFieldNames forKey:@"requiredFieldNames"];
    [coder encodeInt:_fileOrder forKey:@"fileOrder"];
}

- (void)makeType:(NSString *)type{
    
    NSString *fieldString;
    NSEnumerator *e;
    NSString *tmp;
    BibTypeManager *typeMan = [BibTypeManager sharedManager];
    NSMutableArray *removeKeys = [[typeMan allRemovableFieldNames] mutableCopy];
    NSEnumerator *reqFieldsE = [[typeMan requiredFieldsForType:type] objectEnumerator];
    NSEnumerator *optFieldsE = [[typeMan optionalFieldsForType:type] objectEnumerator];
    NSEnumerator *defFieldsE = [[typeMan userDefaultFieldsForType:type] objectEnumerator];
  
    while(fieldString = [reqFieldsE nextObject]){
        addkey(fieldString)
    }
    while(fieldString = [optFieldsE nextObject]){
        addkey(fieldString)
    }
    while(fieldString = [defFieldsE nextObject]){
        addkey(fieldString)
    }    
    
    //I don't enforce Keywords, but since there's GUI depending on them, I will enforce these others:
    addkey(@"Url") addkey(@"Local-Url") addkey(@"Annote") addkey(@"Abstract") addkey(@"Rss-Description")

        // remove from removeKeys things that aren't == @"" in pubFields
        // this includes things left over from the previous bibtype - that's good.
        e = [[pubFields allKeys] objectEnumerator];

    while (tmp = [e nextObject]) {
        if (![[pubFields objectForKey:tmp] isEqualToString:@""]) {
            [removeKeys removeObject:tmp];
        }
    }
    // now remove everything that's left in remove keys from pubfields
    [pubFields removeObjectsForKeys:removeKeys];
    [removeKeys release];
    // and don't forget to set what we say our type is:
    [self setType:type];
	[self setRequiredFieldNames:[typeMan requiredFieldsForType:type]];
}

//@@ type - move to type class
- (BOOL)isRequired:(NSString *)rString{
    if([requiredFieldNames indexOfObject:rString] == NSNotFound)
        return NO;
    else
        return YES;
}

- (void)dealloc{
#ifdef DEBUG
    NSLog([NSString stringWithFormat:@"bibitem Dealloc, rt: %d", [self retainCount]]);
#endif
    [[self undoManager] removeAllActionsWithTarget:self];
    [pubFields release];
    [requiredFieldNames release];
    [pubAuthors release];

    [pubType release];
    [fileType release];
    [citeKey release];
    [pubDate release];
    [dateCreated release];
    [dateModified release];
	
    [super dealloc];
}

- (BibDocument *)document {
    return document;
}

- (void)setDocument:(BibDocument *)newDocument {
    document = newDocument;
}

- (NSUndoManager *)undoManager { // this may be nil
    return [document undoManager];
}

- (BibEditor *)editorObj{
    return editorObj; // if we haven't been given an editor object yet this should be nil.
}

- (void)setEditorObj:(BibEditor *)editor{
    editorObj = editor; // don't retain it- that will create a cycle!
}

- (NSString *)description{
    return [NSString stringWithFormat:@"%@ %@", [self citeKey], [pubFields description]];
}


- (BOOL)isEqual:(BibItem *)aBI{
    BOOL yn = ([citeKey isEqualToString:[aBI citeKey]]) && 
              ([pubType isEqualToString:[aBI type]]) &&
              ([[self title] isEqualToString:[aBI title]]);
    // NSLog(@"isEqual returns %i", yn);
    return yn;
}

- (unsigned)hash{
    return [citeKey hash];
}

- (NSMutableArray*) requiredFieldNames {
    // rather return a copy?
    return requiredFieldNames;
}

#pragma mark Comparison functions
- (NSComparisonResult)pubTypeCompare:(BibItem *)aBI{
	return [[self type] caseInsensitiveCompare:[aBI type]];
}

- (NSComparisonResult)keyCompare:(BibItem *)aBI{
    return [citeKey caseInsensitiveCompare:[aBI citeKey]];
}

- (NSComparisonResult)titleCompare:(BibItem *)aBI{
    return [[self title] caseInsensitiveCompare:[aBI title]];
}

- (NSComparisonResult)dateCompare:(BibItem *)aBI{
	NSCalendarDate *aDate = [aBI date];
	if (pubDate == nil) {
		return (aDate == nil)? NSOrderedSame : NSOrderedDescending;
	} else if (aDate == nil) {
		return NSOrderedAscending;
	}
	return [pubDate compare:aDate];
}

- (NSComparisonResult)createdDateCompare:(BibItem *)aBI{
	NSCalendarDate *aDate = [aBI dateCreated];
	if (pubDate == nil) {
		return (aDate == nil)? NSOrderedSame : NSOrderedDescending;
	} else if (aDate == nil) {
		return NSOrderedAscending;
	}
	return [dateCreated compare:aDate];
}

- (NSComparisonResult)modDateCompare:(BibItem *)aBI{
	NSCalendarDate *aDate = [aBI dateModified];
	if (pubDate == nil) {
		return (aDate == nil)? NSOrderedSame : NSOrderedDescending;
	} else if (aDate == nil) {
		return NSOrderedAscending;
	}
	return [dateModified compare:aDate];
}



- (NSComparisonResult)auth1Compare:(BibItem *)aBI{
    if([pubAuthors count] > 0){
        if([aBI numberOfAuthors] > 0){
            return [[self authorAtIndex:0] compare:
                [aBI authorAtIndex:0]];
        }
        return NSOrderedAscending;
    }else{
        return NSOrderedDescending;
    }
}
- (NSComparisonResult)auth2Compare:(BibItem *)aBI{
    if([pubAuthors count] > 1){
        if([aBI numberOfAuthors] > 1){
            return [[self authorAtIndex:1] compare:
                [aBI authorAtIndex:1]];
        }
        return NSOrderedAscending;
    }else{
        return NSOrderedDescending;
    }
}
- (NSComparisonResult)auth3Compare:(BibItem *)aBI{
    if([pubAuthors count] > 2){
        if([aBI numberOfAuthors] > 2){
            return [[self authorAtIndex:2] compare:
                [aBI authorAtIndex:2]];
        }
        return NSOrderedAscending;
    }else{
        return NSOrderedDescending;
    }
}

- (NSComparisonResult)fileOrderCompare:(BibItem *)aBI{
    int aBIOrd = [aBI fileOrder];
    if (_fileOrder == -1) return NSOrderedDescending; //@@ file order for crossrefs - here is where we would change to accommodate new pubs in crossrefs...
    if (_fileOrder < aBIOrd) {
        return NSOrderedAscending;
    }
    if (_fileOrder > aBIOrd){
        return NSOrderedDescending;
    }else{
        return NSOrderedSame;
    }
}

// accessors for fileorder
- (int)fileOrder{
    return _fileOrder;
}

- (void)setFileOrder:(int)ord{
    _fileOrder = ord;
}
- (NSString *)fileType { return fileType; }

- (void)setFileType:(NSString *)someFileType {
    [someFileType retain];
    [fileType release];
    fileType = someFileType;
}

#pragma mark Author Handling code

- (int)numberOfAuthors{
    return [pubAuthors count];
}

- (void)addAuthorWithName:(NSString *)newAuthorName{
    NSEnumerator *presentAuthE = nil;
    BibAuthor *bibAuthor = nil;
    BibAuthor *existingAuthor = nil;
  
    presentAuthE = [pubAuthors objectEnumerator];
    while(bibAuthor = [presentAuthE nextObject]){
        if([[bibAuthor name] isEqualToString:newAuthorName]){ // @@ TODO: fuzzy author handling
            existingAuthor = bibAuthor;
        }
    }
    if(!existingAuthor){
        existingAuthor =  [BibAuthor authorWithName:newAuthorName andPub:self]; //@@author - why was andPub:nil before?!
        [pubAuthors addObject:existingAuthor];
    }
    return;
}

- (NSArray *)pubAuthors{
    return pubAuthors;
}

- (BibAuthor *)authorAtIndex:(int)index{ 
    if ([pubAuthors count] > index)
        return [pubAuthors objectAtIndex:index];
    else
        return nil;
}

- (void)setAuthorsFromBibtexString:(NSString *)aString{
    
    if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKUseUnicodeBibTeXParser]){
        NSArray *auths = [aString componentsSeparatedByString:@" and "];
        NSEnumerator *e = [auths objectEnumerator];
        NSString *aString = nil;
        
        [pubAuthors removeAllObjects];
        
        while(aString = [e nextObject]){
            [self addAuthorWithName:[aString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
        }
        return;
    }
            
    char *str = nil;

    if (aString == nil) return;

    if(![aString canBeConvertedToEncoding:[NSString defaultCStringEncoding]]){
	NSLog(@"An author name could not be displayed losslessly.");
	NSLog(@"Using lossy encoding for %@", aString);
	str = (char *)[aString lossyCString];
    } else  str = (char *)[aString cString];
    
//    [aString getCString:str]; // str will be autoreleased. (freed?)
    bt_stringlist *sl = nil;
    int i=0;
#warning - Exception - might want to add an exception handler that notifies the user of the warning...
    [pubAuthors removeAllObjects];
    sl = bt_split_list(str, "and", "BibTex Name", 1, "inside setAuthorsFromBibtexString");
    if (sl != nil) {
        for(i=0; i < sl->num_items; i++){
            if(sl->items[i] != nil){
				NSString *s = [NSString stringWithCString: sl->items[i]];
                [self addAuthorWithName:s];
                
            }
        }
        bt_free_list(sl); // hey! got to free the memory!
    }
    //    NSLog(@"%@", pubAuthors);
}

- (NSString *)bibtexAuthorString{
    NSEnumerator *en = [pubAuthors objectEnumerator];
    BibAuthor *author;
    if([pubAuthors count] == 0) return [NSString stringWithString:@""];
    if([pubAuthors count] == 1){
        author = [pubAuthors objectAtIndex:0];
        return [author name];
    }else{
		NSMutableString *rs;
        author = [en nextObject];
        rs = [NSMutableString stringWithString:[author name]];
        // since this method is used for display, BibAuthor -name is right above.
        
        while(author = [en nextObject]){
            [rs appendFormat:@" and %@", [author name]];
        }
        return rs;
    }
        
}

- (NSString *)title{
  NSString *t = [pubFields objectForKey: @"Title"];
  if(t == nil)
    return @"Empty Title";
  else
    return t;
}

- (void)setTitle:(NSString *)title{
  [self setField:@"Title" toValue:title];
}

- (void)setDate: (NSCalendarDate *)newDate{
    [pubDate autorelease];
    pubDate = [newDate copy];
    
}
- (NSCalendarDate *)date{
    return pubDate;
}

- (NSCalendarDate *)dateCreated {
    return [[dateCreated retain] autorelease];
}

- (void)setDateCreated:(NSCalendarDate *)newDateCreated {
    if (dateCreated != newDateCreated) {
        [dateCreated release];
        dateCreated = [newDateCreated copy];
    }
}

- (NSCalendarDate *)dateModified {
    return [[dateModified retain] autorelease];
}

- (NSString *)calendarDateDescription{
    return [pubDate descriptionWithCalendarFormat:@"%B %Y"];
}

- (void)setDateModified:(NSCalendarDate *)newDateModified {
    if (dateModified != newDateModified) {
        [dateModified release];
        dateModified = [newDateModified copy];
    }
}

- (void)setType: (NSString *)newType{
    [pubType autorelease];
    pubType = [newType retain];
}
- (NSString *)type{
    return pubType;
}

- (NSString *)suggestedCiteKey
{
	NSString *citeKeyFormat = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKCiteKeyFormatKey];
	return [self parseFormat:citeKeyFormat forField:@"Cite Key"];
}

- (BOOL)canSetCiteKey
{
	NSEnumerator *fEnum = [[[NSApp delegate] requiredFieldsForCiteKey] objectEnumerator];
	NSString *fieldName;
	NSString *fieldValue = [self citeKey];
	
	if (fieldValue != nil && ![fieldValue isEqualToString:@""] && ![fieldValue isEqualToString:@"cite-key"]) {
		return NO;
	}
	while (fieldName = [fEnum nextObject]) {
		fieldValue = [self valueOfField:fieldName];
		if (fieldValue == nil || [fieldValue isEqualToString:@""]) {
			return NO;
		}
	}
	return YES;
}

- (void)setCiteKey:(NSString *)newCiteKey{
    if ([self undoManager]) {
        [[[self undoManager] prepareWithInvocationTarget:self] setCiteKey:citeKey];
        [[self undoManager] setActionName:NSLocalizedString(@"Change Cite Key",@"")];
    }
	
    [self setCiteKeyString:newCiteKey];
		
    NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:citeKey, @"value", @"Cite Key", @"key",nil];
    NSNotification *aNotification = [NSNotification notificationWithName:BDSKBibItemChangedNotification
                                                                  object:self
                                                                userInfo:notifInfo];
    // Queue the notification, since this can be expensive when opening large files
    [[NSNotificationQueue defaultQueue] enqueueNotification:aNotification
                                               postingStyle:NSPostWhenIdle
                                               coalesceMask:NSNotificationCoalescingOnName
                                                   forModes:nil];
}

- (void)setCiteKeyString:(NSString *)newCiteKey{
    [citeKey autorelease];
		
    citeKey = [newCiteKey copy];
}

- (NSString *)citeKey{
    if(!citeKey){
        [self setCiteKey:@""]; 
    }
    return citeKey;
}

- (void)setPubFields: (NSDictionary *)newFields{
	if(newFields != pubFields){
		[pubFields release];
		pubFields = [newFields mutableCopy];
		[self updateMetadataForKey:nil];
    }
}

- (void)setFields: (NSDictionary *)newFields{
	if(![newFields isEqualToDictionary:pubFields]){
		if ([self undoManager]) {
			[[[self undoManager] prepareWithInvocationTarget:self] setFields:pubFields];
			[[self undoManager] setActionName:NSLocalizedString(@"Change All Fields",@"")];
		}
		
		[self setPubFields:newFields];
		
		NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Add/Del Fields", @"type", nil]; // cmh: maybe not the best info, but handled correctly
		[[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification
															object:self
														  userInfo:notifInfo];
    }
}

- (void)updateMetadataForKey:(NSString *)key{
    NSMutableString *tmp = [NSMutableString string];
	
	if([@"Annote" isEqualToString:key] || 
	   [@"Abstract" isEqualToString:key] || 
	   [@"Rss-Description" isEqualToString:key]){
		// don't do anything for fields we don't need to update.
		return;
	}

    if((![@"" isEqualToString:[pubFields objectForKey: @"Author"]]) && 
	   ([pubFields objectForKey: @"Author"] != nil))
    {
        [self setAuthorsFromBibtexString:[pubFields objectForKey: @"Author"]];
    }else{
        [self setAuthorsFromBibtexString:[pubFields objectForKey: @"Editor"]]; // or what else?
    }
	
    // re-call make type to make sure we still have all the appropriate bibtex defined fields...
	//@@ 3/5/2004: moved why is this here? 
	[self makeType:[self type]];

	NSString *yearValue = [pubFields objectForKey:@"Year"];
    if (yearValue && ![yearValue isEqualToString:@""]) {
		
		NSString *monthValue = [pubFields objectForKey:@"Month"];
        if (monthValue && ![monthValue isEqualToString:@""]) {
			[tmp appendString:monthValue];
			[tmp appendString:@" 1 "];
		}else{
			[tmp appendString:@"1 1 "];
    	}
        [tmp appendString:[pubFields objectForKey:@"Year"]];
		NSMutableDictionary *locale = [[[[NSUserDefaults standardUserDefaults] persistentDomainForName:NSGlobalDomain] mutableCopy] autorelease];
		[locale setObject:@"MDYH" forKey:NSDateTimeOrdering];
        [self setDate:[NSCalendarDate dateWithNaturalLanguageString:tmp locale:locale]];
    }else{
        [self setDate:nil];    // nil means we don't have a good date.
    }
	
	NSString *dateCreatedValue = [pubFields objectForKey:BDSKDateCreatedString];
    if (dateCreatedValue && ![dateCreatedValue isEqualToString:@""]) {
		[self setDateCreated:[NSCalendarDate dateWithNaturalLanguageString:dateCreatedValue]];
	}else{
		[self setDateCreated:nil];
	}
	
	NSString *dateModValue = [pubFields objectForKey:BDSKDateModifiedString];
    if (dateModValue && ![dateModValue isEqualToString:@""]) {
		// NSLog(@"updating date %@", dateModValue);
		[self setDateModified:[NSCalendarDate dateWithNaturalLanguageString:dateModValue]];
	}else{
		[self setDateModified:nil];
	}
	
}

- (void)setRequiredFieldNames: (NSArray *)newRequiredFieldNames{
    [requiredFieldNames autorelease];
    requiredFieldNames = [newRequiredFieldNames mutableCopy];
}

- (void)setField: (NSString *)key toValue: (NSString *)value{
	[self setField:key toValue:value withModDate:[NSCalendarDate date]];
}

- (void)setField:(NSString *)key toValue:(NSString *)value withModDate:(NSCalendarDate *)date{
	if ([self undoManager]) {
		id oldValue = [pubFields objectForKey:key];
		NSCalendarDate *oldModDate = [self dateModified];
		
		[[[self undoManager] prepareWithInvocationTarget:self] setField:key 
														 toValue:oldValue
													 withModDate:oldModDate];
		[[self undoManager] setActionName:NSLocalizedString(@"Edit publication",@"")];
	}
	
    [pubFields setObject: value forKey: key];
	if (date != nil) {
		[pubFields setObject:[date description] forKey:BDSKDateModifiedString];
	}
	[self updateMetadataForKey:key];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:value, @"value", key, @"key", @"Change", @"type",nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification
														object:self
													  userInfo:notifInfo];
    // to allow autocomplete:
	[[NSApp delegate] addString:value forCompletionEntry:key];
}

// for 10.2
- (id)handleQueryWithUnboundKey:(NSString *)key{
    return [self valueForUndefinedKey:key];
}

- (id)valueForUndefinedKey:(NSString *)key{
    id obj = [pubFields objectForKey:key];
    if (obj != nil){
        return obj;
    }else{
        // handle 10.2
        if ([super respondsToSelector:@selector(valueForUndefinedKey:)]){
            return [super valueForUndefinedKey:key];
        }else{
            return [super handleQueryWithUnboundKey:key];
        }
    }
}

- (NSString *)valueOfField: (NSString *)key{
    NSString* value = [pubFields objectForKey:key];
	return [[value retain] autorelease];
}

- (NSString *)acronymValueOfField:(NSString *)key{
    NSMutableString *result = [NSMutableString string];
    NSArray *allComponents = [[self valueOfField:key] componentsSeparatedByString:@" "]; // single whitespace
    NSEnumerator *e = [allComponents objectEnumerator];
    NSString *component = nil;
    
    while(component = [e nextObject]){
        component = [component stringByTrimmingCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]];
        if([component length] > 3){
            [result appendString:[[component substringToIndex:1] uppercaseString]];
        }
    }
    return result;
}

- (void)addField:(NSString *)key{
	[self addField:key withModDate:[NSCalendarDate date]];
}

- (void)addField:(NSString *)key withModDate:(NSCalendarDate *)date{
	if ([self undoManager]) {
		[[[self undoManager] prepareWithInvocationTarget:self] removeField:key
														withModDate:[self dateModified]];
	}
	
	NSString *msg = [NSString stringWithFormat:@"%@ %@",
		NSLocalizedString(@"Add data for field:", @""), key];
	[pubFields setObject:msg forKey:key];
	
	NSString *dateString = [date description];
	[pubFields setObject:dateString forKey:BDSKDateModifiedString];
	[self updateMetadataForKey:key];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Add/Del Field", @"type",nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification
														object:self
													  userInfo:notifInfo];

}

- (void)removeField: (NSString *)key{
	[self removeField:key withModDate:[NSCalendarDate date]];
}

- (void)removeField: (NSString *)key withModDate:(NSCalendarDate *)date{
	
	if ([self undoManager]) {
		[[[self undoManager] prepareWithInvocationTarget:self] addField:key
													 withModDate:[self dateModified]];
	}
	
    [pubFields removeObjectForKey:key];
	
	NSString *dateString = [date description];
	[pubFields setObject:dateString forKey:BDSKDateModifiedString];
	[self updateMetadataForKey:key];

	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Add/Del Field", @"type",nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification
														object:self
													  userInfo:notifInfo];
	
}

- (NSMutableDictionary *)pubFields{
    return [[pubFields retain] autorelease];
}

- (NSData *)PDFValue{
    // Obtain the PDF of a bibtex formatted version of the bibtex entry as is.
    //* we won't be doing this on a per-item basis. this is deprecated. */
    return [[self title] dataUsingEncoding:NSUnicodeStringEncoding allowLossyConversion:YES];
}

- (NSData *)RTFValue{
    NSString *key;
    NSEnumerator *e = [[[pubFields allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] objectEnumerator];

    NSDictionary *titleAttributes =
        [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[_cachedFonts objectForKey:@"Title"], _keyParagraphStyle, nil]
                                    forKeys:[NSArray arrayWithObjects:NSFontAttributeName,  NSParagraphStyleAttributeName, nil]];

    NSDictionary *typeAttributes =
        [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[_cachedFonts objectForKey:@"Type"], [NSColor colorWithCalibratedWhite:0.4 alpha:0.0], nil]
                                    forKeys:[NSArray arrayWithObjects:NSFontAttributeName, NSForegroundColorAttributeName, nil]];

    NSDictionary *keyAttributes =
        [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[_cachedFonts objectForKey:@"Key"], _keyParagraphStyle, nil]
                                    forKeys:[NSArray arrayWithObjects:NSFontAttributeName, NSParagraphStyleAttributeName, nil]];

    NSDictionary *bodyAttributes =
        [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[_cachedFonts objectForKey:@"Body"],
          /*  [NSColor colorWithCalibratedWhite:0.9 alpha:0.0], */
            _bodyParagraphStyle, nil]
                                    forKeys:[NSArray arrayWithObjects:NSFontAttributeName, /*NSBackgroundColorAttributeName, */NSParagraphStyleAttributeName, nil]];

    NSMutableAttributedString* aStr = [[[NSMutableAttributedString alloc] init] autorelease];

    NSMutableArray *nonReqKeys = [NSMutableArray arrayWithCapacity:5]; // yep, arbitrary

    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] initWithDateFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSDateFormatString]
                                                         allowNaturalLanguage:NO] autorelease];
    
    [aStr appendAttributedString:[[[NSMutableAttributedString alloc] initWithString:
                      [NSString stringWithFormat:@"%@\n",[self citeKey]] attributes:typeAttributes] autorelease]];
    [aStr appendAttributedString:[[[NSMutableAttributedString alloc] initWithString:
                     [NSString stringWithFormat:@"%@ ",[self title]] attributes:titleAttributes] autorelease]];

    
    [aStr appendAttributedString:[[[NSMutableAttributedString alloc] initWithString:
                       [NSString stringWithFormat:@"(%@)\n",[self type]] attributes:typeAttributes] autorelease]];

    

    while(key = [e nextObject]){
        if(![[pubFields objectForKey:key] isEqualToString:@""] &&
           ![key isEqualToString:@"Title"]){
            if([self isRequired:key]){
                [aStr appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",key]
                                                                              attributes:keyAttributes] autorelease]];

                [aStr appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",[pubFields objectForKey:key]]
                                                                              attributes:bodyAttributes] autorelease]];
            }else{
                [nonReqKeys addObject:key];
            }
        }
    }// end required keys
    
    e = [nonReqKeys objectEnumerator];
    while(key = [e nextObject]){
        if(![[pubFields objectForKey:key] isEqualToString:@""]){
            [aStr appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",key]
                                                                          attributes:keyAttributes] autorelease]];
            
            if([key isEqualToString:@"Date-Added"] || 
               [key isEqualToString:@"Date-Modified"]){
                NSCalendarDate *date = [NSCalendarDate dateWithString:[pubFields objectForKey:key]];

                [aStr appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",[dateFormatter stringForObjectValue:date]]
                                                                              attributes:bodyAttributes] autorelease]];

            }else{
                [aStr appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",[pubFields objectForKey:key]]
                                                                              attributes:bodyAttributes] autorelease]];
            }

        }
    }

    [aStr appendAttributedString:[[[NSAttributedString alloc] initWithString:@" "
                                                                  attributes:nil] autorelease]];


    return 	[aStr RTFFromRange:NSMakeRange(0,[aStr length]) documentAttributes:nil];
}

- (NSString *)bibTeXString{
    NSString *k;
    NSString *v;
    NSMutableString *s = [[[NSMutableString alloc] init] autorelease];
    NSArray *keys = [[pubFields allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSEnumerator *e = [keys objectEnumerator];

    //build BibTeX entry:
    [s appendString:@"@"];
    [s appendString:pubType];
    [s appendString:@"{"];
    [s appendString:[self citeKey]];
    while(k = [e nextObject]){
        // Get TeX version of each field.
	// Don't run the converter on Local-Url or Url fields, so we don't trash ~ and % escapes.
	// Note that NSURLs comply with RFC 2396, and can't contain high-bit characters anyway.
	if([k isEqualToString:@"Local-Url"] || [k isEqualToString:@"Url"]){
	    v = [pubFields objectForKey:k];
	} else {
	    v = [[BDSKConverter sharedConverter] stringByTeXifyingString:[pubFields objectForKey:k]];
	}
	
        if(![v isEqualToString:@""]){
            [s appendString:@",\n\t"];
            [s appendFormat:@"%@ = {%@}",k,v];
        }
    }
    [s appendString:@"}"];
    return s;
}

- (NSString *)unicodeBibTeXString{
    NSString *k;
    NSString *v;
    NSMutableString *s = [[[NSMutableString alloc] init] autorelease];
    NSArray *keys = [[pubFields allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSEnumerator *e = [keys objectEnumerator];
    
    //build BibTeX entry:
    [s appendString:@"@"];
    [s appendString:pubType];
    [s appendString:@"{"];
    [s appendString:[self citeKey]];
    while(k = [e nextObject]){
        v = [pubFields objectForKey:k];
	
        if(![v isEqualToString:@""]){
            [s appendString:@",\n\t"];
            [s appendFormat:@"%@ = {%@}",k,v];
        }
    }
    [s appendString:@"}"];
    return s;
}
    
#warning not currently XML entity-escaped !!
- (NSString *)MODSString{
    NSDictionary *genreForTypeDict = [[BibTypeManager sharedManager] MODSGenresForBibTeXType:pubType];
    NSMutableString *s = [NSMutableString stringWithString:@"<mods>"];
    int i = 0;
    
    [s appendFormat:@"<titleInfo> <title>%@ </title>", [self valueOfField:@"Title"]];
    
    // note: may in the future want to output subtitles.

    [s appendString:@"</titleInfo>\n"];
    
    foreach (author, pubAuthors){
        [s appendString:[author MODSStringWithRole:@"author"]];
        [s appendString:@"\n"];
    }

    // NOTE: this isn't always text. what are the special case pubtypes?
    [s appendString:@"<typeOfResource>text</typeOfResource>"];
    
    NSArray *genresForSelf = [genreForTypeDict objectForKey:@"self"];
    if(genresForSelf){
        for(i = 0; i < [genresForSelf count]; i++){
            [s appendFormat:@"<genre>%@</genre>", [genresForSelf objectAtIndex:i]];
        }
    }

    // HOST INFO
    NSArray *genresForHost = [genreForTypeDict objectForKey:@"host"];
    if(genresForHost){
        [s appendString:@"<relatedItem type=\"host\">"];
        
        NSString *hostTitle = nil;
        
        if([pubType isEqualToString:@"inproceedings"] || 
           [pubType isEqualToString:@"article"] || 
           [pubType isEqualToString:@"incollection"]){
            hostTitle = [self valueOfField:@"booktitle"];
        }else if([pubType isEqualToString:@"article"]){
            hostTitle = [self valueOfField:@"Journal"];
        }
        [s appendFormat:@"<titleInfo><title>%@</title></titleInfo>", (hostTitle ? hostTitle : @"unknown")];
        
        [s appendString:@"</relatedItem>"];
    }

    [s appendFormat:@"<identifier type=\"citekey\">%@</identifier>", [self citeKey]];
    
    [s appendString:@"</mods>"];
    return [[s copy] autorelease];
}

- (NSString *)RSSValue{
    NSMutableString *s = [[[NSMutableString alloc] init] autorelease];

    NSString *descField = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKRSSDescriptionFieldKey];

    [s appendString:@"<item>\n"];
    [s appendString:@"<description>\n"];
    if([self valueOfField:descField]){
        [s appendString:[[self valueOfField:descField] xmlString]];
    }
    [s appendString:@"</description>\n"];
    [s appendString:@"<link>"];
    [s appendString:[self valueOfField:@"Url"]];
    [s appendString:@"</link>\n"];
    //[s appendString:@"<bt:source><![CDATA[\n"];
    //    [s appendString:[[self bibTeXString] xmlString]];
    //    [s appendString:@"]]></bt:source>\n"];
    [s appendString:@"</item>\n"];
    return s;
}

- (NSString *)HTMLValueUsingTemplateString:(NSString *)templateString{
    return [templateString stringByParsingTagsWithStartDelimeter:@"<$" endDelimeter:@"/>" usingObject:self];
}

- (NSString *)allFieldsString{
    NSMutableString *result = [[[NSMutableString alloc] init] autorelease];
    NSEnumerator *pubFieldsE = [pubFields objectEnumerator];
    NSString *field = nil;
    
	[result appendString:[self citeKey]];
		
    while(field = [pubFieldsE nextObject]){
        [result appendFormat:@" %@ ", field];
    }
    return result;
}

- (NSString *)localURLPathRelativeTo:(NSString *)base{
    NSURL *local = nil;
    NSString *lurl = [self valueOfField:@"Local-Url"];

    if (!lurl || [lurl isEqualToString:@""]) return nil;

    if(base &&
       ![lurl containsString:@"file://"] &&
       ![[lurl substringWithRange:NSMakeRange(0,1)] isEqualToString:@"/"] &&
       ![[lurl substringWithRange:NSMakeRange(0,1)] isEqualToString:@"~"]){
        lurl = [base stringByAppendingPathComponent:lurl];
    }

    
    if(![@"" isEqualToString:lurl]){
        local = [NSURL URLWithString:lurl];
        return [[local path] stringByExpandingTildeInPath];
    }else{
        local = nil;
        return lurl;
    }

}

- (NSString *)suggestedLocalUrl{
	OFPreferenceWrapper *prefs = [OFPreferenceWrapper sharedPreferenceWrapper];
	NSString *localUrlFormat = [prefs objectForKey:BDSKLocalUrlFormatKey];
	NSString *papersFolderPath = [prefs stringForKey:BDSKPapersFolderPathKey];
	NSString *relativeFile = [self parseFormat:localUrlFormat forField:@"Local-Url"];
	
	return [papersFolderPath stringByAppendingPathComponent:relativeFile];
}

- (BOOL)canSetLocalUrl
{
	NSEnumerator *fEnum = [[[NSApp delegate] requiredFieldsForLocalUrl] objectEnumerator];
	NSString *fieldName;
	NSString *fieldValue = [self valueOfField:@"Local-Url"];
	
	if (fieldValue != nil && ![fieldValue isEqualToString:@""]) {
		return NO;
	}
	while (fieldName = [fEnum nextObject]) {
		fieldValue = [self valueOfField:fieldName];
		if (fieldValue == nil || [fieldValue isEqualToString:@""]) {
			return NO;
		}
	}
	return YES;
}

- (NSString *)parseFormat:(NSString *)format forField:(NSString *)fieldName
{
	BDSKConverter *converter = [BDSKConverter sharedConverter];
	NSMutableString *parsedStr = [NSMutableString string];
	NSScanner *scanner = [NSScanner scannerWithString:format];
	NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
	NSString *string, *numStr;
	int number, numAuth, i;
	unichar specifier, nextChar;
	BibAuthor *auth;
	
	// seed for random letters or characters
	srand(time(NULL));
	
	while (![scanner isAtEnd]) {
		// scan non-specifier parts
		if ([scanner scanUpToString:@"%" intoString:&string]) {
			// if we are not sure about a valid format, we should sanitize string
			[parsedStr appendString:string];
		}
		// does nothing at the end; allows but ignores % at end
		[scanner scanString:@"%" intoString:NULL];
		if (![scanner isAtEnd]) {
			// found %, so now there should be a specifier char
			specifier = [format characterAtIndex:[scanner scanLocation]];
			[scanner setScanLocation:[scanner scanLocation]+1];
			switch (specifier) {
				case 'a':
					// author names, optional #names and #chars
					numAuth = 0;
					number = 0;
					if (![scanner isAtEnd]) {
						// look for #names
						nextChar = [format characterAtIndex:[scanner scanLocation]];
						if ([digits characterIsMember:nextChar]) {
							[scanner setScanLocation:[scanner scanLocation]+1];
							numAuth = (int)(nextChar - '0');
							// scan for #chars per name
							if ([scanner scanCharactersFromSet:digits intoString:&numStr]) {
								number = [numStr intValue];
							}
						}
					}
					if (numAuth == 0 || numAuth > [self numberOfAuthors]) {
						numAuth = [self numberOfAuthors];
					}
					for (i = 0; i < numAuth; i++) {
						string = [[self authorAtIndex:i] lastName];
						string = [converter stringBySanitizingString:string forField:fieldName inFileType:[self fileType]];
						if ([string length] > number && number > 0) {
							string = [string substringToIndex:number];
						}
						[parsedStr appendString:string];
					}
					break;
				case 'A':
					// author names with initials, optional #names and #chars
					numAuth = 0;
					number = 0;
					if (![scanner isAtEnd]) {
						// look for #names
						nextChar = [format characterAtIndex:[scanner scanLocation]];
						if ([digits characterIsMember:nextChar]) {
							[scanner setScanLocation:[scanner scanLocation]+1];
							numAuth = (int)(nextChar - '0');
							// scan for #chars per name
							if ([scanner scanCharactersFromSet:digits intoString:&numStr]) {
								number = [numStr intValue];
							}
						}
					}
					if (numAuth == 0 || numAuth > [self numberOfAuthors]) {
						numAuth = [self numberOfAuthors];
					}
					for (i = 0; i < numAuth; i++) {
						if (i > 0) {
							[parsedStr appendString:@";"];
						}
						auth = [self authorAtIndex:i];
						if ([[auth firstName] length] > 0) {
							string = [NSString stringWithFormat:@"%@.%C", 
											[auth lastName], [[auth firstName] characterAtIndex:0]];
						} else {
							string = [auth lastName];
						}
						string = [converter stringBySanitizingString:string forField:fieldName inFileType:[self fileType]];
						if ([string length] > number && number > 0) {
							string = [string substringToIndex:number];
						}
						[parsedStr appendString:string];
					}
					break;
				case 't':
					// title, optional #chars
					string = [converter stringBySanitizingString:[self title] forField:fieldName inFileType:[self fileType]];
					if ([scanner scanCharactersFromSet:digits intoString:&numStr]) {
						number = [numStr intValue];
					} else {
						number = 0;
					}
					if (number > 0 && [string length] > number) {
						[parsedStr appendString:[string substringToIndex:number]];
					} else {
						[parsedStr appendString:string];
					}
					break;
				case 'y':
					// year without century
					if ([self date]) {
						string = [[self date] descriptionWithCalendarFormat:@"%y"];
						[parsedStr appendString:string];
					}
					break;
				case 'Y':
					// year with century
					if ([self date]) {
						string = [[self date] descriptionWithCalendarFormat:@"%Y"];
						[parsedStr appendString:string];
					}
					break;
				case 'm':
					// month
					if ([self date] && [self valueOfField:@"Month"] != nil && ![[self valueOfField:@"Month"] isEqualToString:@""]) {
						string = [[self date] descriptionWithCalendarFormat:@"%m"];
						[parsedStr appendString:string];
					}
					break;
				case 'k':
					// keywords
					string = [self valueOfField:@"Keywords"];
					if (string != nil) {
						NSMutableArray *arr = [NSMutableArray array];
                                                // split the keyword string using the same methodology as addString:forCompletionEntry:, treating ,:; as possible dividers
                                                NSRange keywordPunctuationRange = [string rangeOfCharacterFromSet:[[NSApp delegate] autoCompletePunctuationCharacterSet]];
                                                if (keywordPunctuationRange.location != NSNotFound) {
                                                    NSScanner *keywordScanner = [[NSScanner alloc] initWithString:string];
                                                    [keywordScanner setCharactersToBeSkipped:nil];
                                                    
                                                    while (![keywordScanner isAtEnd]) {
                                                        if ([keywordScanner scanUpToCharactersFromSet:[[NSApp delegate] autoCompletePunctuationCharacterSet] intoString:&string])
                                                            [arr addObject:string];
                                                        [keywordScanner scanCharactersFromSet:[[NSApp delegate] autoCompletePunctuationCharacterSet] intoString:nil];
                                                        [keywordScanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
                                                    }
                                                    [keywordScanner release];
                                                } else {
                                                    [arr addObject:string];
                                                }
                                                                        
						if ([scanner scanCharactersFromSet:digits intoString:&numStr]) {
							number = [numStr intValue];
						} else {
							number = 0;
						}
						for (i = 0; i < [arr count] && (number == 0 || i < number); i++) { 
							string = [[arr objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]; 
							string = [converter stringBySanitizingString:string forField:fieldName inFileType:[self fileType]]; 
							[parsedStr appendString:string]; 
						}
					}
					break;
				case '{':
					// arbitrary field
					[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"}"] intoString:&string];
					[scanner scanString:@"}" intoString:NULL];
					if ([scanner scanCharactersFromSet:digits intoString:&numStr]) {
						number = [numStr intValue];
					} else {
						number = 0;
					}
					string = [self valueOfField:string];
					if (string != nil) {
						string = [converter stringBySanitizingString:string forField:fieldName inFileType:[self fileType]];
						if (number > 0 && [string length] > number) {
							[parsedStr appendString:[string substringToIndex:number]];
						} else {
							[parsedStr appendString:string];
						}
					}
					break;
				case 'r':
					// random lowercase letters
					if ([scanner scanCharactersFromSet:digits intoString:&numStr]) {
						number = [numStr intValue];
					} else {
						number = 1;
					}
					while (number-- > 0) {
						[parsedStr appendFormat:@"%c",'a' + (char)(rand() % 26)];
					}
					break;
				case 'R':
					// random uppercase letters
					if ([scanner scanCharactersFromSet:digits intoString:&numStr]) {
						number = [numStr intValue];
					} else {
						number = 1;
					}
					while (number-- > 0) {
						[parsedStr appendFormat:@"%c",'A' + (char)(rand() % 26)];
					}
					break;
				case 'd':
					// random digits
					if ([scanner scanCharactersFromSet:digits intoString:&numStr]) {
						number = [numStr intValue];
					} else {
						number = 1;
					}
					while (number-- > 0) {
						[parsedStr appendFormat:@"%i",(int)(rand() % 10)];
					}
					break;
				case '0':
				case '1':
				case '2':
				case '3':
				case '4':
				case '5':
				case '6':
				case '7':
				case '8':
				case '9':
				case '%':
					// escaped digit or %
					[parsedStr appendFormat:@"%C", specifier];
					break;
				// the rest is only vallid at the end of the format
				case 'u':
					// unique lowercase letters
					if ([scanner scanCharactersFromSet:digits intoString:&numStr]) {
						number = [numStr intValue];
					} else {
						number = 1;
					}
					if ([scanner scanUpToString:@"%" intoString:&string]) {
						string = [converter stringBySanitizingString:string forField:fieldName inFileType:[self fileType]];
					}
					else {
						string = @"";
					}
					if ([scanner isAtEnd]) {
						[parsedStr setString:[self uniqueString:parsedStr 
														 suffix:string
													   forField:fieldName
												  numberOfChars:number 
														   from:'a' to:'z' 
														  force:(number == 0)]];
					}
					else {
						NSLog(@"Specifier %%u can only be used at the end of format.");
					}
					break;
				case 'U':
					// unique uppercase letters
					if ([scanner scanCharactersFromSet:digits intoString:&numStr]) {
						number = [numStr intValue];
					} else {
						number = 1;
					}
					if ([scanner scanUpToString:@"%" intoString:&string]) {
						string = [converter stringBySanitizingString:string forField:fieldName inFileType:[self fileType]];
					}
					else {
						string = @"";
					}
					if ([scanner isAtEnd]) {
						[parsedStr setString:[self uniqueString:parsedStr 
														 suffix:string
													   forField:fieldName
												  numberOfChars:number 
														   from:'A' to:'Z' 
														  force:(number == 0)]];
					}
					else {
						NSLog(@"Specifier %%U can only be used at the end of the format.");
					}
					break;
				case 'n':
					// unique number
					if ([scanner scanCharactersFromSet:digits intoString:&numStr]) {
						number = [numStr intValue];
					} else {
						number = 1;
					}
					if ([scanner scanUpToString:@"%" intoString:&string]) {
						string = [converter stringBySanitizingString:string forField:fieldName inFileType:[self fileType]];
					}
					else {
						string = @"";
					}
					if ([scanner isAtEnd]) {
						[parsedStr setString:[self uniqueString:parsedStr 
														 suffix:string
													   forField:fieldName
												  numberOfChars:number 
														   from:'0' to:'1' 
														  force:(number == 0)]];
					}
					else {
						NSLog(@"Specifier %%%C can only be used at the end of format.", specifier);
					}
					break;
                                case 'c':
                                    // This handles acronym specifiers of the form %c{FieldName}
                                    NSAssert( [scanner scanString:@"{" intoString:nil], @"Failed to scan {." ); // these errors will be handled gracefully by the BDSKConverter
                                    [scanner scanUpToString:@"}" intoString:&string]; // it isn't really an error if there's no content
                                    NSAssert( [scanner scanString:@"}" intoString:nil], @"Failed to scan }." );
                                    
                                    string = [self acronymValueOfField:string];
                                    string = [converter stringBySanitizingString:string forField:fieldName inFileType:[self fileType]];
                                    [parsedStr appendString:string];
                                    break;
				default: 
					NSLog(@"Unknown format specifier %%%C in format.", specifier);
			}
		}
	}
	
	if(parsedStr == nil || [parsedStr isEqualToString:@""]) {
		number = 0;
		do {
			string = [@"empty" stringByAppendingFormat:@"%i", number++];
		} while (![self stringIsValid:string forField:fieldName]);
		return string;
	} else {
	   return parsedStr;
	}
}

// returns a 'valid' string rather than a 'unique' one
- (NSString *)uniqueString:(NSString *)baseStr 
					suffix:(NSString *)suffix
				  forField:(NSString *)fieldName
			 numberOfChars:(unsigned int)number 
					  from:(unichar)fromChar 
						to:(unichar)toChar 
					 force:(BOOL)force {
	
	NSString *uniqueStr;
	char c;
	
	if (number > 0) {
		for (c = fromChar; c <= toChar; c++) {
			// try with the first added char set to c
			uniqueStr = [baseStr stringByAppendingFormat:@"%C", c];
			uniqueStr = [self uniqueString:uniqueStr suffix:suffix forField:fieldName numberOfChars:number - 1 from:fromChar to:toChar force:NO];
			if ([self stringIsValid:uniqueStr forField:fieldName])
				return uniqueStr;
		}
	}
	else {
		uniqueStr = [baseStr stringByAppendingString:suffix];
	}
	
	if (force && ![self stringIsValid:uniqueStr forField:fieldName]) {
		// not uniqueString yet, so try with 1 more char
		return [self uniqueString:baseStr suffix:suffix forField:fieldName numberOfChars:number + 1 from:fromChar to:toChar force:YES];
	}
	
	return uniqueStr;
}

// this might be changed when more fields are available
// do we want to add character checks as in CiteKeyFormatter?
- (BOOL)stringIsValid:(NSString *)proposedStr forField:(NSString *)fieldName
{
	if ([fieldName isEqualToString:@"Cite Key"]) {
		    return !(proposedStr == nil || [proposedStr isEqualToString:@""] ||
					 [[self document] citeKeyIsUsed:proposedStr byItemOtherThan:self]);
	}
	else if ([fieldName isEqualToString:@"Local-Url"]) {
			if (proposedStr == nil || [proposedStr isEqualToString:@""])
				return NO;
			if ([[NSFileManager defaultManager] fileExistsAtPath:proposedStr])
				return NO;
			return YES;
			
	}
	else {
		[NSException raise:@"unimpl. feat. exc." format:@"stringIsValid:forField: is partly implemented"];
		return YES;
	}
}

@end
