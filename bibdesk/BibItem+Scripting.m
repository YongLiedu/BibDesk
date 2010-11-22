//
//  BibItemClassDescription.m
//  BibDesk
//
//  Created by Sven-S. Porst on Sat Jul 10 2004.
/*
 This software is Copyright (c) 2004-2010
 Sven-S. Porst. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Sven-S. Porst nor the names of any
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
#import "BibItem+Scripting.h"
#import "BibAuthor.h"
#import "BDSKStringConstants.h"
#import "BibDocument.h"
#import "BDSKGroupsArray.h"
#import "BDSKBibTeXParser.h"
#import "BDSKPublicationsArray.h"
#import "BDSKLinkedFile.h"
#import "NSURL_BDSKExtensions.h"
#import "BDSKTemplate.h"
#import "BDSKTemplateObjectProxy.h"

/* ssp
A Category on BibItem with a few additional methods to enable and enhance its scriptability beyond what comes for free with key value coding.
*/
@implementation BibItem (Scripting)

+ (BOOL)accessInstanceVariablesDirectly {
	return NO;
}

/* 
 ssp 2004-07-10
 Returns a path to the BibItem for Apple Script
 Needs a properly working -document method to work with multpiple documents.
*/
- (NSScriptObjectSpecifier *) objectSpecifier {
    // only items belonging to an owner are scriptable
    if ([self owner]) {
        NSScriptObjectSpecifier *containerRef = [(id)[self owner] objectSpecifier];
        return [[[NSUniqueIDSpecifier allocWithZone:[self zone]] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"scriptingPublications" uniqueID:[self uniqueID]] autorelease];
    } else {
        return nil;
    }
}


/* cmh:
 Access to arbitrary fields through 'proxy' objects BDSKField. 
 These are simply wrappers for the accessors in BibItem. 
*/
- (BDSKField *)valueInBibFieldsWithName:(NSString *)name
{
	return [[[BDSKField alloc] initWithName:[name fieldName] bibItem:self] autorelease];
}

- (NSArray *)bibFields
{
	BDSKField *field = nil;
	NSMutableArray *bibFields = [NSMutableArray arrayWithCapacity:5];
	
	for (NSString *name in pubFields) {
		field = [[BDSKField alloc] initWithName:[name fieldName] bibItem:self];
		[bibFields addObject:field];
		[field release];
	}
	return bibFields;
}

- (NSArray *)scriptingAuthors {
	return [self pubAuthors];
}

- (BibAuthor *)valueInScriptingAuthorsWithName:(NSString *)name {
    // create a new author so we can use BibAuthor's isEqual: method for comparison
    // instead of trying to do string comparisons
    BibAuthor *newAuth = [BibAuthor authorWithName:name publication:nil];
	
    for (BibAuthor *auth in [self pubAuthors]) {
		if ([auth isEqual:newAuth])
			return auth;
	}
	return nil;
}

- (NSArray *)scriptingEditors {
	return [self pubEditors];
}

- (BibAuthor *)valueInScriptingEditorsWithName:(NSString *)name {
    // create a new author so we can use BibAuthor's isEqual: method for comparison
    // instead of trying to do string comparisons
    BibAuthor *newAuth = [BibAuthor authorWithName:name publication:nil];
	
    for (BibAuthor *auth in [self pubEditors]) {
		if ([auth isEqual:newAuth])
			return auth;
	}
	return nil;
}

- (NSArray *)linkedFiles {
    return [[self localFiles] valueForKey:@"URL"];
}

