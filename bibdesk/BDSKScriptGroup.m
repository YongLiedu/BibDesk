//
//  BDSKScriptGroup.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 10/19/06.
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

#import "BDSKScriptGroup.h"
#import "BDSKShellTask.h"
#import "KFAppleScriptHandlerAdditionsCore.h"
#import "KFASHandlerAdditions-TypeTranslation.h"
#import "BibTeXParser.h"
#import "NSString_BDSKExtensions.h"
#import "NSImage+Toolbox.h"
#import "BibAppController.h"
#import "NSError_BDSKExtensions.h"

#define APPLESCRIPT_HANDLER_NAME @"main"

@implementation BDSKScriptGroup

- (id)initWithName:(NSString *)aName scriptPath:(NSString *)path scriptArguments:(NSArray *)arguments scriptType:(int)type;
{
    if(self = [super initWithName:aName count:0]){
        publications = nil;
        scriptPath = [path retain];
        scriptArguments = [arguments retain];
        scriptType = type;
        failedDownload = NO;
    }
    return self;
}

- (void)dealloc;
{
    [scriptPath release];
    [scriptArguments release];
    [publications release];
    [super dealloc];
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%@ %p>: {\n\t\tname: %@\n\tscript path: %@\n }", [self class], self, name, scriptPath];
}

#pragma mark Loading

- (void)loadUsingScript;
{
    NSString *outputString = nil;
    failedDownload = NO;
    NSError *error = nil;
    BOOL isDir;
    
    if([[NSFileManager defaultManager] fileExistsAtPath:scriptPath isDirectory:&isDir] && NO == isDir){
        if (scriptType == BDSKShellScriptType) {
                NSString *currentDirPath = [[NSApp delegate] temporaryFilePath:nil createDirectory:YES];
                outputString = [[BDSKShellTask shellTask] executeBinary:scriptPath 
                                                            inDirectory:currentDirPath
                                                          withArguments:scriptArguments
                                                            environment:nil
                                                            inputString:nil];
        } else if (scriptType == BDSKAppleScriptType) {
            NSDictionary *errorInfo = nil;
            NSAppleScript *script = [[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:scriptPath] error:&errorInfo];
            if (errorInfo) {
                error = [NSError mutableLocalErrorWithCode:kBDSKAppleScriptError localizedDescription:NSLocalizedString(@"Unable to Create AppleScript for ", @"")];
                [error setValue:[errorInfo objectForKey:NSAppleScriptErrorMessage] forKey:NSLocalizedRecoverySuggestionErrorKey];
                failedDownload = YES;
            } else {
                
                @try{
                    if ([scriptArguments count])
                        outputString = [script executeHandler:APPLESCRIPT_HANDLER_NAME withParametersFromArray:scriptArguments];
                    else 
                        outputString = [script executeHandler:APPLESCRIPT_HANDLER_NAME];
                }
                @catch (id exception){
                    // if there are no arguments we try to run the whole script
                    if ([scriptArguments count] == 0) {
                        NSDictionary *errorInfo = nil;
                        outputString = [[script executeAndReturnError:&errorInfo] objCObjectValue];
                    } else {
                        error = [NSError mutableLocalErrorWithCode:kBDSKAppleScriptError localizedDescription:NSLocalizedString(@"Error Executing AppleScript", @"")];
                        [error setValue:[exception reason] forKey:NSLocalizedRecoverySuggestionErrorKey];
                        failedDownload = YES;
                    }
                }
                @finally{
                    [script release];
                }
            }
        }
    } else {
        error = [NSError mutableLocalErrorWithCode:kBDSKFileNotFound localizedDescription:nil];
        if (isDir)
            [error setValue:NSLocalizedString(@"Script path points to a directory instead of a file", @"") forKey:NSLocalizedDescriptionKey];
        else
            [error setValue:NSLocalizedString(@"The script path points to a file that does not exist", @"") forKey:NSLocalizedDescriptionKey];
        [error setValue:scriptPath forKey:NSFilePathErrorKey];
        failedDownload = YES;
    }
    
    NSArray *pubs = nil;
    
    if (nil == outputString || error) {
        if (error == nil)
            error = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Script Did Not Return Anything", @"")];
        failedDownload = YES;
        [NSApp presentError:error];
    } else {
        int type = [outputString contentStringType];
        if (type == BDSKBibTeXStringType) {
            pubs = [BibTeXParser itemsFromData:[outputString dataUsingEncoding:NSUTF8StringEncoding] error:&error document:nil];
        } else {
            error = [NSError mutableLocalErrorWithCode:kBDSKUnknownError localizedDescription:NSLocalizedString(@"Script Did Not Return BibTeX", @"")];
        }
        if (pubs == nil || error) {
            failedDownload = YES;
            [NSApp presentError:error];
        }
    }
    [self setPublications:pubs];
}

