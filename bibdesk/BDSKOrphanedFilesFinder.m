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
#import "BibPrefController.h"
#import "BibTypeManager.h"
#import "BibAppController.h"
#import "BibDocument.h"
#import "BibItem.h"
#import "NSString_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSImage+Toolbox.h"
#import "NSBezierPath_BDSKExtensions.h"
#import "BDSKAlert.h"

@interface BDSKOrphanedFilesFinder (Private)
- (void)findAlertDidEnd:(BDSKAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)refreshOrphanedFilesInPapersFolder:(NSString *)papersFolderPath;
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
        wasLaunched = NO;
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

- (IBAction)toggleShowingOrphanedFilesPanel:(id)sender{
    if([[self window] isVisible]){
		[self hideOrphanedFilesPanel:sender];
    }else{
		[self showOrphanedFilesPanel:sender];
    }
}

- (IBAction)showOrphanedFilesPanel:(id)sender{
    if (wasLaunched) {
        [self showWindow:sender];
    } else {
        wasLaunched = YES;
        [self showOrphanedFiles:sender];
    }
}

- (IBAction)hideOrphanedFilesPanel:(id)sender{
	[[self window] close];
}

- (IBAction)showOrphanedFiles:(id)sender{
    [self showWindow:sender];
    [self performSelector:@selector(refreshOrphanedFiles:) withObject:sender afterDelay:0.0];
}

