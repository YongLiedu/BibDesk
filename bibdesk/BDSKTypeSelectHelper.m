//
//  BDSKTypeSelectHelper.m
//  BibDesk
//
//  Created by Christiaan Hofman on 8/11/06.
/*
 This software is Copyright (c) 2005,2006,2007
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKTypeSelectHelper.h"
#import <OmniFoundation/OmniFoundation.h>
#import <OmniBase/OmniBase.h>

#define REPEAT_CHARACTER '/'
#define CANCEL_CHARACTER 0x1B

static NSString *BDSKWindowDidChangeFirstResponderNotification = @"BDSKWindowDidChangeFirstResponderNotification";

@interface NSString (BDSKTypeAheadHelperExtensions)
- (BOOL)containsStringStartingAtWord:(NSString *)string options:(int)mask range:(NSRange)range;
@end

@interface NSWindow (BDSKTypeAheadHelperExtensions)
@end


@interface BDSKTypeSelectHelper (BDSKPrivate)
- (NSArray *)searchCache;
- (void)searchWithStickyMatch:(BOOL)allowUpdate;
- (void)stopTimer;
- (void)startTimer;
- (void)typeSelectSearchTimeout;
- (void)handleTimeoutNotification:(NSNotification *)notification;
- (NSTimeInterval)timeoutInterval;
- (unsigned int)indexOfMatchedItemAfterIndex:(unsigned int)selectedIndex;

@end

@implementation BDSKTypeSelectHelper

// Init and dealloc

- init;
{
    if(self = [super init]){
        searchCache = nil;
        searchString = nil;
        cycleResults = YES;
        matchPrefix = YES;
    }
    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self setDataSource:nil];
    [self stopTimer];
    [searchString release];
    [searchCache release];
    [super dealloc];
}

#pragma mark Accessors

- (id)dataSource;
{
    return dataSource;
}

- (void)setDataSource:(id)newDataSource;
{
    if (dataSource == newDataSource)
        return;
    
    dataSource = newDataSource;
    [self rebuildTypeSelectSearchCache];
}

- (BOOL)cyclesSimilarResults;
{
    return cycleResults;
}

- (void)setCyclesSimilarResults:(BOOL)newValue;
{
    cycleResults = newValue;
}

- (BOOL)matchesPrefix;
{
    return matchPrefix;
}

- (void)setMatchesPrefix:(BOOL)newValue;
{
    matchPrefix = newValue;
}

- (NSString *)searchString;
{
    return searchString;
}

- (void)setSearchString:(NSString *)newSearchString;
{
    if (searchString != newSearchString) {
        [searchString release];
        searchString = [newSearchString retain];
    }
}

- (BOOL)isProcessing;
{
    return processing;
}

#pragma mark API

- (void)rebuildTypeSelectSearchCache;
{    
    if (searchCache)
        [searchCache release];
    
    searchCache = [[dataSource typeSelectHelperSelectionItems:self] retain];
}

- (BOOL)processKeyDownEvent:(NSEvent *)keyEvent;
{
    if ([self isSearchEvent:keyEvent]) {
        [self searchWithEvent:keyEvent];
        return YES;
    } else if ([self isRepeatEvent:keyEvent]) {
        [self repeatSearch];
        return YES;
    } else if ([self isCancelEvent:keyEvent]) {
        [self cancelSearch];
        return YES;
    }
    return NO;
}

- (void)searchWithEvent:(NSEvent *)keyEvent;
{
    NSWindow *window = [NSApp keyWindow];
    NSText *fieldEditor = [window fieldEditor:YES forObject:self];
    
    if (processing == NO) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTimeoutNotification:) name:BDSKWindowDidChangeFirstResponderNotification object:window];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTimeoutNotification:) name:NSWindowDidResignKeyNotification object:window];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTimeoutNotification:) name:NSWindowWillCloseNotification object:window];
        [fieldEditor setDelegate:self];
        [fieldEditor setString:@""];
    }
    
    // Append the new character to the search string
    [fieldEditor interpretKeyEvents:[NSArray arrayWithObject:keyEvent]];
    [self setSearchString:[fieldEditor string]];
    
    if ([dataSource respondsToSelector:@selector(typeSelectHelper:updateSearchString:)])
        [dataSource typeSelectHelper:self updateSearchString:searchString];
    
    // Reset the timer if it hasn't expired yet
    [self startTimer];
    
    [self searchWithStickyMatch:processing];
    
    processing = YES;
}

- (void)repeatSearch;
{
    [self searchWithStickyMatch:NO];
    
    if ([searchString length] && [dataSource respondsToSelector:@selector(typeSelectHelper:updateSearchString:)])
        [dataSource typeSelectHelper:self updateSearchString:searchString];
    
    [self startTimer];
    
    processing = NO;
}

- (void)cancelSearch;
{
    if (timeoutEvent)
        [self typeSelectSearchTimeout];
}

- (BOOL)isTypeSelectEvent:(NSEvent *)keyEvent;
{
    return [self isSearchEvent:keyEvent] || [self isRepeatEvent:keyEvent] || [self isCancelEvent:keyEvent];
}

- (BOOL)isSearchEvent:(NSEvent *)keyEvent;
{
    if ([keyEvent type] != NSKeyDown)
        return NO;
    if ([keyEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask & ~NSShiftKeyMask & ~NSAlternateKeyMask & ~NSAlphaShiftKeyMask)
        return NO;
    
    static NSCharacterSet *nonAlphanumericCharacterSet = nil;
    if (nonAlphanumericCharacterSet == nil)
        nonAlphanumericCharacterSet = [[[NSCharacterSet alphanumericCharacterSet] invertedSet] copy];
    
    NSCharacterSet *invalidCharacters = [self isProcessing] ? [NSCharacterSet controlCharacterSet] : nonAlphanumericCharacterSet;
    
    return [[keyEvent characters] rangeOfCharacterFromSet:invalidCharacters].location == NSNotFound;
}

- (BOOL)isRepeatEvent:(NSEvent *)keyEvent;
{
    if ([keyEvent type] != NSKeyDown)
        return NO;
    
    NSString *characters = [keyEvent charactersIgnoringModifiers];
    unichar character = [characters length] > 0 ? [characters characterAtIndex:0] : 0;
	unsigned modifierFlags = [keyEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
    
    return modifierFlags == 0 && character == REPEAT_CHARACTER;
}

- (BOOL)isCancelEvent:(NSEvent *)keyEvent;
{
    if ([keyEvent type] != NSKeyDown)
        return NO;
    if ([self isProcessing] == NO)
        return NO;
    
    NSString *characters = [keyEvent charactersIgnoringModifiers];
    unichar character = [characters length] > 0 ? [characters characterAtIndex:0] : 0;
	unsigned modifierFlags = [keyEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
    
    return modifierFlags == 0 && character == CANCEL_CHARACTER;
}

@end


@implementation BDSKTypeSelectHelper (BDSKPrivate)

- (NSArray *)searchCache;
{
    if (searchCache == nil)
        [self rebuildTypeSelectSearchCache];
    return searchCache;
}

- (void)stopTimer;
{
    if (timeoutEvent != nil) {
        [[OFScheduler mainScheduler] abortEvent:timeoutEvent];
        [timeoutEvent release];
        timeoutEvent = nil;
    }
}

- (void)startTimer;
{
    [self stopTimer];
    timeoutEvent = [[[OFScheduler mainScheduler] scheduleSelector:@selector(typeSelectSearchTimeout) onObject:self afterTime:[self timeoutInterval]] retain];
}

- (void)typeSelectSearchTimeout;
{
    if([dataSource respondsToSelector:@selector(typeSelectHelper:updateSearchString:)])
        [dataSource typeSelectHelper:self updateSearchString:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopTimer];
    processing = NO;
    
    NSText *fieldEditor = [[NSApp keyWindow] fieldEditor:YES forObject:self];
    if ([fieldEditor delegate] == self) {
        // we pass a dummy key event to the field editor to clear any hanging dead keys (marked text)
        NSEvent *keyEvent = [NSEvent keyEventWithType:NSKeyDown
                                             location:NSZeroPoint
                                        modifierFlags:0
                                            timestamp:0
                                         windowNumber:0
                                              context:nil
                                           characters:@""
                          charactersIgnoringModifiers:@""
                                            isARepeat:NO
                                              keyCode:0];
        [fieldEditor interpretKeyEvents:[NSArray arrayWithObject:keyEvent]];
        [fieldEditor setDelegate:nil];
    }
}

- (void)handleTimeoutNotification:(NSNotification *)notification;
{
    [self typeSelectSearchTimeout];
}

// See http://www.mactech.com/articles/mactech/Vol.18/18.10/1810TableTechniques/index.html
- (NSTimeInterval)timeoutInterval {
    int keyThreshTicks = [[NSUserDefaults standardUserDefaults] integerForKey:@"InitialKeyRepeat"];
    if (0 == keyThreshTicks)
        keyThreshTicks = 35;	// apparent default value, translates to 1.17 sec timeout.
    
    return fmin(2.0 / 60.0 * keyThreshTicks, 2.0);
}

- (void)searchWithStickyMatch:(BOOL)sticky;
{
    OBPRECONDITION(dataSource != nil);
    
    if ([searchString length]) {
        unsigned int selectedIndex, startIndex, foundIndex;
        
        if (cycleResults) {
            selectedIndex = [dataSource typeSelectHelperCurrentlySelectedIndex:self];
            if (selectedIndex >= [[self searchCache] count])
                selectedIndex = NSNotFound;
        } else {
            selectedIndex = NSNotFound;
        }
        
        startIndex = selectedIndex;
        if (sticky && selectedIndex != NSNotFound)
            startIndex = startIndex > 0 ? startIndex - 1 : [[self searchCache] count] - 1;
        
        foundIndex = [self indexOfMatchedItemAfterIndex:startIndex];
        
        if (foundIndex == NSNotFound) {
            if ([dataSource respondsToSelector:@selector(typeSelectHelper:didFailToFindMatchForSearchString:)])
                [dataSource typeSelectHelper:self didFailToFindMatchForSearchString:searchString];
        } else if (foundIndex != selectedIndex) {
            // Avoid flashing a selection all over the place while you're still typing the thing you have selected
            [dataSource typeSelectHelper:self selectItemAtIndex:foundIndex];
        }
    }
}

- (unsigned int)indexOfMatchedItemAfterIndex:(unsigned int)selectedIndex;
{
    unsigned int labelCount = [[self searchCache] count];
    
    if (labelCount == NO)
        return NSNotFound;
    
    if (selectedIndex == NSNotFound)
        selectedIndex = labelCount - 1;

    unsigned int labelIndex = selectedIndex;
    BOOL looped = NO;
    int options = NSCaseInsensitiveSearch;
    
    if (matchPrefix)
        options |= NSAnchoredSearch;
    
    while (looped == NO) {
        NSString *label;
        
        if (++labelIndex == labelCount)
            labelIndex = 0;
        if (labelIndex == selectedIndex)
            looped = YES;
        
        label = [[self searchCache] objectAtIndex:labelIndex];
        if ([label containsStringStartingAtWord:searchString options:options range:NSMakeRange(0, [label length])])
            return labelIndex;
    }
    
    return NSNotFound;
}

@end

#pragma mark -

@implementation NSString (BDSKTypeAheadHelperExtensions)

- (BOOL)containsStringStartingAtWord:(NSString *)string options:(int)mask range:(NSRange)range {
    unsigned int stringLength = [string length];
    if (stringLength == 0 || stringLength > range.length)
        return NO;
    while (range.length >= stringLength) {
        NSRange r = [self rangeOfString:string options:mask range:range];
        if (r.location == NSNotFound)
            return NO;
        // see if we start at a "word boundary"
        if (r.location == 0 || [[NSCharacterSet alphanumericCharacterSet] characterIsMember:[self characterAtIndex:r.location - 1]] == NO)
            return YES;
        // if it's anchored, we only should search once
        if (mask & NSAnchoredSearch)
            return NO;
        // get the new range, shifted by one from the last match
        if (mask & NSBackwardsSearch)
            range = NSMakeRange(range.location, NSMaxRange(r) - range.location - 1);
        else
            range = NSMakeRange(r.location + 1, NSMaxRange(range) - r.location - 1);
    }
    return NO;
}

@end

#pragma mark -

@implementation NSWindow (BDSKTypeAheadHelperExtensions)

static BOOL (*originalMakeFirstResponder)(id, SEL, id) = NULL;

- (BOOL)replacementMakeFirstResponder:(NSResponder *)aResponder {
    id oldFirstResponder = [self firstResponder];
    BOOL success = originalMakeFirstResponder(self, _cmd, aResponder);
    if (oldFirstResponder != [self firstResponder])
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKWindowDidChangeFirstResponderNotification object:self];
    return success;
}

+ (void)load {
    originalMakeFirstResponder = (typeof(originalMakeFirstResponder))OBReplaceMethodImplementationWithSelector(self, @selector(makeFirstResponder:), @selector(replacementMakeFirstResponder:));
}

@end
