//
//  BibFiler.m
//  Bibdesk
//
//  Created by Michael McCracken on Fri Apr 30 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "BibFiler.h"
#import "NSImage+Toolbox.h"

static BibFiler *_sharedFiler = nil;

@implementation BibFiler

+ (BibFiler *)sharedFiler{
	if(!_sharedFiler){
		_sharedFiler = [[BibFiler alloc] init];
	}
	return _sharedFiler;
}

- (id)init{
	if(self = [super init]){
		_fileInfoDicts = [[NSMutableArray arrayWithCapacity:10] retain];
		
	}
	return self;
}

- (void)dealloc{
	[_fileInfoDicts release];
	[super dealloc];
}

#pragma mark Auto file methods

- (void)filePapers:(NSArray *)papers fromDocument:(BibDocument *)doc ask:(BOOL)ask{
	NSString *papersFolderPath = [[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:BDSKPapersFolderPathKey];
	BOOL isDir;
	BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:papersFolderPath isDirectory:&isDir];
	int rv;
	BOOL moveAll = YES;

	if(!(fileExists && isDir)){
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
			moveAll = NO;
		}else if(rv == NSAlertAlternateReturn){
			return;
		}
	}
	
	NSString *path = nil;
	NSString *newPath = nil;
	
	[self prepareMoveForDocument:doc];
	
	foreach(paper , papers){
		path = [paper localURLPathRelativeTo:[[(NSDocument *)doc fileName] stringByDeletingLastPathComponent]];
		newPath = [paper suggestedLocalUrl];
	
		[self movePath:path toPath:newPath forPaper:paper fromDocument:doc moveAll:moveAll];
	}
	
	[self finishMoveForDocument:doc];
}

- (void)movePath:(NSString *)path toPath:(NSString *)newPath forPaper:(BibItem *)paper fromDocument:(BibDocument *)doc moveAll:(BOOL)moveAll{
	NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:[path stringByAbbreviatingWithTildeInPath], @"oloc", 
			[newPath stringByAbbreviatingWithTildeInPath], @"nloc", nil];
	NSString *status = nil;
	int statusFlag = BDSKNoErrorMask;
	NSFileManager *fm = [NSFileManager defaultManager];
	
	if(path == nil || [path isEqualToString:@""] || newPath == nil || [newPath isEqualToString:@""] || [path isEqualToString:newPath])
		return;
	
	if(moveAll || [paper canSetLocalUrl]){
		if([fm fileExistsAtPath:newPath]){
			statusFlag = statusFlag | BDSKGeneratedFileExistsMask;
			if([fm fileExistsAtPath:path]){
				status = NSLocalizedString(@"A file already exists at the generated location.",@"");
			}else{
				status = NSLocalizedString(@"The linked file does not exists, while a file already exists at the generated location.", @"");
				statusFlag = statusFlag | BDSKOldFileDoesNotExistMask;
			}
		}else{
			if([fm fileExistsAtPath:path]){
				[fm createPathToFile:newPath attributes:nil]; // create parent directories if necessary (OmniFoundation)
				if([fm movePath:path toPath:newPath handler:self]){
					[paper setField:@"Local-Url" toValue:[[NSURL fileURLWithPath:newPath] absoluteString]];
					//status = NSLocalizedString(@"Successfully moved.",@"");
					
					NSUndoManager *undoManager = [doc undoManager];
					[[undoManager prepareWithInvocationTarget:self] 
						movePath:newPath toPath:path forPaper:paper fromDocument:doc moveAll:YES];
					_moveCount++;
				}else{
					status = [_errorString autorelease];
					statusFlag = statusFlag | BDSKMoveErrorMask;
				}
			}else{
				status = NSLocalizedString(@"The linked file does not exist.", @"");
				statusFlag = statusFlag | BDSKOldFileDoesNotExistMask;
			}
		}
	}else{
		status = NSLocalizedString(@"Incomplete information to generate the file name.",@"");
		statusFlag = statusFlag | BDSKIncompleteFieldsMask;
	}
	_movableCount++;
	
	if(statusFlag != BDSKNoErrorMask){
		[info setObject:status forKey:@"status"];
		[info setObject:[NSNumber numberWithInt:statusFlag] forKey:@"flag"];
		[_fileInfoDicts addObject:info];
	}
}

- (void)prepareMoveForDocument:(BibDocument *)doc{
	NSUndoManager *undoManager = [doc undoManager];
	[[undoManager prepareWithInvocationTarget:self] finishMoveForDocument:doc];
	
	_moveCount = 0;
	_movableCount = 0;
	_deletedCount = 0;
	_cleanupChangeCount = 0;
	[_fileInfoDicts removeAllObjects];
}

