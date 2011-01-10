//
//  BDSKFiler.m
//  BibDesk
//
//  Created by Michael McCracken on Fri Apr 30 2004.
/*
 This software is Copyright (c) 2004-2011
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
#import "BDSKScriptHookManager.h"
#import "BibDocument.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BDSKLinkedFile.h"
#import "BDSKPreferenceController.h"
#import "BDSKFilerErrorController.h"
#import "NSString_BDSKExtensions.h"

#define BDSKFilerErrorDomain @"BDSKFilerErrorDomain"

NSString *BDSKFilerFileKey = @"file";
NSString *BDSKFilerPublicationKey = @"publication";
NSString *BDSKFilerOldPathKey = @"oldPath";
NSString *BDSKFilerNewPathKey = @"path";
NSString *BDSKFilerStatusKey = @"status";
NSString *BDSKFilerFlagKey = @"flag";
NSString *BDSKFilerFixKey = @"fix";

@implementation BDSKFiler

static BDSKFiler *sharedFiler = nil;

+ (BDSKFiler *)sharedFiler{
	if (sharedFiler == nil)
		sharedFiler = [[BDSKFiler alloc] init];
	return sharedFiler;
}

- (id)init{
    BDSKPRECONDITION(sharedFiler == nil);
	self = [super initWithWindowNibName:@"AutoFileProgress"];
	return self;
}

#pragma mark Auto file methods

- (void)autoFileLinkedFiles:(NSArray *)papers fromDocument:(BibDocument *)doc check:(BOOL)check{
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
	
    BDSKFilerOptions mask = BDSKInitialAutoFileOptionMask;
    if (check) mask |= BDSKCheckCompleteAutoFileOptionMask;
    
    NSMutableArray *paperInfos = [NSMutableArray arrayWithCapacity:[papers count]];
    for (BDSKLinkedFile *file in papers)
        [paperInfos addObject:[NSDictionary dictionaryWithObjectsAndKeys:file, BDSKFilerFileKey, [file delegate], BDSKFilerPublicationKey, nil]];
    
	[self movePapers:paperInfos forField:BDSKLocalFileString fromDocument:doc options:mask];
}

- (void)movePapers:(NSArray *)paperInfos forField:(NSString *)field fromDocument:(BibDocument *)doc options:(BDSKFilerOptions)mask{
	NSFileManager *fm = [NSFileManager defaultManager];
    NSInteger numberOfPapers = [paperInfos count];
	BibItem *pub = nil;
	BDSKLinkedFile *file = nil;
	NSString *oldPath = nil;
	NSString *newPath = nil;
	NSMutableArray *fileInfoDicts = [NSMutableArray arrayWithCapacity:numberOfPapers];
	NSMutableArray *errorInfoDicts = [NSMutableArray arrayWithCapacity:5];
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
        [self window];
		[progressIndicator setMaxValue:numberOfPapers];
		[progressIndicator setDoubleValue:0.0];
        [[self window] orderFront:nil];
	}
	
	for (id paperInfo in paperInfos) {
		
        file = [paperInfo valueForKey:BDSKFilerFileKey];
        pub = [paperInfo valueForKey:BDSKFilerPublicationKey];
        oldPath = [[file URL] path];
		if (initial) // autofile action: an array of BDSKLinkedFiles
			newPath = [[pub suggestedURLForLinkedFile:file] path];
		else // an explicit move, possibly from undo: a list of info dictionaries
			newPath = [paperInfo valueForKey:BDSKFilerNewPathKey];
		
		if (numberOfPapers > 1) {
			[progressIndicator incrementBy:1.0];
			[progressIndicator displayIfNeeded];
		}
			
		if ([NSString isEmptyString:oldPath] || [NSString isEmptyString:newPath] || [oldPath isEqualToString:newPath]) {
            [pub removeFileToBeFiled:file];
			continue;
        }
        
		info = [NSMutableDictionary dictionaryWithCapacity:6];
		[info setValue:file forKey:BDSKFilerFileKey];
		[info setValue:oldPath forKey:BDSKFilerOldPathKey];
		[info setValue:pub forKey:BDSKFilerPublicationKey];
        error = nil;
        
        if (check && NO == [pub canSetURLForLinkedFile:file]) {
            
            [info setValue:NSLocalizedString(@"Incomplete information to generate file name.",@"") forKey:BDSKFilerStatusKey];
            [info setValue:[NSNumber numberWithInteger:BDSKIncompleteFieldsErrorMask] forKey:BDSKFilerFlagKey];
            [info setValue:NSLocalizedString(@"Move anyway.",@"") forKey:BDSKFilerFixKey];
            [info setValue:newPath forKey:BDSKFilerNewPathKey];
            [errorInfoDicts addObject:info];
            
        } else {
            
            [[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKWillAutoFileScriptHookName 
                forPublications:[NSArray arrayWithObject:pub] document:doc 
                field:field oldValues:[NSArray arrayWithObject:oldPath] newValues:[NSArray arrayWithObject:newPath]];
            
            if (NO == [fm movePath:oldPath toPath:newPath force:force error:&error]){ 
                
                NSDictionary *errorInfo = [error userInfo];
                [info setValue:[errorInfo objectForKey:NSLocalizedRecoverySuggestionErrorKey] forKey:BDSKFilerFixKey];
                [info setValue:[errorInfo objectForKey:NSLocalizedDescriptionKey] forKey:BDSKFilerStatusKey];
                [info setValue:[NSNumber numberWithInteger:[error code]] forKey:BDSKFilerFlagKey];
                [info setValue:newPath forKey:BDSKFilerNewPathKey];
                [errorInfoDicts addObject:info];
                
            } else {
                
                [file updateWithPath:newPath];
                // make sure the UI is updated
                [pub noteFilesChanged:YES];
                
                // switch them as this is used in undo
                [info setValue:oldPath forKey:BDSKFilerNewPathKey];
                [fileInfoDicts addObject:info];
                
                [[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKDidAutoFileScriptHookName 
                    forPublications:[NSArray arrayWithObject:pub] document:doc 
                    field:field oldValues:[NSArray arrayWithObject:oldPath] newValues:[NSArray arrayWithObject:newPath]];
                
            }
            
            // we always do this even when it failed, to avoid retrying at every edit
            [pub removeFileToBeFiled:file];
            
        }
	}
	
	if (numberOfPapers > 1)
		[[self window] orderOut:nil];
	
	NSUndoManager *undoManager = [doc undoManager];
	[[undoManager prepareWithInvocationTarget:self] 
		movePapers:fileInfoDicts forField:field fromDocument:doc options:0];
	
	if ([errorInfoDicts count] > 0) {
		BDSKFilerErrorController *errorController = [[[BDSKFilerErrorController alloc] initWithErrors:errorInfoDicts forField:field fromDocument:doc options:mask] autorelease];
        [[errorController window] makeKeyAndOrderFront:nil];
    }
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
                    if([[resolvedPath pathExtension] isCaseInsensitiveEqual:@"pdf"]){
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
            *error = [NSError errorWithDomain:BDSKFilerErrorDomain code:statusFlag userInfo:userInfo];
            //NSLog(@"error \"%@\" occurred; suggested fix is \"%@\"", *error, fix);
        }
        return NO;
    }
    return YES;
}

@end
