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
NSString *BDSKInputManagerLoadableApplications = @"Application bundles that we recognize";

static NSString *kScriptName = @"Bibdesk";
static NSString *kScriptType = @"scpt";
static NSString *kHandlerName = @"getcitekeys";

extern void _objc_resolve_categories_for_class(struct objc_class *cls);

@implementation NSTextView_Bibdesk

+ (void)load{
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier]; // for the app we are loading into
    NSArray *array = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:BDSKInputManagerID] objectForKey:BDSKInputManagerLoadableApplications];
    if(!array)
        array = [[[NSArray alloc] init] autorelease];

    if(debug) NSLog(@"We should enable for %@", [array description]);
  
    NSEnumerator *e = [array objectEnumerator];
    NSString *str;
    BOOL yn = NO;

    while(str = [e nextObject]){
        if([str caseInsensitiveCompare:bundleID] == NSOrderedSame){
            yn = YES;
            break;
        }
    }

    if(debug && yn) NSLog(@"Found a match; enabling autocompletion for %@", bundleID);

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

// ** Check to see if it's TeX
//  - look back to see if { ; if no brace, return not TeX
//  - if { found, look back between insertion point and { to find comma; check to see if it's BibTeX, then return the match range
// ** Check to see if it's BibTeX
//  - look back to see if it's jurabib with }{
//  - look back to see if ] ; if no options, then just find the citecommand (or not) by searching back from {
//  - look back to see if ][ ; if so, set ] range again
//  - look back to find [ starting from ]
//  - now we have the last [, see if there is a cite immediately preceding it using rangeOfString:@"cite" || rangeOfString:@"bibentry"
//  - if there were no brackets, but there was a double curly brace, then check for a jurabib citation
// ** After all of this, we've searched back to a brace, and then checked for a cite command with two optional parameters

NSRange SafeBackwardSearchRange(NSRange startRange, unsigned seekLength){
    unsigned minLoc = ( (startRange.location > seekLength) ? seekLength : startRange.location);
    return NSMakeRange(startRange.location - minLoc, minLoc);
}

- (BOOL)isBibTeXCitation:(NSRange)braceRange{
    NSString *str = [[self textStorage] string];
    NSRange citeSearchRange;
    NSRange doubleBracketRange;

    NSRange rightBracketRange = [str rangeOfString:@"]" options:NSBackwardsSearch | NSLiteralSearch range:SafeBackwardSearchRange(braceRange, 1)]; // see if there are any optional parameters

    // check for jurabib \citefield, which has two mandatory parameters in curly braces, e.g. \citefield[pagerange]{title}{cite:key}
    NSRange doubleBraceRange = [str rangeOfString:@"}{" options:NSBackwardsSearch | NSLiteralSearch range:SafeBackwardSearchRange( NSMakeRange(braceRange.location + 1, 1), 10)];
    
    if(rightBracketRange.location == NSNotFound && doubleBraceRange.location == NSNotFound){ // no options and not jurabib, so life is easy; look backwards 10 characters from the brace and see if there's a citecommand
        citeSearchRange = SafeBackwardSearchRange(braceRange, 20);
        if([str rangeOfString:@"cite" options:NSBackwardsSearch | NSLiteralSearch range:citeSearchRange].location != NSNotFound ||
           [str rangeOfString:@"bibentry" options:NSBackwardsSearch | NSLiteralSearch range:citeSearchRange].location != NSNotFound){
            return YES;
        } else {
            return NO;
        }
    }
    
    if(doubleBraceRange.location != NSNotFound) // reset the brace range if we have jurabib
        braceRange = [str rangeOfString:@"{" options:NSBackwardsSearch | NSLiteralSearch range:SafeBackwardSearchRange(doubleBraceRange, 10)];
    
    NSRange leftBracketRange = [str rangeOfString:@"[" options:NSBackwardsSearch | NSLiteralSearch]; // first occurrence of it, looking backwards
    // next, see if we have two optional parameters; this range is tricky, since we have to go forward one, then do a safe backward search over the previous characters
    if(leftBracketRange.location != NSNotFound){
        doubleBracketRange = [str rangeOfString:@"][" options:NSBackwardsSearch | NSLiteralSearch range:SafeBackwardSearchRange( NSMakeRange(leftBracketRange.location + 1, 3), 3)]; 
    } else {
        doubleBracketRange = NSMakeRange(NSNotFound, 0);
    }
    
    if(doubleBracketRange.location != NSNotFound) // if we had two parameters, find the last opening bracket
        leftBracketRange = [str rangeOfString:@"[" options:NSBackwardsSearch | NSLiteralSearch range:SafeBackwardSearchRange(doubleBracketRange, 50)];
    
    if(leftBracketRange.location != NSNotFound){
        citeSearchRange = SafeBackwardSearchRange(leftBracketRange, 20); // could be larger
        if([str rangeOfString:@"cite" options:NSBackwardsSearch | NSLiteralSearch range:citeSearchRange].location != NSNotFound ||
           [str rangeOfString:@"bibentry" options:NSBackwardsSearch | NSLiteralSearch range:citeSearchRange].location != NSNotFound){
            return YES;
        } else {
            return NO;
        }
    }
    
    if(doubleBraceRange.location != NSNotFound){ // jurabib with no options on it
        citeSearchRange = SafeBackwardSearchRange(braceRange, 20); // could be larger
        if([str rangeOfString:@"cite" options:NSBackwardsSearch | NSLiteralSearch range:citeSearchRange].location != NSNotFound ||
           [str rangeOfString:@"bibentry" options:NSBackwardsSearch | NSLiteralSearch range:citeSearchRange].location != NSNotFound){
            return YES;
        } else {
            return NO;
        }
    }        
    
    return NO;
}

