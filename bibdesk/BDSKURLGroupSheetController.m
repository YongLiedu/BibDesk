//
//  BDSKURLGroupSheetController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/10/06.
/*
 This software is Copyright (c) 2006
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

#import "BDSKURLGroupSheetController.h"
#import "BDSKURLGroup.h"
#import "NSArray_BDSKExtensions.h"

@implementation BDSKURLGroupSheetController

- (id)init {
    self = [self initWithGroup:nil];
    return self;
}

- (id)initWithGroup:(BDSKURLGroup *)aGroup {
    if (self = [super init]) {
        group = [aGroup retain];
        urlString = [[[group URL] absoluteString] retain];
        undoManager = nil;
    }
    return self;
}

- (void)dealloc {
    [urlString release];
    [group release];
    [undoManager release];
    [super dealloc];
}

- (NSString *)windowNibName {
    return @"BDSKURLGroupSheet";
}

- (IBAction)dismiss:(id)sender {
    if ([sender tag] == NSOKButton) {
        if (![[self window] makeFirstResponder:[self window]])
            [[self window] endEditingFor:nil];
        
        if ([NSString isEmptyString:urlString] == NO) {
            NSURL *url = nil;
            if ([urlString rangeOfString:@"://"].location == NSNotFound) {
                if ([[NSFileManager defaultManager] fileExistsAtPath:urlString])
                    url = [NSURL fileURLWithPath:urlString];
                else
                    url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", urlString]];
            } else
                url = [NSURL URLWithString:urlString];
            
            if(group == nil){
                group = [[BDSKURLGroup alloc] initWithURL:url];
            }else{
                [group setURL:url];
                [[group undoManager] setActionName:NSLocalizedString(@"Edit External File Group", @"Undo action name")];
            }
        } else {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Unable to create a group with an empty string", @"alert title") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
            return;
        }
	}
    
    [super dismiss:sender];
}

- (void)chooseURLPanelDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSOKButton) {
        NSURL *url = [[oPanel URLs] firstObject];
        [self setUrlString:[url absoluteString]];
    }
}

- (IBAction)chooseURL:(id)sender {
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:NO];
    [oPanel setResolvesAliases:NO];
    [oPanel setPrompt:NSLocalizedString(@"Choose", @"Prompt for Choose panel")];
    
    [oPanel beginSheetForDirectory:nil 
                              file:nil 
                    modalForWindow:[self window]
                     modalDelegate:self 
                    didEndSelector:@selector(chooseURLPanelDidEnd:returnCode:contextInfo:) 
                       contextInfo:nil];
}

- (BDSKURLGroup *)group {
    return group;
}

- (NSString *)urlString {
    return [[urlString retain] autorelease];
}

- (void)setUrlString:(NSString *)newUrlString {
    if (urlString != newUrlString) {
        [urlString release];
        urlString = [newUrlString copy];
    }
}

#pragma mark Undo support

- (NSUndoManager *)undoManager{
    if(undoManager == nil)
        undoManager = [[NSUndoManager alloc] init];
    return undoManager;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender{
    return [self undoManager];
}

@end