- (void)insertObject:(NSURL *)newURL inLinkedFilesAtIndex:(NSUInteger)idx {
    if ([[self owner] isDocument]) {
        BDSKLinkedFile *file = [BDSKLinkedFile linkedFileWithURL:newURL delegate:self];
        if (file) {
            NSArray *localFiles = [self localFiles];
            if (idx > 0) {
                idx = [files indexOfObject:[localFiles objectAtIndex:idx - 1]];
                if (idx == NSNotFound)
                    idx = 0;
                else
                    idx++;
            }
            [self insertObject:file inFilesAtIndex:idx];
        }
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (void)removeObjectFromLinkedFilesAtIndex:(NSUInteger)idx {
    [[self mutableArrayValueForKey:@"files"] removeObject:[[self localFiles] objectAtIndex:idx]];
}

- (NSArray *)linkedURLs {
    return [[self remoteURLs] valueForKeyPath:@"URL.absoluteString"];
}

- (void)insertObject:(NSString *)newURLString inLinkedURLsAtIndex:(NSUInteger)idx {
    if ([[self owner] isDocument]) {
        NSURL *newURL = [NSURL URLWithStringByNormalizingPercentEscapes:newURLString];
        BDSKLinkedFile *file = [BDSKLinkedFile linkedFileWithURL:newURL delegate:self];
        if (file) {
            NSArray *remoteURLs = [self remoteURLs];
            if (idx < [remoteURLs count]) {
                idx = [files indexOfObject:[remoteURLs objectAtIndex:idx]];
                if (idx == NSNotFound)
                    idx = [self countOfFiles];
            } else {
                idx = [self countOfFiles];
            }
            [self insertObject:file inFilesAtIndex:idx];
        }
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (void)removeObjectFromLinkedURLsAtIndex:(NSUInteger)idx {
    [[self mutableArrayValueForKey:@"files"] removeObject:[[self remoteURLs] objectAtIndex:idx]];
}

- (id)uniqueID {
    return [[self identifierURL] absoluteString];
}

- (id)scriptingDocument {
    return [owner isDocument] ? (id)owner : [owner respondsToSelector:@selector(document)] ? (id)[(id)owner document] : nil;
}

- (id)group {
    return [owner isDocument] ? (BDSKGroup *)[[(BibDocument *)owner groups] libraryGroup] : (BDSKGroup *)owner;
}

- (BOOL)isExternal {
    return [[self owner] isDocument] == NO;
}

- (NSString *)scriptingType {
	return [self pubType];
}

- (void)setScriptingType:(NSString *)newType {
    if ([[self owner] isDocument]) {
        [self setPubType:(NSString *)newType];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString *)scriptingCiteKey {
	return [self citeKey];
}

- (void)setScriptingCiteKey:(NSString *)newKey {
    if ([[self owner] isDocument]) {
        [self setCiteKey:(NSString *)newKey];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString*)scriptingTitle {
	return [self valueOfField:BDSKTitleString];
}

- (void)setScriptingTitle:(NSString*)newTitle {
    if ([[self owner] isDocument]) {
        [self setField:BDSKTitleString toValue:newTitle];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString *) month {
	NSString *month = [self valueOfField:BDSKMonthString];
	return month ?: @"";
}

- (void) setMonth:(NSString*) newMonth {
    if ([[self owner] isDocument]) {
        [self setField:BDSKMonthString toValue:newMonth];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString *) year {
	NSString *year = [self valueOfField:BDSKYearString];
	return year ?: @"";
}

- (void) setYear:(NSString*) newYear {
    if ([[self owner] isDocument]) {
        [self setField:BDSKYearString toValue:newYear];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSDate*)scriptingDate {
	NSDate * d = [self date];
	
	if (!d) return [NSDate dateWithTimeIntervalSince1970:0];
	else return d;
}

- (NSDate*)scriptingDateAdded {
	NSDate * d = [self dateAdded];
	
	if (!d) return [NSDate dateWithTimeIntervalSince1970:0];
	else return d;
}

- (NSDate*)scriptingDateModified {
	NSDate * d = [self dateModified];
	
	if (!d) return [NSDate dateWithTimeIntervalSince1970:0];
	else return d;
}


- (NSColor *)scriptingColor {
	return [self color];
}

- (void)setScriptingColor:(NSColor *)newColor {
    if ([[self owner] isDocument]) {
        if ([newColor isEqual:[NSNull null]])
            newColor = nil;
        [self setColor:newColor];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

/*
 ssp: 2004-07-11
 Extra key-value-style accessor methods for the local and distant URLs, abstract and notes
 These might be particularly useful for scripting, so having them right in the scripting dictionary rather than hidden in the 'fields' record should be useful.
 I assume the same could be achieved more easily using -valueForUndefinedKey:, but that's X.3 and up 
 I am using generic NSStrings here. NSURLs and NSFileHandles might be nicer but as things are handled as strings both in the BibDesk backend and in AppleScript there wouldn't be much point to it.
 Any policies on whether to rather return copies of the strings in question here?
*/
- (NSString*) remoteURLString {
    NSArray *linkedURLs = [self linkedURLs];
    return [linkedURLs count] ? [linkedURLs objectAtIndex:0] : @"";
}

- (void) setRemoteURLString:(NSString*) newURLString{
    if ([[self owner] isDocument]) {
        BDSKLinkedFile *file = [BDSKLinkedFile linkedFileWithURLString:newURLString];
        if (file == nil)
            return;
        NSArray *remoteURLs = [self remoteURLs];
        NSUInteger idx = [self countOfFiles];
        if ([remoteURLs count]) {
            idx = [files indexOfObject:[remoteURLs objectAtIndex:0]];
            if (idx == NSNotFound)
                idx = [self countOfFiles];
            else
                [self removeObjectFromFilesAtIndex:idx];
        }
        [self insertObject:file inFilesAtIndex:idx];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString*) localURLString {
    NSArray *linkedFiles = [self linkedFiles];
    return [linkedFiles count] ? [[linkedFiles objectAtIndex:0] path] : @"";
}

- (void) setLocalURLString:(NSString*) newPath {
    if ([[self owner] isDocument]) {
        NSURL *newURL = [newPath hasPrefix:@"file://"] ? [NSURL URLWithString:newPath] : [NSURL fileURLWithPath:[newPath stringByExpandingTildeInPath]];
        if (newURL == nil)
            return;
        BDSKLinkedFile *file = [BDSKLinkedFile linkedFileWithURL:newURL delegate:self];
        if (file == nil)
            return;
        NSArray *localFiles = [self localFiles];
        NSUInteger idx = 0;
        if ([localFiles count]) {
            idx = [files indexOfObject:[localFiles objectAtIndex:0]];
            if (idx == NSNotFound)
                idx = 0;
            else
                [self removeObjectFromFilesAtIndex:idx];
        }
        [self insertObject:file inFilesAtIndex:idx];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString*) abstract {
	return [self valueOfField:BDSKAbstractString inherit:NO];
}

- (void) setAbstract:(NSString*) newAbstract {
    if ([[self owner] isDocument]) {
        [self setField:BDSKAbstractString toValue:newAbstract];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString*) annotation {
	return [self valueOfField:BDSKAnnoteString inherit:NO];
}

- (void) setAnnotation:(NSString*) newAnnotation {
    if ([[self owner] isDocument]) {
        [self setField:BDSKAnnoteString toValue:newAnnotation];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString*)rssDescription {
	return [self valueOfField:BDSKRssDescriptionString];
}

- (void) setRssDescription:(NSString*) newDesc {
    if ([[self owner] isDocument]) {
        [self setField:BDSKRssDescriptionString toValue:newDesc];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSString*)rssString {
	NSString *value = [self RSSValue];
	return value ?: @"";
}

- (NSString*)risString {
	NSString *value = [self RISStringValue];
	return value ?: @"";
}

- (NSTextStorage *)styledTextValue {
    NSString *templateStyle = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKBottomPreviewDisplayTemplateKey];
    BDSKTemplate *template = [BDSKTemplate templateForStyle:templateStyle] ?: [BDSKTemplate templateForStyle:[BDSKTemplate defaultStyleNameForFileType:@"rtf"]];
    
    NSAttributedString *attrString = nil;
    if ([template templateFormat] & BDSKRichTextTemplateFormat) {
        attrString = [BDSKTemplateObjectProxy attributedStringByParsingTemplate:template withObject:[self owner] publications:[NSArray arrayWithObject:self] documentAttributes:NULL];
    } else if ([template templateFormat] & BDSKPlainTextTemplateFormat) {
        NSString *str = [BDSKTemplateObjectProxy stringByParsingTemplate:template withObject:[self owner] publications:[NSArray arrayWithObject:self]];
        // we generally assume UTF-8 encoding for all template-related files
        if ([template templateFormat] == BDSKPlainHTMLTemplateFormat)
            attrString = [[[NSAttributedString alloc] initWithHTML:[str dataUsingEncoding:NSUTF8StringEncoding] documentAttributes:NULL] autorelease];
        else
            attrString = [[[NSAttributedString alloc] initWithString:str attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:0.0], NSFontAttributeName, nil]] autorelease];
    } else {
        attrString = [[[NSAttributedString alloc] initWithString:@""] autorelease];
    }
	return [[[NSTextStorage alloc] initWithAttributedString:attrString] autorelease];
}

- (NSString *)keywords{
    NSString *keywords = [self valueOfField:BDSKKeywordsString];
	return keywords ?: @"";
}

- (void)setKeywords:(NSString *)keywords{
    if ([[self owner] isDocument]) {
        [self setField:BDSKKeywordsString toValue:keywords];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

- (NSInteger)scriptingRating{
    return [self rating];
}

- (void)setScriptingRating:(NSInteger)rating{
    if ([[self owner] isDocument]) {
        [self setRating:rating];
        [[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
    } else {
        NSScriptCommand *cmd = [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
    }
}

/*
 ssp: 2004-07-11
 Make the bibTeXString settable.
 The only way I could figure out how to initialise a new record with a BibTeX string.
 This may be a bit of a hack for a few reasons: (a) there seems to be no good way to initialise a BibItem from a BibString when it already exists and (b) I suspect this isn't the way you're supposed to do AS.
*/
- (void) setBibTeXString:(NSString*) btString {

	// we do not allow setting the bibtex string after an edit, only at initialization
    if ([self owner] && [[self owner] isDocument] == NO) {
        NSScriptCommand *cmd= [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set property of external publication.",@"Error description")];
        return;
	} else if([self hasBeenEdited]){
        NSScriptCommand *cmd= [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [cmd setScriptErrorString:NSLocalizedString(@"Cannot set BibTeX string after initialization.",@"Error description")];
		return;
	}
    
    NSError *error = nil;
    BOOL isPartialData;
    NSArray *newPubs = [BDSKBibTeXParser itemsFromString:btString owner:[self owner] isPartialData:&isPartialData error:&error];
	
	// try to do some error handling for AppleScript
	if (isPartialData) {
        NSScriptCommand *cmd= [NSScriptCommand currentCommand];
        [cmd setScriptErrorNumber:NSInternalScriptError];
        [cmd setScriptErrorString:[NSString stringWithFormat:NSLocalizedString(@"BibDesk failed to process the BibTeX entry %@ with error %@. It may be malformed.",@"Error description"), btString, [error localizedDescription]]];
		return;
	}
		
	// otherwise use the information of the first publication found in the string.
	BibItem * newPub = [newPubs objectAtIndex:0];
	
	// a parsed pub has no creation date set, so we need to copy first
	NSString *createdDate = [self valueOfField:BDSKDateAddedString inherit:NO];
	if (![NSString isEmptyString:createdDate])
		[newPub setField:BDSKDateAddedString toValue:createdDate];
	
	// ... and replace the current record with it.
	// hopefully, I don't understand the whole filetypes/pubtypes stuff	
	[self setPubType:[newPub pubType]];
	[self setCiteKey:[newPub citeKey]];
	[self setFields:[newPub pubFields]];
	
	[[self undoManager] setActionName:NSLocalizedString(@"AppleScript",@"Undo action name for AppleScript")];
	// NSLog([newPub description]);
}

/*
 ssp: 2004-07-10
 Return attribute keys corresponding to the fields present in the current BibItem
 DOESNT SEEM TO WORK

- (NSArray *)attributeKeys {
	NSLog(@"BibItem attributeKeys");
	NSMutableArray * ar = [NSMutableArray arrayWithObjects:BibItemBasicObjects, nil];
	NSDictionary * f = [self fields];
	NSEnumerator * keyEnum = [f keyEnumerator];
	NSString * key;
	NSString * value;
	
	while (key = [keyEnum nextObject]) {
		value = [f objectForKey:key];
		if (![value isEqualTo:@""]) {
			[ar addObject:key];
		}
	}
	return ar;
}
*/

/*
 ssp: 2004-07-10
 This catches all the keys that aren't implemented, i.e. those we advertise in -attributeKeys but which actually come from the fields record.
 Not sure about the exception stuff. 
 Apparently this is X.3 and up only.

- (id)valueForUndefinedKey:(NSString *)key {
	NSString * s = (NSString*) [self valueOfField:key];
	if (!s) {
		[NSException raise:NSUndefinedKeyException format:@""];
	}		
	return s;
}
*/

@end
