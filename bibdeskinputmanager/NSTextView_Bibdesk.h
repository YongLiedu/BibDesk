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
#define noScriptErr 0

#warning Can you #define a localized (non-constant) string?
// string to reconise the string we inserted
#define kBibDeskInsertion NSLocalizedString(@" (Bibdesk insertion)", @" (Bibdesk insertion)")
// hint string 
#define kHint NSLocalizedString(@"Hint: Just type } or , to insert the current item.",@"Hint: Just type } or , to insert the current item.")


@interface NSTextView_Bibdesk: NSTextView
- (NSRange) citeKeyRange;
- (NSRange)rangeForUserCompletion;
- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(int *)index;
- (void)insertCompletion:(NSString *)word forPartialWordRange:(NSRange)charRange movement:(int)movement isFinal:(BOOL)flag;

@end