NSRange SafeForwardSearchRange( unsigned startLoc, unsigned seekLength, unsigned maxLoc ){
    seekLength = ( (startLoc + seekLength > maxLoc) ? maxLoc - startLoc : seekLength );
    return NSMakeRange(startLoc, seekLength);
}
            
- (NSRange)citeKeyRange{
    NSString *str = [[self textStorage] string];
    NSRange r = [self selectedRange]; // here's the insertion point
    NSRange commaRange;
    NSRange finalRange;
    unsigned maxLoc;

    NSRange braceRange = [str rangeOfString:@"{" options:NSBackwardsSearch | NSLiteralSearch range:SafeBackwardSearchRange(r, 100)]; // look for an opening brace
    NSRange closingBraceRange = [str rangeOfString:@"}" options:NSBackwardsSearch | NSLiteralSearch range:SafeBackwardSearchRange(r, 100)];
    
    if(closingBraceRange.location != NSNotFound && closingBraceRange.location > braceRange.location) // if our { has a matching }, don't bother
        return finalRange = NSMakeRange(NSNotFound, 0);

    if(braceRange.location != NSNotFound){ // may be TeX
        commaRange = [str rangeOfString:@"," options:NSBackwardsSearch | NSLiteralSearch range:NSUnionRange(braceRange, r)]; // exclude commas in the optional parameters
    } else { // definitely not TeX
         return finalRange = NSMakeRange(NSNotFound, 0);
    }

    if([self isBibTeXCitation:braceRange]){
        if(commaRange.location != NSNotFound){
            maxLoc = ( (commaRange.location + 1 > r.location) ? commaRange.location : commaRange.location + 1 );
            finalRange = SafeForwardSearchRange(maxLoc, r.location - commaRange.location - 1, r.location);
        } else {
            maxLoc = ( (braceRange.location + 1 > r.location) ? braceRange.location : braceRange.location + 1 );
            finalRange = SafeForwardSearchRange(maxLoc, r.location - braceRange.location - 1, r.location);
        }
    } else {
        finalRange = NSMakeRange(NSNotFound, 0);
    }

    return finalRange;
}
                
- (NSRange)refLabelRange{
    NSString *s = [[self textStorage] string];
    NSRange r = [self selectedRange];
    return [s rangeOfString:@"\\ref{" options:NSBackwardsSearch range:SafeBackwardSearchRange(r, 12)]; // make this a fairly small range, otherwise bad thing can happen when inserting
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
	NSString *s = [[self textStorage] string];
        NSRange refLabelRange = [self refLabelRange];
        NSRange keyRange = ( (refLabelRange.location == NSNotFound) ? [self citeKeyRange] : NSMakeRange(NSNotFound, 0) ); // don't bother checking for a citekey if this is a \ref
	
	if(keyRange.location != NSNotFound){
                
            NSString *end = [[s substringWithRange:keyRange] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
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
					NSMutableArray *returnArray = [NSMutableArray array];
					
					NSAppleEventDescriptor *stringAEDesc;
					NSString *completionString;
					
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
