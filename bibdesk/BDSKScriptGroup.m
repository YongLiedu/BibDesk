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
#import "BibTeXParser.h"
#import "NSString_BDSKExtensions.h"
#import "NSImage+Toolbox.h"
#import "BibAppController.h"


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
    NSString *output = nil;
    NSError *error = nil;
    
    if (scriptType == BDSKShellScriptType) {
        NSString *currentDirPath = [[NSApp delegate] temporaryFilePath:nil createDirectory:YES];
        output = [[BDSKShellTask shellTask] executeBinary:scriptPath 
                                             inDirectory:currentDirPath
                                           withArguments:scriptArguments
                                             environment:nil
                                             inputString:nil];
    } else if (scriptType == BDSKAppleScriptType) {
		NSDictionary *errorInfo = nil;
        NSAppleScript *script = [[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:scriptPath] error:&errorInfo];
		if (errorInfo) {
			NSLog(@"Error creating AppleScript: %@", [errorInfo objectForKey:NSAppleScriptErrorMessage]);
            failedDownload = YES;
		} else {
            
            @try{
                // @@ this somehow does not work
                if ([scriptArguments count])
                    output = [script executeHandler:@"main" withParametersFromArray:scriptArguments];
                else // @@ maybe when there are no arguments we should just run the script?
                    output = [script executeHandler:@"main"];
            }
            @catch (id exception){
                NSLog(@"Error executing AppleScript for script group \"%@\": %@", name, [exception reason]);
                failedDownload = YES;
            }
            @finally{
                [script release];
            }
        }
    }
    
    NSArray *pubs = nil;
    
    if (nil == output) {
        // error?
        failedDownload = YES;
    } else {
        int type = [output contentStringType];
        if (type == BDSKBibTeXStringType) {
            pubs = [BibTeXParser itemsFromData:[output dataUsingEncoding:NSUTF8StringEncoding] error:&error document:nil];
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
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKURLGroupUpdatedNotification object:self userInfo:userInfo];
        
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
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKURLGroupUpdatedNotification object:self userInfo:userInfo];
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