- (void)finishMoveForDocument:(BibDocument *)doc{
	NSUndoManager *undoManager = [doc undoManager];
	[[undoManager prepareWithInvocationTarget:self] prepareMoveForDocument:doc];
	
	if(_moveCount < _movableCount){
		[self showProblems];
	}
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
	[iconView setImage:[NSImage imageWithLargeIconForToolboxCode:kAlertNoteIcon]];
	[tv setDoubleAction:@selector(showFile:)];
	[tv setTarget:self];
	[window makeKeyAndOrderFront:self];
}

- (IBAction)done:(id)sender{
	[self doCleanup];
}

- (void)doCleanup{
	_currentPapers = nil;
	_currentDocument = nil;
	[window close];
}

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo{
	_errorString = [[errorInfo objectForKey:@"Error"] retain];
	return NO;
}

#pragma mark table view stuff

- (int)numberOfRowsInTableView:(NSTableView *)tableView{
	return [_fileInfoDicts count]; 
}

- (id)tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
			row:(int)row{
	NSString *tcid = [tableColumn identifier];
	NSDictionary *dict = [_fileInfoDicts objectAtIndex:row];
	
	if([tcid isEqualToString:@"oloc"]){
		return [dict objectForKey:@"oloc"];
	}else if([tcid isEqualToString:@"nloc"]){
		return [dict objectForKey:@"nloc"];
	}else if([tcid isEqualToString:@"status"]){
		return [dict objectForKey:@"status"];
	}else if([tcid isEqualToString:@"icon"]){
		NSString *path = [[dict objectForKey:@"oloc"] stringByExpandingTildeInPath];
		NSString *extension = [path pathExtension];
		if(path && [[NSFileManager defaultManager] fileExistsAtPath:path]){
				if(![extension isEqualToString:@""]){
						// use the NSImage method, as it seems to be faster, but only for files with extensions
						return [NSImage imageForFileType:extension];
				} else {
						return [[NSWorkspace sharedWorkspace] iconForFile:path];
				}
		}else{
				return nil;
		}
	}
	else return @"??";
}

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn 
			  row:(int)row{
	NSString *tcid = [tableColumn identifier];
	NSDictionary *dict = [_fileInfoDicts objectAtIndex:row];
	int statusFlag = [[dict objectForKey:@"flag"] intValue];
		
	if([tcid isEqualToString:@"oloc"]){
		if(statusFlag & BDSKOldFileDoesNotExistMask){
			[cell setTextColor:[NSColor grayColor]];
		}else{
			[cell setTextColor:[NSColor blackColor]];
		}
	}else if([tcid isEqualToString:@"nloc"]){
		if(statusFlag & BDSKGeneratedFileExistsMask){
			[cell setTextColor:[NSColor blackColor]];
		}else if(statusFlag & BDSKIncompleteFieldsMask){
			[cell setTextColor:[NSColor redColor]];
		}else{
			[cell setTextColor:[NSColor grayColor]];
		}
	}
}

- (IBAction)showFile:(id)sender{
	NSString *tcid;
	NSDictionary *dict = [_fileInfoDicts objectAtIndex:[tv clickedRow]];
	NSString *path;
	int statusFlag = [[dict objectForKey:@"flag"] intValue];

	if([tv clickedColumn] != -1){
		tcid = [[[tv tableColumns] objectAtIndex:[tv clickedColumn]] identifier];
	}else{
		tcid = @"";
	}

	if([tcid isEqualToString:@"oloc"] || [tcid isEqualToString:@"icon"]){
		if(statusFlag & BDSKOldFileDoesNotExistMask)
			return;
		path = [[dict objectForKey:@"oloc"] stringByExpandingTildeInPath];
		[[NSWorkspace sharedWorkspace]  selectFile:path inFileViewerRootedAtPath:nil];
	}else if([tcid isEqualToString:@"nloc"]){
		if(!(statusFlag & BDSKGeneratedFileExistsMask))
			return;
		path = [[dict objectForKey:@"nloc"] stringByExpandingTildeInPath];
		[[NSWorkspace sharedWorkspace]  selectFile:path inFileViewerRootedAtPath:nil];
	}else if([tcid isEqualToString:@"status"]){
		NSRunAlertPanel(nil,
						[dict objectForKey:@"status"],
						NSLocalizedString(@"OK",@"OK"),nil,nil);
	}
}

@end
