//
//  BibDocument+Scripting.m
//  Bibdesk
//
//  Created by Sven-S. Porst on Thu Jul 08 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "BibDocument+Scripting.h"


/* ssp
Category on BibDocument to implement a few additional functions needed for scripting
*/
@implementation BibDocument (Scripting)


/* ssp: 2004-04-03
Sets the filter field to a specified string.
Have to make it firstResponder first as otherwise it doesn't update (show clear cell) corectly.
*/
- (void)setSearchField:(NSString*) mySearchString {
    NSResponder * oldFirstResponder = [documentWindow firstResponder];
    [documentWindow makeFirstResponder:searchField];
    
    [searchField setObjectValue:mySearchString];
    [self searchFieldAction:searchField];
    
    [documentWindow makeFirstResponder:oldFirstResponder];
}



/* ssp: 2004-07-11
Getting and setting the selection of the table
*/

- (NSArray*) selection {
	// enumerator of row numbers	
	NSEnumerator * myEnum = [self selectedPubEnumerator];
	NSMutableArray * myPubs = [NSMutableArray arrayWithCapacity:10];
	
	NSNumber * row;
	BibItem * aPub;
	
	while (row = [myEnum nextObject]) {
		aPub = [shownPublications objectAtIndex:[row intValue]];
		[myPubs addObject:aPub];
	}
	
	return myPubs;
}


- (void) setSelection: (NSArray*) newSelection {
	//NSLog(@"setSelection:");
	NSEnumerator * myEnum = [newSelection objectEnumerator];
	// debugging revealed that we get an array of NSIndexspecifiers and not of BibItem
	NSIndexSpecifier * aPub;
	
	// do the first one manually to deselect previous selection
	aPub = [myEnum nextObject]; 
	if (!aPub) return;
	[self highlightBib:[shownPublications objectAtIndex:[aPub index]]];
	
	while (aPub = [myEnum nextObject]){
		[self highlightBib:[shownPublications objectAtIndex:[aPub index]] byExtendingSelection:YES];
	}	
}



- (NSTextStorage*) textStorageForBibString:(NSString*) bibString {
	[PDFpreviewer PDFFromString:bibString];
    NSData * d = [PDFpreviewer rtfDataPreview];
	NSDictionary * myDict;
	
	return [[[NSTextStorage alloc] initWithRTF:d documentAttributes:&myDict] autorelease];
}

@end



/* 
ssp: 2004-07-11
 NSScriptCommand for the "bibliography for" command.
 This is sent to the BibDocument.
*/


@implementation BibDeskBibliographyCommand

/*
 ssp: 2004-07-11
 Takes an array of items as given by AppleScript in the formt of NSIndexSpecifiers, runs the items through BibTeX and RTF conversion and returns an attributed string.
 BDSKPreviewer being able to return NSAttributedStrings instead of NSData for RTF might save a few conversions. For the time being I implemented a little function in BibDocument+Scripting. This could be merged into Bibdocument.
 As the BibItem's 'text' attribute, somehow the styling is lost somewhere in the process. Hints?!
 */

- (id) performDefaultImplementation {
    id param = [self directParameter];
	
	//	This should be an NSArray of NSIndexSpecifiers. Perhaps do some error checking
	if (![param isKindOfClass:[NSArray class]]) return nil;
	
	// Determine the document responsible for this
	NSIndexSpecifier * index = [param objectAtIndex:0];
	NSScriptObjectSpecifier * parent = [index containerSpecifier];
	BibDocument * myBib = [parent objectsByEvaluatingSpecifier];
	NSLog([myBib description]);
	if (!myBib) return nil;
	
	// run through the array
	NSEnumerator *e = [(NSArray*)param objectEnumerator];
	NSArray * thePubs = [myBib publications];
    NSIndexSpecifier *i;
	int  n ;
	NSMutableString *bibString = [NSMutableString string];
	
	while (i = [e nextObject]) {
		n = [i index];
		[bibString appendString:[[thePubs objectAtIndex:n] bibTeXString]];
	}
	
	// make RTF and return it.
	NSTextStorage * ts = [myBib textStorageForBibString:bibString];
	
	return ts;
}


@end



/*
 ssp: 2004-04-03
 NSScriptCommand for the "find" command.
*/

@implementation BibDeskFilterScriptCommand

/*
 ssp: 2004-04-03
 Currently this goes through all documents and sets the filterField there.
 Ideally this could be done on a per-document basis is the command is sent to a single document and to all documents if it is sent to the application. But I can't figure out how to tell which object the command was sent to. [self evaluatedReceivers] gives null.
*/

- (id)performDefaultImplementation {
    id param = [self directParameter];
    NSString *input = nil;
    if([param isKindOfClass:[NSString class]]) {
        input = param;
    } else if([param respondsToSelector:@selector(stringValue)]) {
        input = [param stringValue];
    } else {
        return nil;
	}
		

	/*
	// THIS DOESN'T WORK - Just do the same in every situation for the time being
	// Whom are we sent to?
	 
		// Application -> apply to every document
		// Document -> Just apply to that document
	id receivers = [self evaluatedReceivers];
	NSLog([receivers description]);
	NSLog([[self receiversSpecifier] description]);
		  NSLog([self description]);
		  NSLog([[NSScriptCommand currentCommand] description]);
	*/
    if([input length] > 0) {
        NSDocumentController * dc = [NSDocumentController sharedDocumentController];
        NSArray * docs = [dc documents];
        if ([docs count]) {
            NSEnumerator * myEnum = [docs objectEnumerator];
            id theDoc = nil;
            while (theDoc = [myEnum nextObject]) {
                if (theDoc) { 
                    [theDoc setSearchField:input];
                }
            }
        }
    }
    return nil;
}
@end