#pragma mark Accessors

- (void)setName:(NSString *)newName;
{
    if (newName != name) {
		[(BDSKScriptGroup *)[[self undoManager] prepareWithInvocationTarget:self] setName:name];
        [name release];
        name = [newName retain];
    }
}

- (NSArray *)publications;
{
    if(publications == nil){
        // use this to notify the tableview to start the progress indicators
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"succeeded"];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKScriptGroupUpdatedNotification object:self userInfo:userInfo];
        
        // get the publications asynchronously if remote, synchronously if local
        [self loadUsingScript]; 
    }
    // this posts a notification that the publications of the group changed, forcing a redisplay of the table cell
    return publications;
}

- (void)setPublications:(NSArray *)newPublications;
{
    if(newPublications != publications){
        [publications release];
        publications = [newPublications retain];
    }
    
    [self setCount:[publications count]];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:(publications != nil)] forKey:@"succeeded"];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKScriptGroupUpdatedNotification object:self userInfo:userInfo];
}

- (BOOL)failedDownload { return failedDownload; }

- (NSString *)scriptPath;
{
    return scriptPath;
}

- (void)setScriptPath:(NSString *)newPath;
{
    if (newPath != scriptPath) {
		[(BDSKScriptGroup *)[[self undoManager] prepareWithInvocationTarget:self] setScriptPath:newPath];
        [scriptPath release];
        scriptPath = [newPath retain];
        
        [self setPublications:nil];
    }
}

- (NSArray *)scriptArguments;
{
    return scriptArguments;
}

- (void)setScriptArguments:(NSArray *)newArguments;
{
    if (newArguments != scriptArguments) {
		[(BDSKScriptGroup *)[[self undoManager] prepareWithInvocationTarget:self] setScriptArguments:newArguments];
        [scriptArguments release];
        scriptArguments = [newArguments retain];
        
        [self setPublications:nil];
    }
}

- (int)scriptType;
{
    return scriptType;
}

- (void)setScriptType:(int)newType;
{
    if (newType != scriptType) {
		[(BDSKScriptGroup *)[[self undoManager] prepareWithInvocationTarget:self] setScriptType:newType];
        scriptType = newType;
        
        [self setPublications:nil];
    }
}

- (NSUndoManager *)undoManager {
    return undoManager;
}

- (void)setUndoManager:(NSUndoManager *)newUndoManager {
    if (undoManager != newUndoManager) {
        [undoManager release];
        undoManager = [newUndoManager retain];
    }
}

// BDSKGroup overrides

- (NSImage *)icon {
    // @@ should get its own icon
    return [NSImage smallImageNamed:@"urlFolderIcon"];
}

- (BOOL)isScript { return YES; }

- (BOOL)isEditable { return YES; }

- (BOOL)containsItem:(BibItem *)item {
    // calling [self publications] will repeatedly reschedule a retrieval, which is undesirable if the the URL download is busy; containsItem is called very frequently
    NSArray *pubs = [publications retain];
    BOOL rv = [pubs containsObject:item];
    [pubs release];
    return rv;
}

- (BOOL)isValidDropTarget { return NO; }

@end
