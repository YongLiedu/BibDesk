//
//  NSTextView_Bibdesk.h
//  BibDeskInputManager
//
//  Created by Sven-S. Porst on Sat Jul 17 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NSAppleScript+HandlerCalls.h"

extern NSString *BDSKInputManagerID;
extern NSString *BDSKInputManagerLoadableApplications;
#define noScriptErr 0

#warning Can you #define a localized string?
// string to reconise the string we inserted
#define kBibDeskInsertion NSLocalizedString(@" (Bibdesk insertion)", @" (Bibdesk insertion)")
// hint string 
#define kHint NSLocalizedString(@"Hint: Just type } or , to insert the current item.",@"Hint: Just type } or , to insert the current item.")


@interface NSTextView_Bibdesk: NSTextView
/*!
    @method     printSelectorList:
    @abstract   Print a list to standard output of all the selectors to which a class object responds.
                Used only for debugging at this time.
    @param      anObject The object of interest.  Note that [self super] will not get the superclass
                of self; you need to use [self superclass] for this.
*/
+ (void)printSelectorList:(id)anObject;

/*!
    @method    isBibTeXCitation:
    @abstract   Returns whether the range immediately preceding braceRange is (probably) a citekey context.
    @param      braceRange The range of the first curly brace that you're interested in
    @discussion Uses some slightly bizarre heuristics for searching, but seems to work.  See the implementation for comments on why it works this way.
*/
- (BOOL)isBibTeXCitation:(NSRange)braceRange;

/*!
@function SafeBackwardSearchRange(NSRange startRange, unsigned seekLength)
@abstract   Returns a safe range for a backwards search, as used in -[NSString rangeOfString:@"findMe" options:NSBackwardsSearch range:aRange]
@discussion Useful when you want to search backwards an arbitrary distance, but may run into the beginning of the string (or textview text storage).
            This returns the maximum range you can search backwards, within your desired seek length, and avoids out of range exceptions.
            NSBackwardsSearch is confusing, since it starts from the <it>end</it> of the range and works towards the beginning.
@param      (startRange) The range of your initial starting point (only the startRange.location is used, but it was more convenient this way)
@param      (seekLength) The desired backwards search length, starting from startRange.location
@result     An NSRange with startRange.location and some maximum length to search backwards.
*/
NSRange SafeBackwardSearchRange(NSRange startRange, unsigned seekLength);

/*!
@function SafeForwardSearchRange( unsigned startLoc, unsigned seekLength, unsigned maxLength )
@abstract   Returns a range for a forward search that avoids out-of-range exceptions.
@discussion This is useful if you want to make safe adjustments to ranges, such as making a new range based on
            an existing range plus some offset value, since it gets confusing to keep track of the adjustments.
@param      (startLoc) The range.location you're starting the search from.
@param     (seekLength) The desired length to search (usually based on a guess of some sort), from startLoc.
@param      (maxLoc) The maximum location you're searching to (usually the maximum length of the textview storage)
@result     An NSRange with your given start as the location and a length corresponding to maxLoc or seekLength.
*/
NSRange SafeForwardSearchRange( unsigned startLoc, unsigned seekLength, unsigned maxLength );
- (NSRange) citeKeyRange;
- (NSRange)rangeForUserCompletion;
- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(int *)index;
- (void)insertCompletion:(NSString *)word forPartialWordRange:(NSRange)charRange movement:(int)movement isFinal:(BOOL)flag;
int arraySort(NSString *str1, NSString *str2, void *context);
@end
