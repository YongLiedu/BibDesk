//
//  BDSKScriptGroupSheetController.m
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

#import "BDSKScriptGroupSheetController.h"
#import "NSArray_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKFieldEditor.h"
#import "BDSKDragTextField.h"
#import "NSWindowController_BDSKExtensions.h"
#import "NSPasteboard_BDSKExtensions.h"

@implementation BDSKScriptGroupSheetController

- (id)init {
    self = [self initWithPath:nil arguments:nil];
    return self;
}

- (id)initWithPath:(NSString *)aPath arguments:(NSString *)anArguments {
    self = [super init];
    if (self) {
        path = [aPath retain];
        arguments = [anArguments retain];
        undoManager = nil;
        dragFieldEditor = nil;
    }
    return self;
}

- (void)dealloc {
    [pathField setDelegate:nil];
    BDSKDESTROY(path);
    BDSKDESTROY(arguments);
    BDSKDESTROY(undoManager);
    BDSKDESTROY(dragFieldEditor);
    [super dealloc];
}

- (void)awakeFromNib {
    [pathField registerForDraggedTypes:[NSArray arrayWithObjects:(NSString *)kUTTypeFileURL, NSFilenamesPboardType, nil]];
}

- (NSString *)windowNibName {
    return @"BDSKScriptGroupSheet";
}

- (BOOL)isValidScriptFileAtPath:(NSString *)thePath error:(NSString **)message
{
    NSParameterAssert(nil != message);
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isValid;
    BOOL isDir;
    // path is bound to the text field and not validated, so we can get a tilde-path
    thePath = [thePath stringByStandardizingPath];
    if (NO == [fm fileExistsAtPath:thePath isDirectory:&isDir]) {
        // no file; this will never work...
        isValid = NO;
        *message = NSLocalizedString(@"The specified file does not exist.", @"Error description");
    } else if (isDir) {
        // directories aren't scripts
        isValid = NO;
        *message = NSLocalizedString(@"The specified file is a directory, not a script file.", @"Error description");
    } else if ([fm isExecutableFileAtPath:thePath] == NO && [[NSWorkspace sharedWorkspace] isAppleScriptFileAtPath:thePath] == NO) {
        // it's not executable
        isValid = NO;
        *message = NSLocalizedString(@"The file does not have execute permission set.", @"Error description");
    } else {
        isValid = YES;
    }

    return isValid;
}

- (IBAction)dismiss:(id)sender {
    if ([sender tag] == NSOKButton && [self commitEditing] == NO) {
        NSBeep();
        return;
    }
    
    [objectController setContent:nil];
    
    [super dismiss:sender];
}

// open panel delegate method
- (BOOL)panel:(id)sender shouldShowFilename:(NSString *)filename {
    return ([[NSWorkspace sharedWorkspace] isAppleScriptFileAtPath:filename] || [[NSFileManager defaultManager] isExecutableFileAtPath:filename] || [[NSWorkspace sharedWorkspace] isFolderAtPath:filename]);
}

- (IBAction)chooseScriptPath:(id)sender {
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:NO];
    [oPanel setResolvesAliases:NO];
    [oPanel setCanChooseDirectories:NO];
    [oPanel setPrompt:NSLocalizedString(@"Choose", @"Prompt for Choose panel")];
    [oPanel setDelegate:self];
    
    [oPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [[oPanel URLs] firstObject];
            [self setPath:[url path]];
        }
    }];
}

- (NSString *)path{
    return path;
}

- (void)setPath:(NSString *)newPath{
    if(path != newPath){
        [(BDSKScriptGroupSheetController *)[[self undoManager] prepareWithInvocationTarget:self] setPath:path];
        [path release];
        path = [newPath retain];
    }
}

- (NSString *)arguments{
    return arguments;
}

- (void)setArguments:(NSString *)newArguments{
    if(arguments != newArguments){
        [(BDSKScriptGroupSheetController *)[[self undoManager] prepareWithInvocationTarget:self] setArguments:arguments];
        [arguments release];
        arguments = [newArguments retain];
    }
}

#pragma mark NSEditor

- (BOOL)commitEditing {
    if ([objectController commitEditing] == NO)
			return NO;
    
    NSString *errorMessage;
    if ([self isValidScriptFileAtPath:path error:&errorMessage] == NO) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Script Path", @"Message in alert dialog when path for script group is invalid")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                            informativeTextWithFormat:@"%@", errorMessage];
        [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:NULL contextInfo:NULL];
        return NO;
    }
    
    return YES;
}

#pragma mark Dragging support

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject {
    if (anObject == pathField) {
        if (dragFieldEditor == nil) {
            dragFieldEditor = [[BDSKFieldEditor alloc] init];
            [(BDSKFieldEditor *)dragFieldEditor registerForDelegatedDraggedTypes:[NSArray arrayWithObjects:(NSString *)kUTTypeFileURL, NSFilenamesPboardType, nil]];
        }
        return dragFieldEditor;
    }
    return nil;
}

- (NSDragOperation)dragTextField:(BDSKDragTextField *)textField validateDrop:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    BOOL canRead = [pboard canReadFileURLOfTypes:nil];
    
    return canRead ? NSDragOperationEvery : NSDragOperationNone;
}

- (BOOL)dragTextField:(BDSKDragTextField *)textField acceptDrop:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSArray *fileURLs = [pboard readFileURLsOfTypes:nil];
    
    if ([fileURLs count] > 0) {
        NSString *thePath = [[fileURLs objectAtIndex:0] path];
        NSString *message = nil;
        if ([self isValidScriptFileAtPath:thePath error:&message]) {
            [self setPath:thePath];
            return YES;
        }
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
