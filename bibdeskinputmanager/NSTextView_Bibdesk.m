//
//  NSTextView_Bibdesk.m
//  BibDeskInputManager
//
//  Created by Sven-S. Porst on Sat Jul 17 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "NSTextView_Bibdesk.h"
#import <Foundation/Foundation.h>
#import </usr/include/objc/objc-class.h>
#import </usr/include/objc/Protocol.h>

static BOOL debug = NO;

NSString *BDSKInputManagerID = @"net.sourceforge.bibdesk.inputmanager";

static NSString *kScriptName = @"Bibdesk";
static NSString *kScriptType = @"scpt";
static NSString *kHandlerName = @"getcitekeys";

extern void _objc_resolve_categories_for_class(struct objc_class *cls);

@implementation NSTextView_Bibdesk

+ (void)load{
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [[self superclass] load];
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier]; // for the app we are loading into
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSArray *array = [NSArray arrayWithContentsOfFile:[libraryPath stringByAppendingPathComponent:@"/Application Support/BibDeskInputManager/EnabledApplications.plist"]];

    if(debug) NSLog(@"We should enable for %@", [array description]);
  
    NSEnumerator *e = [array objectEnumerator];
    NSDictionary *dict;
    BOOL yn = NO;
    
    while(dict = [e nextObject]){
	if([[dict objectForKey:@"BundleID"] isEqualToString:bundleID]){
	    if(debug) NSLog(@"Found a match; enabling autocompletion for %@",[dict description]);
	    yn = YES;
	    break;
	}
    }

    if(yn && [[self superclass] instancesRespondToSelector:@selector(completionsForPartialWordRange:indexOfSelectedItem:)]){
	if(debug) NSLog(@"%@ performing posing for %@", [self class], [self superclass]);
	[self poseAsClass:[NSTextView class]];
	if(debug) [self printSelectorList:[self superclass]];
    }
    
    [pool release];
}

+ (void)printSelectorList:(id)anObject{
    int k = 0;
    void *iterator = 0;
    struct objc_method_list *mlist;
        
    _objc_resolve_categories_for_class([anObject class]);
        
    while( mlist = class_nextMethodList( [anObject class], &iterator ) ){
	for(k=0; k<mlist->method_count; k++){
	     NSLog(@"%@ implements %s",[anObject class], mlist->method_list[k].method_name);
	    if( strcmp( sel_getName(mlist->method_list[k].method_name), "complete:") == 0 ){
		NSLog(@"found a complete: selector with imp (0x%08x)", (int)(mlist->method_list[k].method_imp) );
	    }
	}
    }
}

/* ssp: 2004-07-18
1. Determines whether we are in a cite key context, returns (NSNotFound,0) range otherwise
This will determine any cite command beginning with \cite as well as \fullcite and \bibentry.
Are any others needed?
2. Determines cite key to be completed and returns its range
The cite key will be the text (no spaces) between the insertion point and the next { or , preceding it.
	
The heuristics we use here aren't particularly good. Neither the idea nor the implementation. Basically we simply see whether there was a \cite command recently (within 100 characters) and assume it's ours then. Determining whether we _really_ are in the right context for this seems quite hard as \cite commands can have space, newlines, optional parameters wiht about everything in them.
However, we will simply add the usual completions after our own for safety...
*/
- (NSRange) citeKeyRange {
    NSString * s = [[self textStorage] string];
    int sLen = [s length];
    NSRange r = [self selectedRange];
    int locDiff = 100 - r.location;
    if (locDiff < 0 ) { locDiff = 0; }
    int r2Loc = r.location - 100 + locDiff;
    int r2Len = 100 - locDiff;
    NSRange r2 = NSMakeRange(r2Loc, r2Len);
    
    NSRange backslash = [s rangeOfString:@"\\" options:NSBackwardsSearch range:r2];
    if (backslash.location != NSNotFound) {
	// we've got a backslash
	NSRange cite;
	if (backslash.location + 5 <= sLen) {
	    // string is long enough to avoid range exception
	    cite = [s rangeOfString:@"\\cite" options:NSAnchoredSearch range:NSMakeRange(backslash.location,5)];
	    if ((cite.location == NSNotFound) && (backslash.location + 9 <= sLen)) {
		// make sure there is even more space for matching the longer strings
		cite = [s rangeOfString:@"\\fullcite" options:NSAnchoredSearch range:NSMakeRange(backslash.location,9)];
		if (cite.location == NSNotFound) {
		    // last chance...
		    cite = [s rangeOfString:@"\\bibentry" options:NSAnchoredSearch range:NSMakeRange(backslash.location,9)];
		}
	    }
	    
	    if (cite.location != NSNotFound) {
		// we've found some cite command
		NSRange comma = [s rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@", \n{"] options:NSBackwardsSearch range:r2];
		if (comma.location !=NSNotFound) {
		    // We're pretty sure now we've got the correct partial citekey
		    return NSMakeRange(comma.location+1,r.location-comma.location-1);
		} // comma found
	    } // cite command found
	} // string long enough
    } // backslash found
    return NSMakeRange(NSNotFound,0);
}

