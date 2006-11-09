//
//  BDSKScriptGroupSheetController.m
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

#import "BDSKScriptGroupSheetController.h"
#import "BDSKScriptGroup.h"
#import "NSArray_BDSKExtensions.h"

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
    }
    return self;
}

- (void)dealloc {
    [path release];
    [arguments release];
    [group release];
    [undoManager release];
    [super dealloc];
}

- (NSString *)windowNibName {
    return @"BDSKScriptGroupSheet";
}

- (IBAction)dismiss:(id)sender {
    if ([sender tag] == NSOKButton) {
        if (![[self window] makeFirstResponder:[self window]])
            [[self window] endEditingFor:nil];
        
        BOOL isDir;
        if ([sender tag] == NSOKButton && (NO == [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || isDir || NO == [[NSFileManager defaultManager] isExecutableFileAtPath:path])) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Script Path", @"Invalid Script Path")
                                             defaultButton:nil
                                           alternateButton:nil
                                               otherButton:nil
                                informativeTextWithFormat:NSLocalizedString(@"The path does not point to a valid script.", @"")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:NULL contextInfo:NULL];
            return;
        }
        
        if(group == nil){
            group = [[BDSKScriptGroup alloc] initWithScriptPath:path scriptArguments:arguments scriptType:type];
        }else{
            [group setScriptPath:path];
            [group setScriptArguments:arguments];
            [group setScriptType:type];
            [[group undoManager] setActionName:NSLocalizedString(@"Edit Script Group", @"Edit script group")];
        }
	}
    
    [super dismiss:sender];
}

- (void)chooseScriptPathPanelDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSOKButton) {
        NSURL *url = [[oPanel URLs] firstObject];
        [self setPath:[url path]];
    }
}

- (IBAction)chooseScriptPath:(id)sender {
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:NO];
    [oPanel setResolvesAliases:NO];
    [oPanel setPrompt:NSLocalizedString(@"Choose", @"Choose")];
    
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

- (int)type{
    return type;
}

- (void)setType:(int)newType{
    [[[self undoManager] prepareWithInvocationTarget:self] setType:type];
    type = newType;
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
