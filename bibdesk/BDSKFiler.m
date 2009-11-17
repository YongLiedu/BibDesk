//
//  BDSKFiler.m
//  BibDesk
//
//  Created by Michael McCracken on Fri Apr 30 2004.
/*
 This software is Copyright (c) 2004-2009
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BDSKFiler.h"
#import "BDSKStringConstants.h"
#import "BibItem.h"
#import "NSImage_BDSKExtensions.h"
#import "BDSKScriptHookManager.h"
#import "BDSKPathColorTransformer.h"
#import "BibDocument.h"
#import "BibDocument_Actions.h"
#import "BDSKAppController.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKLinkedFile.h"
#import "BDSKPreferenceController.h"

// these keys should correspond to the table column identifiers
#define FILE_KEY           @"file"
#define PUBLICATION_KEY    @"publication"
#define OLD_PATH_KEY       @"oldPath"
#define NEW_PATH_KEY       @"path"
#define STATUS_KEY         @"status"
#define FLAG_KEY           @"flag"
#define FIX_KEY            @"fix"
#define SELECT_KEY         @"select"

@implementation BDSKFiler

+ (void)initialize {
    BDSKINITIALIZE;
	// register transformer class
	[NSValueTransformer setValueTransformer:[[[BDSKOldPathColorTransformer alloc] init] autorelease]
									forName:@"BDSKOldPathColorTransformer"];
	[NSValueTransformer setValueTransformer:[[[BDSKNewPathColorTransformer alloc] init] autorelease]
									forName:@"BDSKNewPathColorTransformer"];
}

static BDSKFiler *sharedFiler = nil;

+ (BDSKFiler *)sharedFiler{
	if (sharedFiler == nil)
		[[BDSKFiler alloc] init];
	return sharedFiler;
}

+ (id)allocWithZone:(NSZone *)zone {
    return sharedFiler ?: [super allocWithZone:zone];
}

- (id)init{
	if((sharedFiler == nil) && (sharedFiler = self = [super init])){
		errorInfoDicts = [[NSMutableArray alloc] initWithCapacity:10];
	}
	return sharedFiler;
}

- (id)retain { return self; }

- (id)autorelease { return self; }

- (void)release {}

- (NSUInteger)retainCount { return NSUIntegerMax; }

#pragma mark Auto file methods

- (void)filePapers:(NSArray *)papers fromDocument:(BibDocument *)doc check:(BOOL)check{
	NSString *papersFolderPath = [[NSUserDefaults standardUserDefaults] stringForKey:BDSKPapersFolderPathKey];

	if (NO == [NSString isEmptyString:papersFolderPath]) {
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL isDir, exists;
        
        papersFolderPath = [fm resolveAliasesInPath:papersFolderPath];
        exists = [fm fileExistsAtPath:papersFolderPath isDirectory:&isDir];
        if (exists == NO)
            isDir = exists = [fm createPathToFile:[papersFolderPath stringByAppendingPathComponent:@"0"] attributes:nil];
        
        if (exists == NO || isDir == NO) {
            // The directory isn't there or isn't a directory, so pop up an alert.
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Papers Folder doesn't exist", @"Message in alert dialog when unable to find Papers Folder")
                                             defaultButton:NSLocalizedString(@"OK", @"Button title")
                                           alternateButton:NSLocalizedString(@"Go to Preferences", @"Button title")
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"The Papers Folder you've chosen either doesn't exist or isn't a folder. Any files you have dragged in will be linked to in their original location. Press \"Go to Preferences\" to set the Papers Folder.", @"Informative text in alert dialog")];
            if ([alert runModal] == NSAlertAlternateReturn){
                [[BDSKPreferenceController sharedPreferenceController] showWindow:self];
                [[BDSKPreferenceController sharedPreferenceController] selectPaneWithIdentifier:@"edu.ucsd.cs.mmccrack.bibdesk.prefpane.autofile"];
            }
            return;
        }
	}
	
    NSInteger mask = BDSKInitialAutoFileOptionMask;
    if (check) mask |= BDSKCheckCompleteAutoFileOptionMask;
	[self movePapers:papers forField:BDSKLocalFileString fromDocument:doc options:mask];
}

- (void)movePapers:(NSArray *)paperInfos forField:(NSString *)field fromDocument:(BibDocument *)doc options:(NSInteger)mask{
	NSFileManager *fm = [NSFileManager defaultManager];
    NSInteger numberOfPapers = [paperInfos count];
	BibItem *pub = nil;
	BDSKLinkedFile *file = nil;
	NSString *oldPath = nil;
	NSString *newPath = nil;
	NSMutableArray *fileInfoDicts = [NSMutableArray arrayWithCapacity:numberOfPapers];
	NSMutableDictionary *info = nil;
	NSError *error = nil;
    
    BOOL initial = (mask & BDSKInitialAutoFileOptionMask);
    BOOL force = (mask & BDSKForceAutoFileOptionMask);
    BOOL check = (initial) && (force == NO) && (mask & BDSKCheckCompleteAutoFileOptionMask);
    
	if (numberOfPapers == 0)
		return;
	
	if (initial && [field isEqualToString:BDSKLocalFileString] == NO)
        [NSException raise:BDSKUnimplementedException format:@"%@ is only implemented for local files for initial moves.",NSStringFromSelector(_cmd)];
	
	if (numberOfPapers > 1) {
        if (progressWindow == nil)
            [NSBundle loadNibNamed:@"AutoFileProgress" owner:self];
		[progressIndicator setMaxValue:numberOfPapers];
		[progressIndicator setDoubleValue:0.0];
        [progressWindow orderFront:nil];
	}
	
	for (id paperInfo in paperInfos) {
		
		if (initial) {
			// autofile action: an array of BDSKLinkedFiles
			file = (BDSKLinkedFile *)paperInfo;
			pub = (BibItem *)[file delegate];
			oldPath = [[file URL] path];
			newPath = [[pub suggestedURLForLinkedFile:file] path];
		} else {
			// an explicit move, possibly from undo: a list of info dictionaries
			file = [paperInfo valueForKey:FILE_KEY];
			pub = [paperInfo valueForKey:PUBLICATION_KEY];
			oldPath = [[file URL] path];
			newPath = [paperInfo valueForKey:NEW_PATH_KEY];
		}
		
		if (numberOfPapers > 1) {
			[progressIndicator incrementBy:1.0];
			[progressIndicator displayIfNeeded];
		}
			
		if ([NSString isEmptyString:oldPath] || [NSString isEmptyString:newPath] || [oldPath isEqualToString:newPath]) {
            [pub removeFileToBeFiled:file];
			continue;
        }
        
		info = [NSMutableDictionary dictionaryWithCapacity:6];
		[info setValue:file forKey:FILE_KEY];
		[info setValue:oldPath forKey:OLD_PATH_KEY];
		[info setValue:pub forKey:PUBLICATION_KEY];
        error = nil;
        
        if (check && NO == [pub canSetURLForLinkedFile:file]) {
            
            [info setValue:NSLocalizedString(@"Incomplete information to generate file name.",@"") forKey:STATUS_KEY];
            [info setValue:[NSNumber numberWithInt:BDSKIncompleteFieldsErrorMask] forKey:FLAG_KEY];
            [info setValue:NSLocalizedString(@"Move anyway.",@"") forKey:FIX_KEY];
            [info setValue:newPath forKey:NEW_PATH_KEY];
            [self insertObject:info inErrorInfoDictsAtIndex:[self countOfErrorInfoDicts]];
            
        } else {
            
            BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKWillAutoFileScriptHookName];
            if (scriptHook) {
                [scriptHook setField:field];
                [scriptHook setOldValues:[NSArray arrayWithObject:oldPath]];
                [scriptHook setNewValues:[NSArray arrayWithObject:newPath]];
                [[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:pub] document:doc];
            }
            
            if (NO == [fm movePath:oldPath toPath:newPath force:force error:&error]){ 
                
                NSDictionary *errorInfo = [error userInfo];
                [info setValue:[errorInfo objectForKey:NSLocalizedRecoverySuggestionErrorKey] forKey:FIX_KEY];
                [info setValue:[errorInfo objectForKey:NSLocalizedDescriptionKey] forKey:STATUS_KEY];
                [info setValue:[NSNumber numberWithInt:[error code]] forKey:FLAG_KEY];
                [info setValue:newPath forKey:NEW_PATH_KEY];
                [self insertObject:info inErrorInfoDictsAtIndex:[self countOfErrorInfoDicts]];
                
            } else {
                
                [file updateWithPath:newPath];
                // make sure the UI is updated
                [pub noteFilesChanged:YES];
                
                scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKDidAutoFileScriptHookName];
                if (scriptHook) {
                    [scriptHook setField:field];
                    [scriptHook setOldValues:[NSArray arrayWithObject:oldPath]];
                    [scriptHook setNewValues:[NSArray arrayWithObject:newPath]];
                    [[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:pub] document:doc];
                }
                
                // switch them as this is used in undo
                [info setValue:oldPath forKey:NEW_PATH_KEY];
                [fileInfoDicts addObject:info];
                
            }
            
            // we always do this even when it failed, to avoid retrying at every edit
            [pub removeFileToBeFiled:file];
            
        }
	}
	
	if (numberOfPapers > 1)
		[progressWindow orderOut:nil];
	
	NSUndoManager *undoManager = [doc undoManager];
	[[undoManager prepareWithInvocationTarget:self] 
		movePapers:fileInfoDicts forField:field fromDocument:doc options:0];
	
	if ([self countOfErrorInfoDicts] > 0) {
        document = [doc retain];
        fieldName = [field retain];
        options = mask;
		[self showProblems];
    }
}

#pragma mark Error reporting

- (void)showProblems{
    if (window == nil) {
        if([NSBundle loadNibNamed:@"AutoFile" owner:self] == NO){
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error loading AutoFile window module.", @"Message in alert dialog when unable to load window")
                                             defaultButton:nil
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"There was an error loading the AutoFile window module. BibDesk will still run, and automatically filing papers that are dragged in should still work fine. Please report this error to the developers. Sorry!", @"Informative text in alert dialog")];
            [alert setAlertStyle:NSCriticalAlertStyle];
            [alert runModal];
            return;
        }
	}
    [tv reloadData];
    if (options & BDSKInitialAutoFileOptionMask)
        [infoTextField setStringValue:NSLocalizedString(@"There were problems moving the following files to the location generated using the format string. You can retry to move items selected in the first column.",@"description string")];
    else
        [infoTextField setStringValue:NSLocalizedString(@"There were problems moving the following files to the target location. You can retry to move items selected in the first column.",@"description string")];
	[iconView setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
	[tv setDoubleAction:@selector(showFile:)];
	[tv setTarget:self];
    [forceCheckButton setState:NSOffState];
	[window makeKeyAndOrderFront:self];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:window];
}

- (IBAction)done:(id)sender{
    [window close];
}

- (IBAction)tryAgain:(id)sender{
	NSDictionary *info = nil;
    NSInteger i, count = [self countOfErrorInfoDicts];
	NSMutableArray *fileInfoDicts = [NSMutableArray arrayWithCapacity:count];
    
    for (i = 0; i < count; i++) {
        info = [self objectInErrorInfoDictsAtIndex:i];
        if ([[info objectForKey:SELECT_KEY] boolValue]) {
            if (options & BDSKInitialAutoFileOptionMask) {
                [fileInfoDicts addObject:[info objectForKey:PUBLICATION_KEY]];
            } else {
                [fileInfoDicts addObject:info];
            }
        }
    }
    
    if ([fileInfoDicts count] == 0) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Nothing Selected", @"Message in alert dialog when retrying to autofile without selection")
                                         defaultButton:NSLocalizedString(@"OK", @"Button title")
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"Please select the items you want to auto file again or press Done.", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:window
                          modalDelegate:nil
                         didEndSelector:NULL 
                            contextInfo:NULL];
        return;
    }
    
    BibDocument *doc = [[document retain] autorelease];
    NSString *field = [[fieldName retain] autorelease];
    NSInteger mask = (options & BDSKInitialAutoFileOptionMask);
    mask |= ([forceCheckButton state]) ? BDSKForceAutoFileOptionMask : (options & BDSKCheckCompleteAutoFileOptionMask);
    
    [window close];
    
    [self movePapers:fileInfoDicts forField:field fromDocument:doc options:mask];
}

- (IBAction)dump:(id)sender{
    NSMutableString *string = [NSMutableString string];
	NSDictionary *info = nil;
    NSInteger i, count = [self countOfErrorInfoDicts];
    
    for (i = 0; i < count; i++) {
        info = [self objectInErrorInfoDictsAtIndex:i];
        [string appendStrings:NSLocalizedString(@"Publication key: ", @"Label for autofile dump"),
                              [[info objectForKey:PUBLICATION_KEY] citeKey], @"\n", 
                              NSLocalizedString(@"Original path: ", @"Label for autofile dump"),
                              [[[info objectForKey:FILE_KEY] URL] path], @"\n", 
                              NSLocalizedString(@"New path: ", @"Label for autofile dump"),
                              [info objectForKey:NEW_PATH_KEY], @"\n", 
                              NSLocalizedString(@"Status: ",@"Label for autofile dump"),
                              [info objectForKey:STATUS_KEY], @"\n", 
                              NSLocalizedString(@"Fix: ", @"Label for autofile dump"),
                              (([info objectForKey:FIX_KEY] == nil) ? NSLocalizedString(@"Cannot fix.", @"Cannot fix AutoFile error") : [info objectForKey:FIX_KEY]),
                              @"\n\n", nil];
    }
    
    NSString *fileName = NSLocalizedString(@"BibDesk AutoFile Errors", @"Filename for dumped autofile errors.");
    NSString *path = [[NSFileManager defaultManager] desktopDirectory];
    if (path)
        path = [[NSFileManager defaultManager] uniqueFilePathWithName:[fileName stringByAppendingPathExtension:@"txt"] atPath:path];
    
    [string writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (void)windowWillClose:(NSNotification *)notification{
    if ([[notification object] isEqual:window]) {
        [[self mutableArrayValueForKey:@"errorInfoDicts"] removeAllObjects];
        [tv reloadData]; // this is necessary to avoid an exception
        [document release];
        document = nil;
        [fieldName release];
        fieldName = nil;
        options = 0;
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:window];
    }
}

#pragma mark Accessors

- (NSArray *)errorInfoDicts {
    return errorInfoDicts;
}

- (NSUInteger)countOfErrorInfoDicts {
    return [errorInfoDicts count];
}

- (id)objectInErrorInfoDictsAtIndex:(NSUInteger)idx {
    return [errorInfoDicts objectAtIndex:idx];
}

- (void)insertObject:(id)obj inErrorInfoDictsAtIndex:(NSUInteger)idx {
    [errorInfoDicts insertObject:obj atIndex:idx];
}

- (void)removeObjectFromErrorInfoDictsAtIndex:(NSUInteger)idx {
    [errorInfoDicts removeObjectAtIndex:idx];
}

#pragma mark table view stuff

// dummy dataSource implementation
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tView{ return 0; }
- (id)tableView:(NSTableView *)tView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{ return nil; }

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation{
	NSString *tcid = [tableColumn identifier];
    if ([tcid isEqualToString:SELECT_KEY]) {
        return NSLocalizedString(@"Select items to Try Again or to Force.", @"Tool tip message");
    }
    return [[self objectInErrorInfoDictsAtIndex:row] objectForKey:tcid];
}

- (IBAction)showFile:(id)sender{
    NSInteger row = [tv selectedRow];
    if (row == -1)
        return;
    NSDictionary *dict = [self objectInErrorInfoDictsAtIndex:row];
    NSInteger statusFlag = [[dict objectForKey:FLAG_KEY] integerValue];
    NSString *tcid = nil;
    NSString *path = nil;
    BibItem *pub = nil;
    NSInteger type = -1;

    if(sender == tv){
        NSInteger column = [tv clickedColumn];
        if(column == -1)
            return;
        tcid = [[[tv tableColumns] objectAtIndex:column] identifier];
        if([tcid isEqualToString:OLD_PATH_KEY] || [tcid isEqualToString:@"icon"]){
            type = 0;
        }else if([tcid isEqualToString:@"newPath"]){
            type = 1;
        }else if([tcid isEqualToString:STATUS_KEY] || [tcid isEqualToString:FIX_KEY]){
            type = 2;
        }
    }else if([sender isKindOfClass:[NSMenuItem class]]){
        type = [sender tag];
    }
    
    switch(type){
        case 0:
            if(statusFlag & BDSKSourceFileDoesNotExistErrorMask)
                return;
            path = [[[dict objectForKey:FILE_KEY] URL] path];
            [[NSWorkspace sharedWorkspace]  selectFile:path inFileViewerRootedAtPath:nil];
            break;
        case 1:
            if(!(statusFlag & BDSKTargetFileExistsErrorMask))
                return;
            path = [dict objectForKey:NEW_PATH_KEY];
            [[NSWorkspace sharedWorkspace]  selectFile:path inFileViewerRootedAtPath:nil];
            break;
        case 2:
            pub = [dict objectForKey:PUBLICATION_KEY];
            // at this moment we have the document set
            [document editPub:pub];
            break;
	}
}

- (NSMenu *)tableView:(NSTableView *)tv menuForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    return contextMenu;
}

@end


@implementation NSFileManager (BDSKFilerExtensions)

- (BOOL)movePath:(NSString *)path toPath:(NSString *)newPath force:(BOOL)force error:(NSError **)error{
    NSString *resolvedPath = nil;
    NSString *resolvedNewPath = nil;
    NSString *status = nil;
    NSString *fix = nil;
    NSInteger statusFlag = BDSKNoError;
    BOOL ignoreMove = NO;
    BOOL isDir;
    
    // filemanager needs aliases resolved for moving and existence checks
    // ...however we want to move aliases, not their targets
    // so we resolve aliases in the path to the containing folder
    resolvedNewPath = [[self resolveAliasesInPath:[newPath stringByDeletingLastPathComponent]] 
                        stringByAppendingPathComponent:[newPath lastPathComponent]];
    if (resolvedNewPath == nil) {
        status = NSLocalizedString(@"Unable to resolve aliases in path.", @"AutoFile error message");
        statusFlag =  BDSKCannotResolveAliasErrorMask;
    }
    
    resolvedPath = [[self resolveAliasesInPath:[path stringByDeletingLastPathComponent]] 
                    stringByAppendingPathComponent:[path lastPathComponent]];
    if (resolvedPath == nil) {
        status = NSLocalizedString(@"Unable to resolve aliases in path.", @"AutoFile error message");
        statusFlag = BDSKCannotResolveAliasErrorMask;
    }
    
    if(statusFlag == BDSKNoError){
        if([self fileExistsAtPath:resolvedNewPath]){
            if([self fileExistsAtPath:resolvedPath isDirectory:&isDir]){
                if(force){
                    NSString *backupPath = [[self desktopDirectory] stringByAppendingPathComponent:[resolvedNewPath lastPathComponent]];
                    backupPath = [self uniqueFilePathWithName:[resolvedNewPath lastPathComponent] atPath:[self desktopDirectory]];
                    if(![self movePath:resolvedNewPath toPath:backupPath force:NO error:NULL] && 
                        [self fileExistsAtPath:resolvedNewPath] && 
                        ![self removeItemAtPath:resolvedNewPath error:NULL]){
                        status = NSLocalizedString(@"Unable to remove existing file at target location.", @"AutoFile error message");
                        statusFlag = BDSKTargetFileExistsErrorMask | BDSKCannotRemoveFileErrorMask;
                        // cleanup: move back backup
                        if(![self moveItemAtPath:backupPath toPath:resolvedNewPath error:NULL] && [self fileExistsAtPath:resolvedNewPath]){
                            [self removeItemAtPath:backupPath error:NULL];
                        }
                    }
                }else{
                    if([self isDeletableFileAtPath:resolvedNewPath]){
                        status = NSLocalizedString(@"File exists at target location.", @"AutoFile error message");
                        fix = NSLocalizedString(@"Overwrite existing file.", @"AutoFile fix");
                    }else{
                        status = NSLocalizedString(@"Undeletable file exists at target location.", @"AutoFile error message");
                    }
                    statusFlag = BDSKTargetFileExistsErrorMask;
                }
            }else{
                if(force){
                    ignoreMove = YES;
                }else{
                    status = NSLocalizedString(@"Original file does not exist, file exists at target location.", @"AutoFile error message");
                    fix = NSLocalizedString(@"Use existing file at target location.", @"AutoFile fix");
                    statusFlag = BDSKSourceFileDoesNotExistErrorMask | BDSKTargetFileExistsErrorMask;
                }
            }
        }else if(![self fileExistsAtPath:resolvedPath]){
            status = NSLocalizedString(@"Original file does not exist.", @"AutoFile error message");
            statusFlag = BDSKSourceFileDoesNotExistErrorMask;
        }else if(![self isDeletableFileAtPath:resolvedPath]){
            if(force == NO){
                status = NSLocalizedString(@"Unable to move read-only file.", @"AutoFile error message");
                fix = NSLocalizedString(@"Copy original file.", @"AutoFile fix");
                statusFlag = BDSKCannotMoveFileErrorMask;
            }
        }
        if(statusFlag == BDSKNoError && ignoreMove == NO){
            NSString *fileType = [[self attributesOfItemAtPath:resolvedPath error:NULL] fileType];
 
            // create parent directories if necessary (OmniFoundation)
            if (NO == [self createPathToFile:resolvedNewPath attributes:nil]) {
                status = NSLocalizedString(@"Unable to create parent directory.", @"AutoFile error message");
                statusFlag = BDSKCannotCreateParentErrorMask;
            }
            if(statusFlag == BDSKNoError){
                if([fileType isEqualToString:NSFileTypeDirectory] && [[NSWorkspace sharedWorkspace] isFilePackageAtPath:resolvedPath] == NO && force == NO && 
                   [[NSUserDefaults standardUserDefaults] boolForKey:BDSKWarnOnMoveFolderKey]){
                    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Really Move Folder?", @"Message in alert dialog when trying to auto file a folder")
                                                     defaultButton:NSLocalizedString(@"Move", @"Button title")
                                                   alternateButton:NSLocalizedString(@"Don't Move", @"Button title") 
                                                       otherButton:nil
                                         informativeTextWithFormat:NSLocalizedString(@"AutoFile is about to move the folder \"%@\" to \"%@\". Do you want to move the folder?", @"Informative text in alert dialog"), path, newPath];
                    [alert setShowsSuppressionButton:YES];
                    ignoreMove = (NSAlertAlternateReturn == [alert runModal]);
                    if([[alert suppressionButton] state] == NSOnState)
                        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:BDSKWarnOnMoveFolderKey];
                }
                if(ignoreMove){
                    status = NSLocalizedString(@"Shouldn't move folder.", @"AutoFile error message");
                    fix = NSLocalizedString(@"Move anyway.", @"AutoFile fix");
                    statusFlag = BDSKCannotMoveFileErrorMask;
                }else if([fileType isEqualToString:NSFileTypeSymbolicLink]){
                    // unfortunately NSFileManager cannot reliably move symlinks...
                    NSString *pathContent = [self destinationOfSymbolicLinkAtPath:resolvedPath error:NULL];
                    if([pathContent isAbsolutePath] == NO){// it links to a relative path
                        pathContent = [[[resolvedPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:pathContent] stringByStandardizingPath];
                        pathContent = [pathContent relativePathFromPath:[resolvedNewPath stringByDeletingLastPathComponent]];
                    }
                    if(![self createSymbolicLinkAtPath:resolvedNewPath withDestinationPath:pathContent error:NULL]){
                        status = NSLocalizedString(@"Unable to move symbolic link.", @"AutoFile error message");
                        statusFlag = BDSKCannotMoveFileErrorMask;
                    }else{
                        if(![self removeItemAtPath:resolvedPath error:NULL]){
                            if (force == NO){
                                status = NSLocalizedString(@"Unable to remove original.", @"AutoFile error message");
                                fix = NSLocalizedString(@"Copy original file.", @"AutoFile fix");
                                statusFlag = BDSKCannotRemoveFileErrorMask;
                                //cleanup: remove new file
                                [self removeItemAtPath:resolvedNewPath error:NULL];
                            }
                        }
                    }
                }else if([self moveItemAtPath:resolvedPath toPath:resolvedNewPath error:NULL]){
                    if([[resolvedPath pathExtension] caseInsensitiveCompare:@"pdf"] == NSOrderedSame){
                        NSString *notesPath = [[resolvedPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"skim"];
                        NSString *newNotesPath = [[resolvedNewPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"skim"];
                        if([self fileExistsAtPath:notesPath] && [self fileExistsAtPath:newNotesPath] == NO){
                            [self moveItemAtPath:notesPath toPath:newNotesPath error:NULL];
                        }
                    }
                }else if([self fileExistsAtPath:resolvedNewPath]){ // error remove original file
                    if(force == NO){
                        status = NSLocalizedString(@"Unable to remove original file.", @"AutoFile error message");
                        fix = NSLocalizedString(@"Copy original file.", @"AutoFile fix");
                        statusFlag = BDSKCannotRemoveFileErrorMask;
                        // cleanup: move back
                        if(![self moveItemAtPath:resolvedNewPath toPath:resolvedPath error:NULL] && [self fileExistsAtPath:resolvedPath]){
                            [self removeItemAtPath:resolvedNewPath error:NULL];
                        }
                    }
                }else{ // other error while moving file
                    status = NSLocalizedString(@"Unable to move file.", @"AutoFile error message");
                    statusFlag = BDSKCannotMoveFileErrorMask;
                }
            }
        }
    }
    
    if(statusFlag != BDSKNoError){
        if(error){
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:status, NSLocalizedDescriptionKey, nil];
            if (fix != nil)
                [userInfo setObject:fix forKey:NSLocalizedRecoverySuggestionErrorKey];
            *error = [NSError errorWithDomain:@"BDSKFilerErrorDomain" code:statusFlag userInfo:userInfo];
            //NSLog(@"error \"%@\" occurred; suggested fix is \"%@\"", *error, fix);
        }
        return NO;
    }
    return YES;
}

@end
