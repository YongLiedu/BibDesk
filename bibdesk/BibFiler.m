//
//  BibFiler.m
//  BibDesk
//
//  Created by Michael McCracken on Fri Apr 30 2004.
/*
 This software is Copyright (c) 2004,2005,2006
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

#import "BibFiler.h"
#import "NSImage+Toolbox.h"
#import "BDSKScriptHookManager.h"
#import "BDSKPathColorTransformer.h"
#import <OmniAppKit/OATextWithIconCell.h>
#import <OmniAppKit/NSTableView-OAExtensions.h>
#import "BibDocument.h"
#import "BibAppController.h"
#import "NSFileManager_BDSKExtensions.h"

static BibFiler *sharedFiler = nil;

@implementation BibFiler

+ (void)initialize {
	// register transformer class
	[NSValueTransformer setValueTransformer:[[[BDSKOldPathColorTransformer alloc] init] autorelease]
									forName:@"BDSKOldPathColorTransformer"];
	[NSValueTransformer setValueTransformer:[[[BDSKNewPathColorTransformer alloc] init] autorelease]
									forName:@"BDSKNewPathColorTransformer"];
}

+ (BibFiler *)sharedFiler{
	if(!sharedFiler){
		sharedFiler = [[BibFiler alloc] init];
	}
	return sharedFiler;
}

- (id)init{
	if(self = [super init]){
		errorInfoDicts = [[NSMutableArray alloc] initWithCapacity:10];
	}
	return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[errorInfoDicts release];
	[super dealloc];
}

- (void)awakeFromNib{
	// this isn't set properly in the nib because OATextWithIconCell does not override initWithCoder
	OATextWithIconCell *cell = [[tv tableColumnWithIdentifier:@"oldPath"] dataCell];
	[cell setDrawsHighlight:YES];
	[cell setImagePosition:NSImageLeft];
	cell = [[tv tableColumnWithIdentifier:@"newPath"] dataCell];
	[cell setDrawsHighlight:YES];
	[cell setImagePosition:NSImageLeft];
}

#pragma mark Auto file methods

- (void)filePapers:(NSArray *)papers fromDocument:(BibDocument *)doc ask:(BOOL)ask{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *papersFolderPath = [[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:BDSKPapersFolderPathKey];
	BOOL isDir;
	int rv;
	BOOL check = NO;

	if(![NSString isEmptyString:papersFolderPath] && !([fm fileExistsAtPath:[fm resolveAliasesInPath:papersFolderPath] isDirectory:&isDir] && isDir)){
		// The directory isn't there or isn't a directory, so pop up an alert.
		rv = NSRunAlertPanel(NSLocalizedString(@"Papers Folder doesn't exist",@""),
							 NSLocalizedString(@"The Papers Folder you've chosen either doesn't exist or isn't a folder. Any files you have dragged in will be linked to in their original location. Press \"Go to Preferences\" to set the Papers Folder.",@""),
							 NSLocalizedString(@"OK",@"OK"),NSLocalizedString(@"Go to Preferences",@""),nil);
		if (rv == NSAlertAlternateReturn){
				[[OAPreferenceController sharedPreferenceController] showPreferencesPanel:self];
				[[OAPreferenceController sharedPreferenceController] setCurrentClientByClassName:@"BibPref_AutoFile"];
		}
		return;
	}
	
	if(ask){
		rv = NSRunAlertPanel(NSLocalizedString(@"Consolidate Linked Files",@""),
							 NSLocalizedString(@"This will put all files linked to the selected items in your Papers Folder, according to the format string. Do you want me to generate a new location for all linked files, or only for those for which all the bibliographical information used in the generated file name has been set?",@""),
							 NSLocalizedString(@"Move All",@"Move All"),
							 NSLocalizedString(@"Cancel",@"Cancel"), 
							 NSLocalizedString(@"Move Complete Only",@"Move Complete Only"));
		if(rv == NSAlertOtherReturn){
			check = YES;
		}else if(rv == NSAlertAlternateReturn){
			return;
		}
	}
	
    int mask = BDSKInitialAutoFileOptionMask;
    if (check == YES) mask |= BDSKCheckCompleteAutoFileOptionMask;
	[self movePapers:papers forField:BDSKLocalUrlString fromDocument:doc options:mask];
}

- (void)movePapers:(NSArray *)paperInfos forField:(NSString *)field fromDocument:(BibDocument *)doc options:(int)mask{
	NSFileManager *fm = [NSFileManager defaultManager];
	int numberOfPapers = [paperInfos count];
	NSEnumerator *paperEnum = [paperInfos objectEnumerator];
	id paperInfo = nil;
	BibItem *paper = nil;
	NSString *path = nil;
	NSString *newPath = nil;
	NSString *resolvedPath = nil;
	NSString *resolvedNewPath = nil;
	NSMutableArray *fileInfoDicts = [NSMutableArray arrayWithCapacity:numberOfPapers];
	NSMutableDictionary *info = nil;
	NSString *status = nil;
	int statusFlag = BDSKNoErrorMask;
    NSString *fix = nil;
	BOOL useRelativePath = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKAutoFileUsesRelativePathKey];
    NSString *papersFolderPath = [[[NSApp delegate] folderPathForFilingPapersFromDocument:doc] stringByAppendingString:@"/"];
	
    BOOL initial = (mask & BDSKInitialAutoFileOptionMask);
    BOOL force = (mask & BDSKForceAutoFileOptionMask);
    BOOL check = (initial == YES) && (force == NO) && (mask & BDSKCheckCompleteAutoFileOptionMask);
    BOOL ignoreMove = NO;
    
	if (numberOfPapers == 0)
		return;
	
	if (initial == YES && [field isEqualToString:BDSKLocalUrlString] == NO)
        [NSException raise:BDSKUnimplementedException format:@"movePapers:forField:fromDocument:checkComplete:initialMove: is only implemented for the Local-Url field for initial moves."];
	
	if (numberOfPapers > 1 && [NSBundle loadNibNamed:@"AutoFileProgress" owner:self]) {
		[NSApp beginSheet:progressSheet
		   modalForWindow:[doc windowForSheet]
			modalDelegate:self
		   didEndSelector:NULL
			  contextInfo:nil];
		[progressIndicator setMaxValue:numberOfPapers];
		[progressIndicator setDoubleValue:0.0];
		[progressIndicator displayIfNeeded];
	}
	
	BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKWillAutoFileScriptHookName];
	NSMutableArray *papers = nil;
	NSMutableArray *oldValues = nil;
	NSMutableArray *newValues = nil;
	NSString *oldValue = nil;
	NSString *newValue = nil;
	
	if(scriptHook){
		papers = [NSMutableArray arrayWithCapacity:[paperInfos count]];
		while (paperInfo = [paperEnum nextObject]) {
			if(initial)
				[papers addObject:paperInfo];
			else
				[papers addObject:[paperInfo objectForKey:@"paper"]];
		}
		// we don't set the old/new values as the newValues are not reliable
		[scriptHook setField:field];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:papers];
	}
	
	scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKDidAutoFileScriptHookName];
	if(scriptHook){
		papers = [NSMutableArray arrayWithCapacity:[paperInfos count]];
		oldValues = [NSMutableArray arrayWithCapacity:[paperInfos count]];
		newValues = [NSMutableArray arrayWithCapacity:[paperInfos count]];
	}
	
	paperEnum = [paperInfos objectEnumerator];
	while (paperInfo = [paperEnum nextObject]) {
		
		if(initial){
			// autofile action: an array of BibItems
			paper = (BibItem *)paperInfo;
			path = [paper localURLPathInheriting:NO];
			newPath = [[NSURL URLWithString:[paper suggestedLocalUrl]] path];
		}else{
			// undo: a list of info dictionaries. We should move the file back!
			paper = [paperInfo objectForKey:@"paper"];
			path = [paperInfo objectForKey:@"oldPath"];
			newPath = [paperInfo objectForKey:@"newPath"];
		}
		
		if(progressSheet){
			[progressIndicator incrementBy:1.0];
			[progressIndicator displayIfNeeded];
		}
			
		if([NSString isEmptyString:path] || [NSString isEmptyString:newPath] || 
		   [path isEqualToString:newPath])
			continue;
		
		info = [NSMutableDictionary dictionaryWithCapacity:5];
		[info setObject:paper forKey:@"paper"];
		status = nil;
		fix = nil;
		statusFlag = BDSKNoErrorMask;
        ignoreMove = NO;
		// filemanager needs aliases resolved for moving and existence checks
		// ...however we want to move aliases, not their targets
		// so we resolve aliases in the path to the containing folder
		NS_DURING
			resolvedNewPath = [[fm resolveAliasesInPath:[newPath stringByDeletingLastPathComponent]] 
						 stringByAppendingPathComponent:[newPath lastPathComponent]];
		NS_HANDLER
            NSLog(@"Ignoring exception %@ raised while resolving aliases in %@", [localException name], newPath);
			status = NSLocalizedString(@"Unable to resolve aliases in path.\nFix: cannot fix.", @"");
			statusFlag = statusFlag | BDSKUnableToResolveAliasMask;
		NS_ENDHANDLER
		
		NS_DURING
			resolvedPath = [[fm resolveAliasesInPath:[path stringByDeletingLastPathComponent]] 
					  stringByAppendingPathComponent:[path lastPathComponent]];
		NS_HANDLER
            NSLog(@"Ignoring exception %@ raised while resolving aliases in %@", [localException name], path);
			status = NSLocalizedString(@"Unable to resolve aliases in path.", @"");
			statusFlag = statusFlag | BDSKUnableToResolveAliasMask;
		NS_ENDHANDLER
		
		if(check && ![paper canSetLocalUrl]){
            status = NSLocalizedString(@"Incomplete information to generate the file name.",@"");
            fix = NSLocalizedString(@"Move anyway.",@"");
			statusFlag = statusFlag | BDSKIncompleteFieldsMask;
		}
		
		if(statusFlag == BDSKNoErrorMask){
			if([fm fileExistsAtPath:resolvedNewPath]){
				if([fm fileExistsAtPath:resolvedPath]){
                    if(force == YES){
                        NSString *backupPath = [[fm desktopPathForCurrentUser] stringByAppendingPathComponent:[resolvedNewPath lastPathComponent]];
                        backupPath = [fm uniqueFilePath:backupPath createDirectory:NO];
                        if(![fm movePath:resolvedNewPath toPath:backupPath handler:self]){
                            status = [errorString autorelease];
                            statusFlag = statusFlag | BDSKGeneratedFileExistsMask | BDSKRemoveErrorMask;
                        }
                    }else{
                        status = NSLocalizedString(@"A file already exists at the generated location.",@"");
                        fix = NSLocalizedString(@"Overwrite existing file.",@"");
                        statusFlag = statusFlag | BDSKGeneratedFileExistsMask;
                    }
				}else{
                    if(force == YES){
                        ignoreMove = YES;
                    }else{
                        status = NSLocalizedString(@"The linked file does not exists, while a file already exists at the generated location.", @"");
                        fix = NSLocalizedString(@"Link to existing file.", @"");
                        statusFlag = statusFlag | BDSKOldFileDoesNotExistMask | BDSKGeneratedFileExistsMask;
                    }
				}
			}else if(![fm fileExistsAtPath:resolvedPath]){
				status = NSLocalizedString(@"The linked file does not exist.", @"");
				statusFlag = statusFlag | BDSKOldFileDoesNotExistMask;
			}else if(![fm isDeletableFileAtPath:resolvedPath]){
                if(force == NO){
                    status = NSLocalizedString(@"Could not move read-only file.", @"");
                    fix = NSLocalizedString(@"Copy the original file.", @"");
                    statusFlag = statusFlag | BDSKMoveErrorMask;
                }
			}
            if(statusFlag == BDSKNoErrorMask || ignoreMove){
				NSString *fileType = [[fm fileAttributesAtPath:resolvedPath traverseLink:NO] objectForKey:NSFileType];
				NS_DURING
					[fm createPathToFile:resolvedNewPath attributes:nil]; // create parent directories if necessary (OmniFoundation)
				NS_HANDLER
					NSLog(@"Ignoring exception %@ raised while creating path %@", [localException name], resolvedNewPath);
					status = NSLocalizedString(@"Unable to create the parent directory structure.", @"");
					statusFlag = statusFlag | BDSKUnableToCreateParentMask;
				NS_ENDHANDLER
				if(statusFlag == BDSKNoErrorMask){
					// unfortunately NSFileManager cannot reliably move symlinks...
					if([fileType isEqualToString:NSFileTypeSymbolicLink]){
						NSString *pathContent = [fm pathContentOfSymbolicLinkAtPath:resolvedPath];
						if(![pathContent hasPrefix:@"/"]){// it links to a relative path
							pathContent = [[resolvedPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:pathContent];
						}
						if(![fm createSymbolicLinkAtPath:resolvedNewPath pathContent:pathContent]){
							status = NSLocalizedString(@"Could not move symbolic link.", @"");
							statusFlag = statusFlag | BDSKMoveErrorMask;
						}else{
							if(![fm removeFileAtPath:resolvedPath handler:self]){
								if (force == NO){
                                    status = [NSString stringWithFormat:@"@%@ %@", NSLocalizedString(@"Could not remove original.", @""), [errorString autorelease]];
                                    fix = NSLocalizedString(@"Copy the original file.", @"");
                                    statusFlag = statusFlag | BDSKRemoveErrorMask;
                                    //cleanup: remove new file
                                    [fm removeFileAtPath:resolvedNewPath handler:nil];
                                }
							}
							//status = NSLocalizedString(@"Successfully moved.",@"");
						}
					}else if([fm movePath:resolvedPath toPath:resolvedNewPath handler:self]){
						//status = NSLocalizedString(@"Successfully moved.",@"");
					}else if([fm fileExistsAtPath:resolvedNewPath]){ // error remove original file
						if(force == NO){
                            status = [NSString stringWithFormat:@"@%@ %@", NSLocalizedString(@"Could not remove original.", @""), [errorString autorelease]];
                            fix = NSLocalizedString(@"Copy the original file.", @"");
                            statusFlag = statusFlag | BDSKRemoveErrorMask;
                            // cleanup: move back
                            if(![fm movePath:resolvedNewPath toPath:resolvedPath handler:nil] && [fm fileExistsAtPath:resolvedPath]){
                                [fm removeFileAtPath:resolvedNewPath handler:nil];
                            }
                        }
					}else{ // other error while moving file
						status = [errorString autorelease];
						statusFlag = statusFlag | BDSKMoveErrorMask;
					}
				}
			}
		}
		
		if(statusFlag == BDSKNoErrorMask){ 
			oldValue  = [[NSURL fileURLWithPath:path] absoluteString]; // we don't use the field value, as we might have already changed it in undo or find/replace
			newValue  = [[NSURL fileURLWithPath:newPath] absoluteString];
			if(initial) {// otherwise will be done by undo of setField:
                if(useRelativePath){
                    NSString *relativePath = newPath;
                    if ([newPath hasPrefix:papersFolderPath])
                        [newPath substringFromIndex:[papersFolderPath length]];
                    [paper setField:field toValue:relativePath];
                }else{
                    [paper setField:field toValue:newValue];
                }
			}
            if(scriptHook){
				[papers addObject:paper];
				[oldValues addObject:oldValue];
				[newValues addObject:newValue];
			}
			// switch them as this is used in undo
            [info setObject:path forKey:@"newPath"];
            [info setObject:newPath forKey:@"oldPath"];
			[fileInfoDicts addObject:info];
		}else{
            [info setObject:path forKey:@"oldPath"];
            [info setObject:newPath forKey:@"newPath"];
			[info setObject:status forKey:@"status"];
			[info setObject:[NSNumber numberWithInt:statusFlag] forKey:@"flag"];
            if(fix != nil){
                [info setObject:fix forKey:@"fix"];
			}
            [self insertObject:info inErrorInfoDictsAtIndex:[self countOfErrorInfoDicts]];
		}
	}
	
	if(scriptHook){
		[scriptHook setField:field];
		[scriptHook setOldValues:oldValues];
		[scriptHook setNewValues:newValues];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:papers];
	}
	
	if(progressSheet){
		[progressSheet orderOut:nil];
		[NSApp endSheet:progressSheet returnCode:0];
	}
	
	NSUndoManager *undoManager = [doc undoManager];
	[[undoManager prepareWithInvocationTarget:self] 
		movePapers:fileInfoDicts forField:field fromDocument:doc options:0];
	
	if([self countOfErrorInfoDicts] > 0){
        document = [doc retain];
        fieldName = [field retain];
        options = mask;
		[self showProblems];
    }
}

- (void)windowWillClose:(NSNotification *)notification{
	[[self mutableArrayValueForKey:@"errorInfoDicts"] removeAllObjects];
	[tv reloadData]; // this is necessary to avoid an exception
    [document release];
    document = nil;
    [fieldName release];
    fieldName = nil;
    options = 0;
}

- (void)showProblems{
	BOOL success = [NSBundle loadNibNamed:@"AutoFile" owner:self];
	if(!success){
		NSRunCriticalAlertPanel(NSLocalizedString(@"Error loading AutoFile window module.",@""),
								NSLocalizedString(@"There was an error loading the AutoFile window module. BibDesk will still run, and automatically filing papers that are dragged in should still work fine. Please report this error to the developers. Sorry!",@""),
								NSLocalizedString(@"OK",@"OK"),nil,nil);
		return;
	}

	[tv reloadData];
	[infoTextField setStringValue:NSLocalizedString(@"There were problems moving the following files to the generated file location, according to the format string.",@"description string")];
	[iconView setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
	[tv setDoubleAction:@selector(showFile:)];
	[tv setTarget:self];
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
    int force = [sender tag];
	NSDictionary *info = nil;
    int i, count = [self countOfErrorInfoDicts];
	NSMutableArray *fileInfoDicts = [NSMutableArray arrayWithCapacity:count];
    
    for (i = 0; i < count; i++) {
        info = [self objectInErrorInfoDictsAtIndex:i];
        if ([[info objectForKey:@"select"] boolValue] == YES) {
            if (options & BDSKInitialAutoFileOptionMask) {
                [fileInfoDicts addObject:[info objectForKey:@"paper"]];
            } else {
                [fileInfoDicts addObject:info];
            }
        }
    }
    
    BibDocument *doc = [[document retain] autorelease];
    NSString *field = [[fieldName retain] autorelease];
    int mask = (options & BDSKInitialAutoFileOptionMask);
    mask |= (force == 1) ? BDSKForceAutoFileOptionMask : (options & BDSKCheckCompleteAutoFileOptionMask);
    
    [window close];
    
    if([fileInfoDicts count] != 0){
        [self movePapers:fileInfoDicts forField:field fromDocument:doc options:mask];
    }
}

- (IBAction)dump:(id)sender{
    NSMutableString *string = [NSMutableString string];
	NSDictionary *info = nil;
    int i, count = [self countOfErrorInfoDicts];
    
    for (i = 0; i < count; i++) {
        info = [self objectInErrorInfoDictsAtIndex:i];
        [string appendStrings:NSLocalizedString(@"Publication key: ", @""),
                              [[info objectForKey:@"paper"] citeKey], @"\n", 
                              NSLocalizedString(@"Original path: ", @""),
                              [info objectForKey:@"oldPath"], @"\n", 
                              NSLocalizedString(@"New path: ", @""),
                              [info objectForKey:@"newPath"], @"\n", 
                              NSLocalizedString(@"Status: ",@""),
                              [info objectForKey:@"status"], @"\n", 
                              NSLocalizedString(@"Fix: ", @""),
                              (([info objectForKey:@"fix"] == nil) ? NSLocalizedString(@"Cannot fix.", @"") : [info objectForKey:@"fix"]),
                              @"\n\n", nil];
    }
    
    NSString *fileName = NSLocalizedString(@"BibDesk AutoFile Errors",@"Filename for dumped autofile errors.");
    NSString *path = [[NSFileManager defaultManager] desktopPathForCurrentUser];
    if (path == nil)
        return;
    path = [[[NSFileManager defaultManager] uniqueFilePath:[path stringByAppendingPathComponent:fileName] createDirectory:NO] stringByAppendingPathExtension:@"txt"];
    
    [string writeToFile:path atomically:YES];
}

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo{
	errorString = [[errorInfo objectForKey:@"Error"] retain];
	return NO;
}

#pragma mark Accessors

- (NSArray *)errorInfoDicts {
    return errorInfoDicts;
}

- (unsigned)countOfErrorInfoDicts {
    return [errorInfoDicts count];
}

- (id)objectInErrorInfoDictsAtIndex:(unsigned)index {
    return [errorInfoDicts objectAtIndex:index];
}

- (void)insertObject:(id)obj inErrorInfoDictsAtIndex:(unsigned)index {
    [errorInfoDicts insertObject:obj atIndex:index];
}

- (void)removeObjectFromErrorInfoDictsAtIndex:(unsigned)index {
    [errorInfoDicts removeObjectAtIndex:index];
}

#pragma mark table view stuff

- (NSString *)tableView:(NSTableView *)tableView toolTipForTableColumn:(NSTableColumn *)tableColumn row:(int)row{
	NSString *tcid = [tableColumn identifier];
    if ([tcid isEqualToString:@"select"]) {
        return NSLocalizedString(@"Select items to Try Again or to Force.", @"");
    }
    return [[self objectInErrorInfoDictsAtIndex:row] objectForKey:tcid];
}

- (IBAction)showFile:(id)sender{
	int column = [tv clickedColumn];
	NSString *tcid;
	NSDictionary *dict = [self objectInErrorInfoDictsAtIndex:[tv clickedRow]];
	NSString *path;
	int statusFlag = [[dict objectForKey:@"flag"] intValue];

	if(column == -1)
		return;
	
	tcid = [[[tv tableColumns] objectAtIndex:column] identifier];
	if([tcid isEqualToString:@"oldPath"] || [tcid isEqualToString:@"icon"]){
		if(statusFlag & BDSKOldFileDoesNotExistMask)
			return;
		path = [[dict objectForKey:@"oldPath"] stringByExpandingTildeInPath];
		[[NSWorkspace sharedWorkspace]  selectFile:path inFileViewerRootedAtPath:nil];
	}else if([tcid isEqualToString:@"newPath"]){
		if(!(statusFlag & BDSKGeneratedFileExistsMask))
			return;
		path = [[dict objectForKey:@"newPath"] stringByExpandingTildeInPath];
		[[NSWorkspace sharedWorkspace]  selectFile:path inFileViewerRootedAtPath:nil];
	}else if([tcid isEqualToString:@"status"]){
		BibItem *pub = [dict objectForKey:@"paper"];
		[[pub document] editPub:pub];
	}
}

@end
