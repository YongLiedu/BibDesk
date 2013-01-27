//
//  BDSKOrphanedFilesFinder.m
//  BibDesk
//
//  Created by Christiaan Hofman on 8/11/06.
/*
 This software is Copyright (c) 2005-2013
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
#import "BDSKStringConstants.h"
#import "BDSKTypeManager.h"
#import "BDSKAppController.h"
#import "BibDocument.h"
#import "BibItem.h"
#import "NSString_BDSKExtensions.h"
#import "NSURL_BDSKExtensions.h"
#import "NSImage_BDSKExtensions.h"
#import "NSBezierPath_BDSKExtensions.h"
#import "NSTableView_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKFileMatcher.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKLinkedFile.h"
#import "BDSKTableView.h"
#import "NSMenu_BDSKExtensions.h"
#import "NSPasteboard_BDSKExtensions.h"
#import "NSFileManager_BDSKExtensions.h"
#import <libkern/OSAtomic.h>

#define BDSKOrphanedFilesWindowFrameAutosaveName @"BDSKOrphanedFilesWindow"

@interface BDSKOrphanedFilesFinder (Private)
- (void)refreshOrphanedFiles;
- (void)findAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)restartChecking;
- (void)startAnimationWithStatusMessage:(NSString *)message;
- (void)stopAnimationWithStatusMessage:(NSString *)message;
- (void)checkForOrphansWithKnownFiles:(NSSet *)theFiles baseURL:(NSURL *)theURL;
- (void)flushFoundFiles;
- (void)clearFoundFiles;
- (BOOL)allFilesEnumerated;
- (void)stopEnumerating;
@end

@implementation BDSKOrphanedFilesFinder

static BDSKOrphanedFilesFinder *sharedFinder = nil;

+ (id)sharedFinder {
    if (sharedFinder == nil)
        sharedFinder = [[self alloc] init];
    return sharedFinder;
}

- (id)init {
    BDSKPRECONDITION(sharedFinder == nil);
    self = [super init];
    if (self) {
        orphanedFiles = [[NSMutableArray alloc] init];
        wasLaunched = NO;
        foundFiles = [[NSMutableArray alloc] initWithCapacity:32];
        keepEnumerating = 0;
        allFilesEnumerated = 0;
    }
    return self;
}

- (void)windowDidLoad{
    [self setWindowFrameAutosaveName:BDSKOrphanedFilesWindowFrameAutosaveName];
    [tableView setDoubleAction:@selector(showFile:)];
    [tableView setFontNamePreferenceKey:BDSKOrphanedFilesTableViewFontNameKey];
    [tableView setFontSizePreferenceKey:BDSKOrphanedFilesTableViewFontSizeKey];
    [tableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [tableView setDraggingSourceOperationMask:NSDragOperationCopy | NSDragOperationDelete forLocal:NO];
    [progressIndicator setUsesThreadedAnimation:YES];
}

- (NSString *)windowNibName{
    return @"BDSKOrphanedFilesFinder";
}

- (IBAction)showWindow:(id)sender{
    [super showWindow:sender];
    if (wasLaunched == NO) {
        wasLaunched = YES;
        [self refreshOrphanedFiles:sender];
    }
}

- (void)windowWillClose:(NSNotification *)aNotification{
    [self stopRefreshing:nil];
}

- (IBAction)showOrphanedFiles:(id)sender{
    [super showWindow:sender];
    [self refreshOrphanedFiles:nil];
    wasLaunched = YES;
}

- (IBAction)matchFilesWithPubs:(id)sender;
{
    [self close];
    [(BDSKFileMatcher *)[BDSKFileMatcher sharedInstance] matchFiles:[self orphanedFiles] withPublications:nil];
}

- (NSURL *)baseURL
{
    NSString *papersFolderPath = [[NSUserDefaults standardUserDefaults] objectForKey:BDSKPapersFolderPathKey];
    
    // old prefs may not have a standarized path
    papersFolderPath = [papersFolderPath stringByStandardizingPath];
    
    if ([NSString isEmptyString:papersFolderPath]) {
        NSArray *documents = [[NSDocumentController sharedDocumentController] documents];
        if ([documents count] == 1) {
            papersFolderPath = [BDSKFormatParser folderPathForFilingPapersFromDocumentAtPath:[[[documents objectAtIndex:0] fileURL] path]];
        } else {
            return nil;
        }
    }
    
    papersFolderPath = [[NSFileManager defaultManager] resolveAliasesInPath:papersFolderPath];
    
    return [NSURL fileURLWithPath:papersFolderPath];
}

- (NSSet *)knownFiles
{
    NSMutableSet *knownFiles = [NSMutableSet set];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *fileURL;
    
    for (BibDocument *doc in [[NSDocumentController sharedDocumentController] documents]) {
        fileURL = [doc fileURL];
        if ([fm fileExistsAtPath:[fileURL path]])
            [knownFiles addObject:fileURL];
        for (BibItem *pub in [doc publications]) {
            for (BDSKLinkedFile *file in [pub localFiles]) {
                fileURL = [file URL];
                if ([fm fileExistsAtPath:[fileURL path]])
                    [knownFiles addObject:fileURL];
            }
        }
    }
    return knownFiles;
}

- (IBAction)refreshOrphanedFiles:(id)sender{
    
    NSString *papersFolderPath = [[self baseURL] path];
    
    if ([NSHomeDirectory() isEqualToString:papersFolderPath]) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Find Orphaned Files", @"Message in alert dialog when trying to find orphaned files in Home folder")
                                         defaultButton:NSLocalizedString(@"Find", @"Button title: find orphaned files")
                                       alternateButton:NSLocalizedString(@"Don't Find", @"Button title: don't find orphaned files")
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"You have chosen your Home Folder as your Papers Folder. Finding all orphaned files in this folder could take a long time. Do you want to proceed?", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:self
                         didEndSelector:@selector(findAlertDidEnd:returnCode:contextInfo:)
                            contextInfo:NULL];
    } else {
        [self refreshOrphanedFiles];
    }

}

- (IBAction)stopRefreshing:(id)sender{
    [self stopEnumerating];
}

- (IBAction)search:(id)sender{
    [arrayController setSearchString:[sender stringValue]];
    [arrayController rearrangeObjects];
    NSUInteger count = [[arrayController arrangedObjects] count];
    NSString *message = count == 1 ? [NSString stringWithFormat:NSLocalizedString(@"%ld orphaned file found", @"Status message"), (long)count] : [NSString stringWithFormat:NSLocalizedString(@"%ld orphaned files found", @"Status message"), (long)count];
    [statusField setStringValue:message];
}    

#pragma mark Accessors
 
- (NSArray *)orphanedFiles {
    return [[orphanedFiles copy] autorelease];
}

- (NSUInteger)countOfOrphanedFiles {
    return [orphanedFiles count];
}

- (id)objectInOrphanedFilesAtIndex:(NSUInteger)theIndex {
    return [orphanedFiles objectAtIndex:theIndex];
}

- (void)insertObject:(id)obj inOrphanedFilesAtIndex:(NSUInteger)theIndex {
    [orphanedFiles insertObject:obj atIndex:theIndex];
}

- (void)removeObjectFromOrphanedFilesAtIndex:(NSUInteger)theIndex {
    [orphanedFiles removeObjectAtIndex:theIndex];
}

- (BOOL)wasLaunched {
    return wasLaunched;
}

#pragma mark TableView stuff

// dummy dataSource implementation
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tView{ return 0; }
- (id)tableView:(NSTableView *)tView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{ return nil; }

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation{
    return [[[arrayController arrangedObjects] objectAtIndex:row] path];
}

- (IBAction)showFile:(id)sender{
    NSInteger row = [tableView clickedRow];
    if (row == -1)
        return;
    
    NSIndexSet *rowIndexes = [tableView selectedRowIndexes];
    if ([rowIndexes containsIndex:row] == NO)
        rowIndexes = [NSIndexSet indexSetWithIndex:row];
    
    NSArray *paths = [[[arrayController arrangedObjects] objectsAtIndexes:rowIndexes] valueForKey:@"path"];
    NSInteger type = ([sender isKindOfClass:[NSMenuItem class]]) ? [sender tag] : 0;
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    
    for (NSString *path in paths) {
        if(type == 1)
            [ws openLinkedURL:[NSURL fileURLWithPath:path]];
        else
            [ws selectFile:path inFileViewerRootedAtPath:nil];
    }
}   

- (void)trashAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    NSArray *files = [(NSArray *)contextInfo autorelease];
    if (returnCode == NSAlertDefaultReturn) {
        [[self mutableArrayValueForKey:@"orphanedFiles"] removeObjectsInArray:files];
        for (NSString *path in [files valueForKey:@"path"]) {
            NSString *folderPath = [path stringByDeletingLastPathComponent];
            NSString *fileName = [path lastPathComponent];
            NSInteger tag = 0;
            [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:folderPath destination:nil files:[NSArray arrayWithObjects:fileName, nil] tag:&tag];
        }
    }
}

- (IBAction)moveToTrash:(id)sender{
    NSInteger row = [tableView clickedRow];
    if (row == -1)
        return;
    
    NSIndexSet *rowIndexes = [tableView selectedRowIndexes];
    if ([rowIndexes containsIndex:row] == NO)
        rowIndexes = [NSIndexSet indexSetWithIndex:row];
    
    NSArray *files = [[arrayController arrangedObjects] objectsAtIndexes:rowIndexes];
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Move Files to Trash?", @"Message in alert dialog when deleting a file")
                                     defaultButton:NSLocalizedString(@"Yes", @"Button title")
                                   alternateButton:NSLocalizedString(@"No", @"Button title")
                                       otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"Do you want to move the removed files to the trash?", @"Informative text in alert dialog")];
    [alert beginSheetModalForWindow:[self window]
                      modalDelegate:self 
                     didEndSelector:@selector(trashAlertDidEnd:returnCode:contextInfo:)  
                        contextInfo:[files retain]];
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard{
    [draggedFiles release];
    draggedFiles = [[[arrayController arrangedObjects] objectsAtIndexes:rowIndexes] retain];
    [pboard clearContents];
    [pboard writeObjects:[draggedFiles valueForKey:@"fileURL"]];
    return YES;
}

- (void)tableView:(NSTableView *)tv concludeDragOperation:(NSDragOperation)operation{
    if (operation == NSDragOperationDelete && [draggedFiles count]) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Move Files to Trash?", @"Message in alert dialog when deleting a file")
                                         defaultButton:NSLocalizedString(@"Yes", @"Button title")
                                       alternateButton:NSLocalizedString(@"No", @"Button title")
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"Do you want to move the removed files to the trash?", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:self 
                         didEndSelector:@selector(trashAlertDidEnd:returnCode:contextInfo:)  
                            contextInfo:[draggedFiles retain]];
    }
    [draggedFiles release];
    draggedFiles = nil;
}

- (NSImage *)tableView:(NSTableView *)aTableView dragImageForRowsWithIndexes:(NSIndexSet *)dragRows{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    NSArray *fileURLs = [pboard readFileURLsOfTypes:nil];
    NSImage *image = nil;
    
    if ([fileURLs count] > 0)
        image = [[NSWorkspace sharedWorkspace] iconForFiles:[fileURLs valueForKey:@"path"]];
    
    return [image dragImageWithCount:[fileURLs count]];
}

#pragma mark Contextual menu

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];
    if (menu == [tableView menu] && [tableView clickedRow] != -1)
        [menu addItemsFromMenu:contextMenu];
}

@end


@implementation BDSKOrphanedFilesFinder (Private)

- (void)findAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo{
    if (returnCode == NSAlertDefaultReturn)
        [self refreshOrphanedFiles];
}

- (void)refreshOrphanedFiles{
    [self startAnimationWithStatusMessage:[NSLocalizedString(@"Looking for orphaned files", @"Status message") stringByAppendingEllipsis]];
    // do the actual work with a zero delay to let the UI update 
    [self performSelector:@selector(restartChecking) withObject:nil afterDelay:0.0];
}

- (void)restartChecking{
    [[self mutableArrayValueForKey:@"orphanedFiles"] removeAllObjects];
    
    NSURL *baseURL = [self baseURL];
    
    if(baseURL){
        if(queue == NULL)
            queue = dispatch_queue_create("edu.ucsd.cs.mmccrack.bibdesk.queue.BDSKOrphanedFilesFinder", NULL);
        
        NSSet *knownFiles = [self knownFiles];
        dispatch_async(queue, ^{
            [self checkForOrphansWithKnownFiles:knownFiles baseURL:baseURL];
        });
        
    } else {
        NSBeep();
        [self stopAnimationWithStatusMessage:NSLocalizedString(@"Unknown papers folder.", @"Status message")];
    }
}

- (void)startAnimationWithStatusMessage:(NSString *)message{
    [progressIndicator startAnimation:nil];
    [refreshButton setTitle:NSLocalizedString(@"Stop", @"Button title")];
    [refreshButton setAction:@selector(stopRefreshing:)];
    [refreshButton setToolTip:NSLocalizedString(@"Stop looking for orphaned files", @"Tool tip message")];
    [statusField setStringValue:message];
}

- (void)stopAnimationWithStatusMessage:(NSString *)message{
    [progressIndicator stopAnimation:nil];
    [refreshButton setTitle:NSLocalizedString(@"Refresh", @"Button title")];
    [refreshButton setAction:@selector(refreshOrphanedFiles:)];
    [refreshButton setToolTip:NSLocalizedString(@"Refresh the list of orphaned files", @"Tool tip message")];
    [statusField setStringValue:message];
}

- (void)checkForOrphansWithKnownFiles:(NSSet *)theFiles baseURL:(NSURL *)theURL;
{
    // set the stop flag so enumeration ceases
    // CMH: is this necessary, shouldn't we already be done as we're on the same thread?
    OSAtomicCompareAndSwap32Barrier(1, 0, &keepEnumerating);
    
    [self clearFoundFiles];
    
    OSAtomicCompareAndSwap32Barrier(0, 1, &keepEnumerating);
    OSAtomicCompareAndSwap32Barrier(1, 0, &allFilesEnumerated);
    
    // increase file limit for enumerating a home directory http://developer.apple.com/qa/qa2001/qa1292.html
    struct rlimit limit;
    int err;
    
    err = getrlimit(RLIMIT_NOFILE, &limit);
    if (err == 0) {
        limit.rlim_cur = RLIM_INFINITY;
        (void) setrlimit(RLIMIT_NOFILE, &limit);
    }
        
    // run directory enumerator; if knownFiles doesn't contain object, add to foundFiles
    NSFileManager *fm = [[[NSFileManager alloc] init] autorelease];
    NSDirectoryEnumerator *dirEnum = [fm enumeratorAtURL:theURL includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLIsDirectoryKey, NSURLIsPackageKey, nil] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    
    for (NSURL *aURL in dirEnum) {
        OSMemoryBarrier();
        if (0 == keepEnumerating)
            break;
        
        if ([foundFiles count] >= 16)
            [self flushFoundFiles];
        
        NSNumber *isDir = nil;
        NSNumber *isPackage = nil;
        [aURL getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
        [aURL getResourceValue:&isPackage forKey:NSURLIsPackageKey error:NULL];
        
        if ((NO == [isDir boolValue] || [isPackage boolValue]) && [theFiles containsObject:aURL] == NO)
            [foundFiles addObject:aURL];
    }
    
    
    // see if we have some left in the cache
    [self flushFoundFiles];
    
    // keepEnumerating is 0 when enumeration was stopped
    OSMemoryBarrier();
    if (keepEnumerating == 1)
        OSAtomicCompareAndSwap32Barrier(0, 1, &allFilesEnumerated);
    
    // notify the delegate that we're done
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger count = [[arrayController arrangedObjects] count];
        NSString *message = count == 1 ? [NSString stringWithFormat:NSLocalizedString(@"%ld orphaned file found", @"Status message"), (long)count] : [NSString stringWithFormat:NSLocalizedString(@"%ld orphaned files found", @"Status message"), (long)count];
        if ([self allFilesEnumerated] == NO)
            message = [NSString stringWithFormat:@"%@. %@", NSLocalizedString(@"Stopped", @"Partial status message"), message];
        [self stopAnimationWithStatusMessage:message];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKOrphanedFilesFinderFinishedNotification object:self];
    });
}

- (void)flushFoundFiles;
{
    if([foundFiles count]){
        NSArray *newFiles = [[foundFiles copy] autorelease];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableArray *mutableArray = [self mutableArrayValueForKey:@"orphanedFiles"];
            [mutableArray addObjectsFromArray:newFiles];
            NSUInteger count = [[arrayController arrangedObjects] count];
            NSString *message = count == 1 ? [NSString stringWithFormat:NSLocalizedString(@"%ld orphaned file found", @"Status message"), (long)count] : [NSString stringWithFormat:NSLocalizedString(@"%ld orphaned files found", @"Status message"), (long)count];
            [statusField setStringValue:[message stringByAppendingEllipsis]];
        });
        [self clearFoundFiles];
    }
}

- (void)clearFoundFiles;
{
    [foundFiles removeAllObjects];
}

- (BOOL)allFilesEnumerated { OSMemoryBarrier(); return (BOOL)(1 == allFilesEnumerated); }

- (void)stopEnumerating { OSAtomicCompareAndSwap32Barrier(1, 0, &keepEnumerating); }

@end

#pragma mark -
#pragma mark Array controller subclass for searching

@interface NSURL (BDSKPathSearch)
- (BOOL)pathContainsSubstring:(NSString *)aString;
@end

@implementation NSURL (BDSKPathSearch)

// compare case-insensitive and non-literal
- (BOOL)pathContainsSubstring:(NSString *)aString;
{
    CFURLRef theURL = (CFURLRef)self;
    CFStringRef path = CFURLCopyFileSystemPath(theURL, kCFURLPOSIXPathStyle);
    BOOL found = NO;
    if(path){
        found = CFStringFindWithOptions(path, (CFStringRef)aString, CFRangeMake(0, CFStringGetLength(path)), kCFCompareNonliteral | kCFCompareCaseInsensitive, NULL);
        CFRelease(path);
    }
    return found;
}

@end

@implementation BDSKOrphanedFilesArrayController

- (void)updateTemplateMenu
{
    NSMenu *menu = [[[searchField cell] searchMenuTemplate] copyWithZone:[NSMenu menuZone]];
    [[menu itemAtIndex:0] setState:(showsMatches ? NSOnState : NSOffState)];
    [[menu itemAtIndex:1] setState:(showsMatches ? NSOffState : NSOnState)];
    [[searchField cell] setSearchMenuTemplate:menu];
    [menu release];
}

- (void)awakeFromNib
{
    showsMatches = YES;
    [self updateTemplateMenu];   
}

- (void)dealloc
{
    [self setSearchString:nil];
    [super dealloc];
}

- (void)setSearchString:(NSString *)aString;
{
    [searchString autorelease];
    searchString = [aString copy];
}

- (NSString *)searchString { return searchString; }

- (IBAction)showMatches:(id)sender;
{
    showsMatches = YES;
    [self updateTemplateMenu];
    [self rearrangeObjects];
}

- (IBAction)hideMatches:(id)sender;
{
    showsMatches = NO;
    [self updateTemplateMenu];
    [self rearrangeObjects];
}

- (NSArray *)arrangeObjects:(NSArray *)objects
{
    if([NSString isEmptyString:searchString])
        return [super arrangeObjects:objects];
    
    NSMutableArray *array = [[objects mutableCopy] autorelease];
    NSUInteger i = [array count];
    BOOL itemMatches;
    while(i--){
        itemMatches = [[array objectAtIndex:i] pathContainsSubstring:searchString];
        if((itemMatches && showsMatches == NO) || (itemMatches == NO && showsMatches))
            [array removeObjectAtIndex:i];
    }
    
    return [super arrangeObjects:array];
}

@end