// ** check to see if it's TeX
// look back to see if { ; if no brace, return not TeX

// if { found, look back between insertion point and { to find comma; check to see if it's BibTeX, then return the match range

// ** check to see if it's BibTeX
// look back to see if ] ; if no options, then just find the citecommand (or not) by searching back from {
// look back to see if ][ ; if so, set ] range again
// look back to find [ starting from ]
// now we have [, see if there is a cite immediately preceding it (rangeOfString:@"cite" || rangeOfString:@"bibentry"

// now we've search back to a brace, and then checked for a cite command with two optional parameters

- (BOOL)isBibTeXCitation:(NSRange)braceRange{
    NSString *str = [[self textStorage] string];

    NSRange rightBracketRange = [str rangeOfString:@"]" options:NSBackwardsSearch | NSLiteralSearch range:NSMakeRange(braceRange.location - 1, 1)];
    
    unsigned minLoc = ( (braceRange.location > 10) ? 10 : braceRange.location);
	NSRange citeSearchRange = NSMakeRange(braceRange.location - minLoc, minLoc); 
    
    if(rightBracketRange.location == NSNotFound){
        if([str rangeOfString:@"cite" options:NSBackwardsSearch | NSLiteralSearch range:citeSearchRange].location != NSNotFound){
            return YES;
        } else {
            return NO;
        }
    }
    
    NSRange leftBracketRange = [str rangeOfString:@"[" options:NSBackwardsSearch | NSLiteralSearch]; // first occurrence of it, looking backwards
    NSRange doubleBracketRange = [str rangeOfString:@"][" options:NSBackwardsSearch | NSLiteralSearch range:NSMakeRange(leftBracketRange.location - 2, 3)]; // look back from [ to see if we have ][; allow some slop
#warning range checks needed    
    if(doubleBracketRange.location != NSNotFound)
        leftBracketRange = [str rangeOfString:@"[" options:NSBackwardsSearch | NSLiteralSearch range:NSMakeRange(doubleBracketRange.location - 50, 50)];
    
    if(leftBracketRange.location != NSNotFound){
        minLoc = ( (leftBracketRange.location > 10) ? 10 : leftBracketRange.location);
		citeSearchRange = NSMakeRange(leftBracketRange.location - minLoc, minLoc);
        if([str rangeOfString:@"cite" options:NSBackwardsSearch | NSLiteralSearch range:citeSearchRange].location != NSNotFound){
            return YES;
        } else {
            return NO;
        }
    }
    NSLog(@"why am I here?");
    return NO;
}
            
- (NSRange)newCiteKeyRange{
    NSString *str = [[self textStorage] string];
    NSRange r = [self selectedRange]; // here's the insertion point
    NSRange commaRange;

    unsigned minLoc = ( (r.location > 100) ? 100 : r.location);
    NSRange braceRange = [str rangeOfString:@"{" options:NSBackwardsSearch | NSLiteralSearch range:NSMakeRange(r.location - minLoc, minLoc)];

    if(braceRange.location != NSNotFound) // may be TeX
        commaRange = [str rangeOfString:@"," options:NSBackwardsSearch | NSLiteralSearch range:NSUnionRange(braceRange, r)];

    if([self isBibTeXCitation:braceRange]){
#warning range checks needed
        return ( (commaRange.location != NSNotFound) ? NSMakeRange(commaRange.location + 1, r.location - commaRange.location - 1) : NSMakeRange(braceRange.location + 1, r.location - braceRange.location - 1)  );
    } else {
        return NSMakeRange(NSNotFound, 0);
    }
}
                
