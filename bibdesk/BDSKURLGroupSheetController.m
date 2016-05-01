//
//  BDSKURLGroupSheetController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/10/06.
/*
 This software is Copyright (c) 2006-2016
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
#import "NSArray_BDSKExtensions.h"
#import "NSError_BDSKExtensions.h"
#import "BibDocument.h"
#import "BDSKFieldEditor.h"
#import "BDSKDragTextField.h"
#import "NSWindowController_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSPasteboard_BDSKExtensions.h"

@implementation BDSKURLGroupSheetController

- (id)init {
    self = [self initWithURL:nil];
    return self;
}

- (id)initWithURL:(NSURL *)aURL {
    self = [super init];
    if (self) {
        urlString = [[aURL absoluteString] retain];
        undoManager = nil;
        dragFieldEditor = nil;
    }
    return self;
}

- (void)dealloc {
    [urlField setDelegate:nil];
    BDSKDESTROY(urlString);
    BDSKDESTROY(undoManager);
    BDSKDESTROY(dragFieldEditor);
    [super dealloc];
}

- (void)windowDidLoad {
    [urlField registerForDraggedTypes:[NSArray arrayWithObjects:(NSString *)kUTTypeURL, (NSString *)kUTTypeFileURL, NSFilenamesPboardType, NSURLPboardType, nil]];
}

- (NSString *)windowNibName {
    return @"BDSKURLGroupSheet";
}

- (IBAction)dismiss:(id)sender {
    if ([sender tag] == NSOKButton && [self commitEditing] == NO) {
        NSBeep();
        return;
    }
    
    [objectController setContent:nil];
    
    [super dismiss:sender];
}

- (IBAction)chooseURL:(id)sender {
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:NO];
    [oPanel setResolvesAliases:NO];
    [oPanel setPrompt:NSLocalizedString(@"Choose", @"Prompt for Choose panel")];
    
    [oPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        if (result == NSOKButton) {
            NSURL *url = [[oPanel URLs] firstObject];
            [self setUrlString:[url absoluteString]];
        }
    }];
}

- (NSString *)urlString {
    return [[urlString retain] autorelease];
}

- (void)setUrlString:(NSString *)newUrlString {
    if (urlString != newUrlString) {
        [[[self undoManager] prepareWithInvocationTarget:self] setUrlString:urlString];
        [urlString release];
        urlString = [newUrlString copy];
        [[self undoManager] setActionName:NSLocalizedString(@"Edit URL", @"Undo action name")];
    }
}

- (NSURL *)URL {
    NSURL *url = nil;
    if ([urlString rangeOfString:@"://"].location == NSNotFound) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:urlString])
            url = [NSURL fileURLWithPath:urlString];
        else
            url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", urlString]];
    } else
        url = [NSURL URLWithString:urlString];
    return url;
}

#pragma mark NSEditor

- (BOOL)commitEditing {
    if ([objectController commitEditing] == NO)
			return NO;
    
    if ([NSString isEmptyString:urlString]) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:NSLocalizedString(@"Empty URL", @"Message in alert dialog when URL for external file group is invalid")];
        [alert setInformativeText:NSLocalizedString(@"Unable to create a group with an empty string", @"Informative text in alert dialog when URL for external file group is invalid")];
        [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:NULL contextInfo:NULL];
        return NO;
    }
    return YES;
}

#pragma mark Dragging support

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject {
	if (dragFieldEditor == nil) {
		dragFieldEditor = [[BDSKFieldEditor alloc] init];
		[(BDSKFieldEditor *)dragFieldEditor registerForDelegatedDraggedTypes:[NSArray arrayWithObjects:(NSString *)kUTTypeURL, (NSString *)kUTTypeFileURL, NSURLPboardType, NSFilenamesPboardType, nil]];
	}
	return dragFieldEditor;
}

- (NSDragOperation)dragTextField:(BDSKDragTextField *)textField validateDrop:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
	BOOL canRead = [pboard canReadURL];
    
    return canRead ? NSDragOperationEvery : NSDragOperationNone;
}

- (BOOL)dragTextField:(BDSKDragTextField *)textField acceptDrop:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
	NSArray *urls = [pboard readURLs];
    
    if ([urls count] > 0) {
        [self setUrlString:[urls objectAtIndex:0]];
        return YES;
    }
    return NO;
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
