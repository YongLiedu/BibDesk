//
//  BDSKScriptGroupSheetController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 11/10/06.
/*
 This software is Copyright (c) 2006-2009
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
#import "BDSKScriptGroup.h"
#import "NSArray_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKFieldEditor.h"
#import "BDSKDragTextField.h"
#import "NSWindowController_BDSKExtensions.h"

@implementation BDSKScriptGroupSheetController

- (id)init {
    self = [self initWithGroup:nil];
    return self;
}

- (id)initWithGroup:(BDSKScriptGroup *)aGroup {
    if (self = [super init]) {
        group = [aGroup retain];
        path = [[group scriptPath] retain];
        arguments = [[group scriptArguments] retain];
        type = [group scriptType];
        undoManager = nil;
        dragFieldEditor = nil;
    }
    return self;
}

- (void)dealloc {
    [path release];
    [arguments release];
    [group release];
    [undoManager release];
    [dragFieldEditor release];
    [super dealloc];
}

- (void)awakeFromNib {
    [pathField registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
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
    if ([sender tag] == NSOKButton) {
        
        if ([self commitEditing] == NO)
            return;
        
        if ([[NSWorkspace sharedWorkspace] isAppleScriptFileAtPath:path])
            type = BDSKAppleScriptType;
        else
            type = BDSKShellScriptType;
        
        if(group == nil){
            group = [[BDSKScriptGroup alloc] initWithScriptPath:path scriptArguments:arguments scriptType:type];
        }else{
            [group setScriptPath:path];
            [group setScriptArguments:arguments];
            [group setScriptType:type];
            [[group undoManager] setActionName:NSLocalizedString(@"Edit Script Group", @"Undo action name")];
        }
        
    }
    
    [objectController setContent:nil];
    
    [super dismiss:sender];
}

- (void)chooseScriptPathPanelDidEnd:(NSOpenPanel *)oPanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSOKButton) {
        NSURL *url = [[oPanel URLs] firstObject];
        [self setPath:[url path]];
    }
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
    
    [oPanel beginSheetForDirectory:nil 
                              file:nil 
                    modalForWindow:[self window]
                     modalDelegate:self 
                    didEndSelector:@selector(chooseScriptPathPanelDidEnd:returnCode:contextInfo:) 
                       contextInfo:nil];
}

- (BDSKScriptGroup *)group {
    return group;
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
                            informativeTextWithFormat:errorMessage];
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
            [(BDSKFieldEditor *)dragFieldEditor registerForDelegatedDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
        }
        return dragFieldEditor;
    }
    return nil;
}

- (NSDragOperation)dragTextField:(BDSKDragTextField *)textField validateDrop:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *dragType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
    
    return dragType ? NSDragOperationEvery : NSDragOperationNone;
}

- (BOOL)dragTextField:(BDSKDragTextField *)textField acceptDrop:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]]) {
        NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
        if ([fileNames count]) {
            NSString *thePath = [[fileNames objectAtIndex:0] stringByExpandingTildeInPath];
            NSString *message = nil;
            if ([self isValidScriptFileAtPath:thePath error:&message]) {
                [self setPath:thePath];
                return YES;
            }
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