- (NSRange)refLabelRange{
    NSString *s = [[self textStorage] string];
    NSRange r = [self selectedRange];
    unsigned minLoc = ( (r.location > 12) ? 12 : r.location);
    return [s rangeOfString:@"\\ref{" options:NSBackwardsSearch range:NSMakeRange(r.location - minLoc, minLoc)]; // make this a fairly small range, otherwise bad thing can happen when inserting
}

/* ssp: 2004-07-18
Override usual behaviour so we can have dots, colons and hyphens in our cite keys
requires X.3
*/
- (NSRange)rangeForUserCompletion {
    NSRange r = [self citeKeyRange];
    if (r.location != NSNotFound) {
	return r;
    }
    return [super rangeForUserCompletion];
}


/* ssp: 2004-07-18
Provide own completions based on results by Bibdesk
Should check whether Bibdesk is available first
setting initial selection in list to second item doesn't work
requires X.3
*/
- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(int *)index	{
	NSString * s = [[self textStorage] string];
	NSRange r = [self citeKeyRange];
        NSRange refLabelRange = [self refLabelRange];
        NSRange newRange = [self newCiteKeyRange];
	
	if (r.location != NSNotFound ){
		//	NSString * beginning = [s substringWithRange:NSMakeRange(charRange.location - 6, 6)];
#warning debug only
		NSString * end = [s substringWithRange:r];
        NSString *newend = [[s substringWithRange:newRange] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        end = newend;
		
		// code shamelessly lifted from Buzz Anderson's ASHandlerTest example app
		// Performance gain if we stored the script permanently? But where to store it?
		/* Locate the script within the bundle */
		NSString *scriptPath = [[NSBundle bundleWithIdentifier:BDSKInputManagerID] pathForResource:kScriptName ofType: kScriptType];
		NSURL *scriptURL = [NSURL fileURLWithPath: scriptPath];
		
		NSDictionary *errorInfo = nil;
		NSAppleScript *script = [[[NSAppleScript alloc] initWithContentsOfURL:scriptURL error:&errorInfo] autorelease];
		
		/* See if there were any errors loading the script */
		if (script && !errorInfo) {
			
			/* We have to construct an AppleEvent descriptor to contain the arguments for our handler call.  Remember that this list is 1, rather than 0, based. */
			NSAppleEventDescriptor *arguments = [[[NSAppleEventDescriptor alloc] initListDescriptor] autorelease];
			[arguments insertDescriptor: [NSAppleEventDescriptor descriptorWithString:end] atIndex: 1] ;
			
			errorInfo = nil;
			
			/* Call the handler using the method in our special NSAppleScript category */
			NSAppleEventDescriptor *result = [script callHandler: kHandlerName withArguments: arguments errorInfo: &errorInfo];
			
			if (!errorInfo ) {
				
				int n;
				
				if (result &&  (n = [result numberOfItems])) {
					// start with the system's standard completions
					NSMutableArray * returnArray = [[[super completionsForPartialWordRange:charRange indexOfSelectedItem:index] mutableCopy] autorelease];
					
					NSAppleEventDescriptor * stringAEDesc;
					NSString * completionString;
					
					while (n) {
						// run through the list top to bottom, keeping in mind it is 1 based.
						stringAEDesc = [result descriptorAtIndex:n];
						// insert 'identification string at end so we'll recognise our own completions in -insertCompletion:for...
						completionString = [[stringAEDesc stringValue] stringByAppendingString:kBibDeskInsertion];
						
						n--;
						// add in at beginning of array
						[returnArray insertObject:completionString atIndex:0];
					}			
					
					if ([returnArray count]  == 1) {
						// if we have only one item for completion, artificially add a second one, so the user can review the full information before adding it to the document.
						[returnArray addObject:kHint];
						//  also set the index to 1, so the 'heading' line isn't selected initially.
						// THIS DOESN'T SEEM TO WORK!
						// *index = 1;
					}
					
					return returnArray;
				} 
			} // no script running error	
		} // no script loading error
	} // location > 5
	// if in doubt just stick to ordinary completion dictionary
        
        if(refLabelRange.location != NSNotFound){
            NSString *hintPossibilities = nil;
            unsigned hintLocation = refLabelRange.location + refLabelRange.length;
            unsigned maxHintLen = [s length] - hintLocation;
            
            hintPossibilities = [s substringWithRange:NSMakeRange(hintLocation, ( (maxHintLen <= 7) ? maxHintLen : 7 ) )];
            
            // scan up to a space or newline, since those shouldn't occur in a label, and use that as a hint for the \label scanner
            // if hintPossibilities is nil, don't scan, but hint needs to be nil since we check for that later
            NSString *hint = nil;
            if(hintPossibilities != nil){
                NSScanner *hintScanner = [[NSScanner alloc] initWithString:hintPossibilities];
                NSCharacterSet *stopSet = [NSCharacterSet characterSetWithCharactersInString:@"} \n\t"];
                [hintScanner setCharactersToBeSkipped:nil];
                [hintScanner scanUpToCharactersFromSet:stopSet intoString:&hint];
                [hintScanner release];
            }
            
            NSScanner *labelScanner = [[NSScanner alloc] initWithString:s];
            [labelScanner setCharactersToBeSkipped:nil];
            NSString *scanned = nil;
            NSMutableSet *setOfLabels = [NSMutableSet setWithCapacity:10];
            NSString *scanFormat;

            if(hint == nil){
                scanFormat = [NSString stringWithString:@"\\label{"];
            } else {
                scanFormat = [@"\\label{" stringByAppendingString:hint];
            }
            
            while(![labelScanner isAtEnd]){
                [labelScanner scanUpToString:scanFormat intoString:nil]; // scan for strings with \label{hint in them
                [labelScanner scanString:@"\\label{" intoString:nil];    // scan away the \label{
                [labelScanner scanUpToString:@"}" intoString:&scanned];  // scan up to the next brace
                if(scanned != nil) [setOfLabels addObject:[scanned stringByAppendingString:kBibDeskInsertion]]; // add it to the set
            }
            [labelScanner release];
            return [[setOfLabels allObjects] sortedArrayUsingFunction:arraySort context:NULL]; // return the set as an array, sorted alphabetically
        }
            
        
	return [super completionsForPartialWordRange:charRange indexOfSelectedItem:index];
}

int arraySort(NSString *str1, NSString *str2, void *context){
    return [str1 compare:str2];
}


/* ssp: 2004-07-18
finish off the completion, inserting just the cite key
requires X.3
*/
- (void)insertCompletion:(NSString *)word forPartialWordRange:(NSRange)charRange movement:(int)movement isFinal:(BOOL)flag {
    
	if (!flag || ([word rangeOfString:kBibDeskInsertion].location == NSNotFound)) {
		// this is just a preliminary completion (suggestion) or the word wasn't suggested by us anyway, so let the text system deal with this
                if([self refLabelRange].location != NSNotFound){ 
                    charRange = [self refLabelRange]; // if it's a \ref completion, set the selection properly, otherwise we can overwrite \ref{ itself
                    charRange.location += 5; // length of the \ref{ string
                }
		[super insertCompletion:word forPartialWordRange:charRange movement:movement isFinal:flag];
	}
	else {
		// final step
		
		/*
		 doesn't work
		if([word isEqualToString:kHint]) {
			// don't do anything if we get the heading 
			[super insertCompletion:@"" forPartialWordRange:charRange movement:NSCancelTextMovement isFinal:YES];
			return;
		}
		*/
	
		// strip the comment for this, this assumes cite keys can't have spaces in them
		NSRange firstSpace = [word rangeOfString:@" "];
		NSString * replacementString = [word substringToIndex:firstSpace.location];
                if([self refLabelRange].location != NSNotFound){
                    charRange = [self refLabelRange]; // if it's a \ref completion, set the selection properly, otherwise we can overwrite \ref{ itself
                    charRange.location += 5; // length of the \ref{ string
                }

		// add a little twist, so we can end completion by entering }
		// sadly NSCancelTextMovement  and NSOtherTextMovement both are 0, so we can't really tell the difference from movement alone
		int newMovement = movement;
		NSEvent * theEvent = [NSApp currentEvent];
		if ((movement == 0) && ([theEvent type] == NSKeyDown)) {
			// we've got a key event
			if ([[theEvent characters] isEqualToString:@"}"]) {
				// with a closing bracket 
				newMovement = NSRightTextMovement;
			}
		}			
		
		[super insertCompletion:replacementString forPartialWordRange:charRange movement:newMovement isFinal:flag];
	}

}

@end
