//
//  BDSKOrphanedFilesFinder.m
//  BibDesk
//
//  Created by Christiaan Hofman on 8/11/06.
/*
 This software is Copyright (c) 2005,2006
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

#import "BDSKOrphanedFilesFinder.h"
#import "BDSKPreferenceController.h"
#import "BibTypeManager.h"
#import "BibAppController.h"
#import "BibDocument.h"
#import "BibItem.h"
#import "NSString_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSImage+Toolbox.h"

@interface BDSKOrphanedFilesFinder (Private)
- (NSArray *)directoryContentsAtPath:(NSString *)path;
@end


@implementation BDSKOrphanedFilesFinder

static BDSKOrphanedFilesFinder *sharedFinder = nil;

+ (id)sharedFinder {
    if (sharedFinder == nil)
        sharedFinder = [[[self class] alloc] init];
    return sharedFinder;
}

- (id)init {
    if (self = [super init]) {
        orphanedFiles = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    [orphanedFiles release];
    [super dealloc];
}

- (void)awakeFromNib{
    [tableView setDoubleAction:@selector(showFile:)];
}

- (NSString *)windowNibName{
    return @"BDSKOrphanedFilesFinder";
}

- (IBAction)showOrphanedFiles:(id)sender{
    [self showWindow:sender];
    [self refreshOrphanedFiles:sender];
}

- (IBAction)refreshOrphanedFiles:(id)sender{
    [statusField setStringValue:[NSLocalizedString(@"Looking for orphaned files", @"") stringByAppendingEllipsis]];
    [statusField display];
    [progressIndicator startAnimation:sender];
    
    NSString *papersFolderPath = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKPapersFolderPathKey];
    
    if ([NSString isEmptyString:papersFolderPath]) {
        NSArray *documents = [[NSDocumentController sharedDocumentController] documents];
        if ([documents count] > 1) {
            [statusField setStringValue:NSLocalizedString(@"No papers folder", @"")];
            NSBeep();
            return;
        }
        papersFolderPath = [[NSApp delegate] folderPathForFilingPapersFromDocument:[documents objectAtIndex:1]];
    }
    
    NSMutableArray *allFiles = [[self directoryContentsAtPath:papersFolderPath] mutableCopy];
    
    NSSet *localFileFields = [[BibTypeManager sharedManager] localFileFieldsSet];
    NSEnumerator *docEnum = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
    BibDocument *doc;
    NSEnumerator *pubEnum;
    BibItem *pub;
    NSEnumerator *fieldEnum;
    NSString *field;
    NSString *path;

    while (doc = [docEnum nextObject]) {
        pubEnum = [[doc publications] objectEnumerator];
        while (pub = [pubEnum nextObject]) {
            fieldEnum = [localFileFields objectEnumerator];
            while (field = [fieldEnum nextObject]) {
                path = [pub localFilePathForField:field];
                if ([NSString isEmptyString:path] == NO)
                    [allFiles removeObject:path];
            }
        }
    }
    
    [[self mutableArrayValueForKey:@"orphanedFiles"] setArray:allFiles];
    
    int numberOfFiles = [allFiles count];
    NSString *statusMessage = (numberOfFiles == 1) ? NSLocalizedString(@"Found 1 orphaned files", @"") : [NSString stringWithFormat:NSLocalizedString(@"Found %i orphaned files", @""), numberOfFiles];
    [progressIndicator stopAnimation:sender];
    [statusField setStringValue:statusMessage];
    
    [allFiles release];
}

#pragma mark Accessors
 
- (NSArray *)orphanedFiles {
    return [[orphanedFiles retain] autorelease];
}

- (unsigned)countOfOrphanedFiles {
    return [orphanedFiles count];
}

- (id)objectInOrphanedFilesAtIndex:(unsigned)theIndex {
    return [orphanedFiles objectAtIndex:theIndex];
}

- (void)insertObject:(id)obj inOrphanedFilesAtIndex:(unsigned)theIndex {
    [orphanedFiles insertObject:obj atIndex:theIndex];
}

- (void)removeObjectFromOrphanedFilesAtIndex:(unsigned)theIndex {
    [orphanedFiles removeObjectAtIndex:theIndex];
}

#pragma mark TableView stuff

// dummy dataSource implementation
- (int)numberOfRowsInTableView:(NSTableView *)tView{ return 0; }
- (id)tableView:(NSTableView *)tView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row{ return nil; }

- (NSString *)tableView:(NSTableView *)tableView toolTipForTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    return [self objectInOrphanedFilesAtIndex:row];
}

- (NSMenu *)tableView:(NSTableView *)tableView contextMenuForRow:(int)row column:(int)column{
    return contextMenu;
}

- (IBAction)showFile:(id)sender{
    int row = [tableView selectedRow];
    if (row == -1)
        return;
    
    int type = -1;
    NSString *path = [self objectInOrphanedFilesAtIndex:row];
    
    if(sender == tableView){
        int column = [tableView clickedColumn];
        if(column == -1)
            return;
        type = 0;
    }else if([sender isKindOfClass:[NSMenuItem class]]){
        type = [sender tag];
    }
    
    if(type == 1){
        [[NSWorkspace sharedWorkspace] openFile:path];
    }else{
        [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil];
    }
}   

// for 10.3 compatibility and OmniAppKit dataSource methods
- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard{
	NSMutableIndexSet *rowIndexes = [NSMutableIndexSet indexSet];
	NSEnumerator *rowEnum = [rows objectEnumerator];
	NSNumber *row;
	
	while (row = [rowEnum nextObject]) 
		[rowIndexes addIndex:[row intValue]];
	
	return [self tableView:tv writeRowsWithIndexes:rowIndexes toPasteboard:pboard];
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard{
    unsigned row = [rowIndexes firstIndex];
    NSArray *filePaths = [[self mutableArrayValueForKey:@"orphanedFiles"] objectsAtIndexes:rowIndexes];
    [pboard declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil] owner:nil];
    [pboard setPropertyList:filePaths forType:NSFilenamesPboardType];
    return YES;
}

@end


@implementation BDSKOrphanedFilesFinder (Private)

- (NSArray *)directoryContentsAtPath:(NSString *)path{
	NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:path];
	NSString *file, *fileType, *filePath;
	NSNumber *fileCode;
	NSArray *content;
	NSMutableArray *fileArray = [NSMutableArray array];
    
    NSDictionary *fileAttributes;
    
    // avoid recursing too many times (and creating an excessive number of submenus)
	while (file = [dirEnum nextObject]) {
        fileAttributes = [dirEnum fileAttributes];
		fileType = [fileAttributes valueForKey:NSFileType];
		filePath = [path stringByAppendingPathComponent:file];
        
		if ([file hasPrefix:@"."]) {
			[dirEnum skipDescendents];
		} else if ([fileType isEqualToString:NSFileTypeDirectory]) {
			[dirEnum skipDescendents];
			[fileArray addObjectsFromArray:[self directoryContentsAtPath:filePath]];
		} else {
			[fileArray addObject:filePath];
		}
	}
	return fileArray;
}

@end

@implementation BDSKDragImageTableView

// @@ legacy implementation for 10.3 compatibility
- (NSImage *)dragImageForRows:(NSArray *)dragRows event:(NSEvent *)dragEvent dragImageOffset:(NSPointPointer)dragImageOffset{
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    NSNumber *number;
    NSEnumerator *rowE = [dragRows objectEnumerator];
    while(number = [rowE nextObject])
        [indexes addIndex:[number intValue]];
    
    NSPoint zeroPoint = NSMakePoint(0,0);
	return [self dragImageForRowsWithIndexes:indexes tableColumns:[self tableColumns] event:dragEvent offset:&zeroPoint];
}

- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent*)dragEvent offset:(NSPointPointer)dragImageOffset{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    NSString *dragType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
    NSImage *image = nil;
    
    if ([dragType isEqualToString:NSFilenamesPboardType]) {
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		int count = [fileNames count];
        NSString *filePath = count ? [[pboard propertyListForType:NSFilenamesPboardType] objectAtIndex:0] : nil;
		image = [NSImage imageForFile:filePath];
        
        NSImage *dragImage = [[NSImage alloc] initWithSize:[image size]];
        
        [dragImage lockFocus];
        [image compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:0.7];
        [dragImage unlockFocus];
        
        image = [dragImage autorelease];
    } else {
        image = [super dragImageForRowsWithIndexes:dragRows tableColumns:tableColumns event:dragEvent offset:dragImageOffset];
    }
    
    return image;
}

@end