- (IBAction)refreshOrphanedFiles:(id)sender{
    NSString *papersFolderPath = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKPapersFolderPathKey];
    
    if ([NSString isEmptyString:papersFolderPath]) {
        NSArray *documents = [[NSDocumentController sharedDocumentController] documents];
        if ([documents count] > 1) {
            [statusField setStringValue:NSLocalizedString(@"No papers folder", @"")];
            NSBeep();
            return;
        }
        papersFolderPath = [[NSApp delegate] folderPathForFilingPapersFromDocument:[documents objectAtIndex:0]];
    }
    
    if ([NSHomeDirectory() isEqualToString:papersFolderPath]) {
        BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Find Orphined Files", @"")
                                             defaultButton:NSLocalizedString(@"Find", @"Find")
                                           alternateButton:NSLocalizedString(@"Don't Find", @"Don't Find")
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"You have chosen your Home Folder as your Papers Folder. Finding all orphined files in this folder could take a long time. Do you want to proceed?",@"")];
        // we use the didDismissSelector because we want to alert to be gone before we start a long process
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:self
                         didEndSelector:NULL
                     didDismissSelector:@selector(findAlertDidEnd:returnCode:contextInfo:)
                            contextInfo:[papersFolderPath retain]];
    } else {
        [self refreshOrphanedFilesInPapersFolder:papersFolderPath];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem{
	SEL act = [menuItem action];

    if (act == @selector(toggleShowingOrphanedFilesPanel:)){ 
		// menu item for toggling the orphaned files panel
		// set the on/off state according to the panel's visibility
		if ([[self window] isVisible]) {
			[menuItem setState:NSOnState];
		}else {
			[menuItem setState:NSOffState];
		}
	}
    return YES;
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
    NSIndexSet *rowIndexes = [tableView selectedRowIndexes];
    if ([rowIndexes count] == 0)
        return;
    
    int type = -1;
    
    if(sender == tableView){
        if([tableView clickedColumn] == -1)
            return;
        type = 0;
    }else if([sender isKindOfClass:[NSMenuItem class]]){
        type = [sender tag];
    }
    
    NSString *path;
    unsigned int index = [rowIndexes firstIndex];
    
    while (index != NSNotFound) {
        path = [self objectInOrphanedFilesAtIndex:index];
        if(type == 1)
            [[NSWorkspace sharedWorkspace] openFile:path];
        else
            [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil];
        index = [rowIndexes indexGreaterThanIndex:index];
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
    NSArray *filePaths = [[self mutableArrayValueForKey:@"orphanedFiles"] objectsAtIndexes:rowIndexes];
    [pboard declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil] owner:nil];
    [pboard setPropertyList:filePaths forType:NSFilenamesPboardType];
    return YES;
}

@end


@implementation BDSKOrphanedFilesFinder (Private)

- (void)findAlertDidEnd:(BDSKAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    NSString *papersFolderPath = (NSString *)contextInfo;
    if (returnCode == NSAlertDefaultReturn)
        [self refreshOrphanedFilesInPapersFolder:papersFolderPath];
    [papersFolderPath release];
}

- (void)refreshOrphanedFilesInPapersFolder:(NSString *)papersFolderPath{
    NSMutableArray *allFiles = [[NSMutableArray alloc] init];
	NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:papersFolderPath];
	NSString *file, *filePath;
    BOOL isDir;
    NSDictionary *fileAttributes;
    
    [statusField setStringValue:[NSLocalizedString(@"Looking for orphaned files", @"") stringByAppendingEllipsis]];
    [statusField display];
    [progressIndicator startAnimation:self];
    
	while (file = [dirEnum nextObject]) {
        fileAttributes = [dirEnum fileAttributes];
		isDir = [[fileAttributes valueForKey:NSFileType] isEqualToString:NSFileTypeDirectory];
		filePath = [papersFolderPath stringByAppendingPathComponent:file];
        // resolve aliases in the containing dir, because that is the form localFilePathForField returns
        filePath = [[[NSURL fileURLWithPath:filePath] fileURLByResolvingAliasesBeforeLastPathComponent] path];
        
		if ([[file lastPathComponent] hasPrefix:@"."]) {
            if (isDir) 
                [dirEnum skipDescendents];
		} else if (isDir == NO) {
			[allFiles addObject:filePath];
		}
	}
    
    NSSet *localFileFields = [[BibTypeManager sharedManager] localFileFieldsSet];
    NSEnumerator *docEnum = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
    BibDocument *doc;
    NSEnumerator *pubEnum;
    BibItem *pub;
    NSEnumerator *fieldEnum;
    NSString *field;
    NSString *path;

    while (doc = [docEnum nextObject]) {
        path = [doc fileName];
        if ([NSString isEmptyString:path] == NO)
            [allFiles removeObject:path];
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
    NSString *statusMessage = (numberOfFiles == 1) ? NSLocalizedString(@"Found 1 orphaned file", @"") : [NSString stringWithFormat:NSLocalizedString(@"Found %i orphaned files", @""), numberOfFiles];
    [progressIndicator stopAnimation:self];
    [statusField setStringValue:statusMessage];
    
    [allFiles release];
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
    int count = 0;
    
    if ([dragType isEqualToString:NSFilenamesPboardType]) {
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
        count = [fileNames count];
        NSString *filePath = count ? [[pboard propertyListForType:NSFilenamesPboardType] objectAtIndex:0] : nil;
		if (filePath)
            image = [NSImage imageForFile:filePath];
    }
    
    if (image == nil)
        return [super dragImageForRowsWithIndexes:dragRows tableColumns:tableColumns event:dragEvent offset:dragImageOffset];
    
	if (count > 1) {
		NSAttributedString *countString = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%i", count]
											attributeName:NSForegroundColorAttributeName attributeValue:[NSColor whiteColor]] autorelease];
		NSSize size = [image size];
		NSRect rect = {NSZeroPoint, size};
		NSRect iconRect = rect;
		NSRect countRect = {NSZeroPoint, [countString size]};
		float countOffset;
		
		countOffset = floorf(0.5f * NSHeight(countRect)); // make sure the cap radius is integral
		countRect.size.height = 2.0 * countOffset;
        countRect.origin = NSMakePoint(NSMaxX(rect), 0.0);
        size.width += NSWidth(countRect) + countOffset;
        size.height += countOffset;
        rect.origin.y += countOffset;
		
		NSImage *labeledImage = [[[NSImage alloc] initWithSize:size] autorelease];
		
		[labeledImage lockFocus];
		
		[image drawInRect:rect fromRect:iconRect operation:NSCompositeCopy fraction:1.0];
		
        [NSGraphicsContext saveGraphicsState];
		// draw a count of the rows being dragged, similar to Mail.app
		[[NSColor redColor] setFill];
		[NSBezierPath fillHorizontalOvalAroundRect:countRect];
		[countString drawInRect:countRect];
		[NSGraphicsContext restoreGraphicsState];
        
		[labeledImage unlockFocus];
		
		image = labeledImage;
    }
    
    NSImage *dragImage = [[NSImage alloc] initWithSize:[image size]];
    
    [dragImage lockFocus];
    [image compositeToPoint:NSZeroPoint operation:NSCompositeCopy fraction:0.7];
    [dragImage unlockFocus];
        
    
    return [dragImage autorelease];
}

@end
