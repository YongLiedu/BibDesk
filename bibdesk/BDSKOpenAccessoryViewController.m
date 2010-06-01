//
//  BDSKOpenAccessoryViewController.m
//  Bibdesk
//
//  Created by Christiaan on 6/1/10.
/*
 This software is Copyright (c) 2010
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

#import "BDSKOpenAccessoryViewController.h"
#import "NSArray_BDSKExtensions.h"
#import "BDSKStringEncodingManager.h"
#import "NSString_BDSKExtensions.h"
#import "BDSKStringConstants.h"

#define MAX_FILTER_HISTORY 7

@implementation BDSKOpenAccessoryViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:@"BDSKOpenAccessoryView" bundle:nil]) {
        // make sure the nib is loaded
        [self view];
    }
    return self;
}

- (NSView *)openTextEncodingAccessoryView {
    return openTextEncodingAccessoryView;
}

- (NSMutableArray *)commandHistoryFromDefaults {
    NSMutableArray *commandHistory = [NSMutableArray array];
    // this is a workaround for older versions which added the same command multiple times
    [commandHistory addNonDuplicateObjectsFromArray:[[NSUserDefaults standardUserDefaults] stringArrayForKey:BDSKFilterFieldHistoryKey]];
    // this is also a workaround for older versions
    if([commandHistory count] > MAX_FILTER_HISTORY)
        [commandHistory removeObjectsInRange:NSMakeRange(MAX_FILTER_HISTORY, [commandHistory count] - MAX_FILTER_HISTORY)];
    return commandHistory;
}

- (NSView *)openUsingFilterAccessoryView {
    if ([openTextEncodingPopupButton isDescendantOf:openUsingFilterAccessoryView] == NO) {
        NSRect frame = [openTextEncodingAccessoryView frame];
        frame.origin = NSZeroPoint;
        frame.size.width = NSWidth([openUsingFilterAccessoryView frame]);
        [openTextEncodingAccessoryView setFrame:frame];
        [openUsingFilterAccessoryView addSubview:openTextEncodingAccessoryView];
        
        NSArray *commandHistory = [self commandHistoryFromDefaults];
        [openUsingFilterComboBox removeAllItems];
        [openUsingFilterComboBox addItemsWithObjectValues:commandHistory];
        if ([commandHistory count]) {
            [openUsingFilterComboBox selectItemAtIndex:0];
            [openUsingFilterComboBox setObjectValue:[openUsingFilterComboBox objectValueOfSelectedItem]];
        }
    }
    return openUsingFilterAccessoryView;
}

- (NSStringEncoding)encoding {
    return [openTextEncodingPopupButton encoding];
}

- (void)setEncoding:(NSStringEncoding)encoding {
    [openTextEncodingPopupButton setEncoding:encoding];
}

- (NSString *)filterCommand {
    NSString *command = [openUsingFilterComboBox stringValue];
    if ([NSString isEmptyString:command] == NO) {
        NSMutableArray *commandHistory = [self commandHistoryFromDefaults];
        NSUInteger commandIndex = [commandHistory indexOfObject:command];
        if (commandIndex == NSNotFound) {
            // not in the array, so add it and then remove the tail
            [commandHistory insertObject:command atIndex:0];
            if([commandHistory count] > MAX_FILTER_HISTORY)
                [commandHistory removeLastObject];
        } else if (commandIndex != 0) {
            // already in the array, so move it to the head of the list
            [commandHistory removeObject:command];
            [commandHistory insertObject:command atIndex:0];
        }
        [[NSUserDefaults standardUserDefaults] setObject:commandHistory forKey:BDSKFilterFieldHistoryKey];
    }
    return command;
}

- (void)setFilterCommand:(NSString *)command {
    [openUsingFilterComboBox setStringValue:command];
}


@end
