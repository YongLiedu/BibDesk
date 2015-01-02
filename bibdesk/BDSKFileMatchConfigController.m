/*
 This software is Copyright (c) 2006-2015
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "BDSKFileMatchConfigController.h"
#import "BibDocument.h"
#import "BDSKOrphanedFilesFinder.h"
#import "BDSKTextWithIconCell.h"
#import "NSImage_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "NSPasteboard_BDSKExtensions.h"


@implementation BDSKFileMatchConfigController

- (id)init
{
    self = [super init];
    if (self) {
        documents = [NSArray new];
        files = [NSMutableArray new];
        useOrphanedFiles = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDocumentAddRemove:) name:BDSKDocumentControllerRemoveDocumentNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDocumentAddRemove:) name:BDSKDocumentControllerAddDocumentNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    BDSKDESTROY(documents);
    BDSKDESTROY(files);
    [super dealloc];
}

- (NSArray *)URLsFromURLsAndDirectories:(NSArray *)filesAndDirectories
{
    NSMutableArray *URLs = [NSMutableArray arrayWithCapacity:[filesAndDirectories count]];
    NSNumber *isDir;
    NSNumber *isPackage;
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSURL *aURL in filesAndDirectories) {
        isDir = isPackage = nil;
        [aURL getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
        [aURL getResourceValue:&isPackage forKey:NSURLIsPackageKey error:NULL];
        // presumably the file exists, since it arrived here because of drag-and-drop or the open panel, but we handle directories specially
        // if not a directory, or it's a package, add it immediately
        if (NO == [isDir boolValue] || [isPackage boolValue]) {
            [URLs addObject:aURL];
        } else {
            // shallow directory traversal: only add the (non-folder) contents of a folder that was dropped, since an arbitrarily deep traversal would have performance issues for file listing and for the search kit indexing
            for (NSURL *fileURL in [fm contentsOfDirectoryAtURL:aURL includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL]) {
                isDir = isPackage = nil;
                [fileURL getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
                [fileURL getResourceValue:&isPackage forKey:NSURLIsPackageKey error:NULL];
                if (NO == [isDir boolValue] || [isPackage boolValue])
                    [URLs addObject:fileURL];
            }
        }
    }
    return URLs;
}

- (IBAction)addRemove:(id)sender;
{
    if ([sender selectedSegment] == 0) { // add
        
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        [openPanel setAllowsMultipleSelection:YES];
        [openPanel setCanChooseDirectories:YES];
        [openPanel setPrompt:NSLocalizedString(@"Choose", @"")];
        [openPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
            if (result == NSFileHandlingPanelOKButton)
                [[self mutableArrayValueForKey:@"files"] addObjectsFromArray:[self URLsFromURLsAndDirectories:[openPanel URLs]]];
        }];
        
    } else { // remove
        
        [fileArrayController remove:self];
        
    }
}

- (IBAction)selectAllDocuments:(id)sender;
{
    [documents setValue:[NSNumber numberWithBool:(BOOL)[sender tag]] forKey:@"useDocument"];
}

- (void)handleDocumentAddRemove:(NSNotification *)note
{
    NSArray *docs = [[NSDocumentController sharedDocumentController] documents];
    NSMutableArray *array = [NSMutableArray array];
    for (NSDocument *doc in docs) {
        NSString *docType = [[[NSDocumentController sharedDocumentController] fileExtensionsFromType:[doc fileType]] lastObject] ?: @"";
        NSDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:[doc displayName], BDSKTextWithIconStringKey, [[NSWorkspace sharedWorkspace] iconForFileType:docType], BDSKTextWithIconImageKey, [NSNumber numberWithBool:NO], @"useDocument", doc, @"document", nil];
        [array addObject:dict];
    }
    [self setDocuments:array];
}

- (void)windowDidLoad
{
    [self handleDocumentAddRemove:nil];
    [fileTableView registerForDraggedTypes:[NSArray arrayWithObjects:(NSString *)kUTTypeFileURL, NSFilenamesPboardType, nil]];
    [addRemoveButton setEnabled:[fileTableView numberOfSelectedRows] > 0 forSegment:1];
}

// fix a zombie issue
- (void)windowWillClose:(NSNotification *)note
{
    [documentTableView setDataSource:nil];
    [documentTableView setDelegate:nil];
    [fileTableView setDataSource:nil];
    [fileTableView setDelegate:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setDocuments:(NSArray *)docs;
{
    if (documents != docs) {
        [documents release];
        documents = [docs copy];
    }
}

- (NSArray *)documents { return documents; }

- (NSArray *)files { return files; }

- (NSUInteger)countOfFiles {
    return [files count];
}

- (id)objectInFilesAtIndex:(NSUInteger)anIndex {
    return [files objectAtIndex:anIndex];
}

- (void)insertObject:(id)obj inFilesAtIndex:(NSUInteger)anIndex {
    [files insertObject:obj atIndex:anIndex];
}

- (void)removeObjectFromFilesAtIndex:(NSUInteger)anIndex {
    [files removeObjectAtIndex:anIndex];
}

- (NSArray *)publications;
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"useDocument == YES"];
    return [[documents filteredArrayUsingPredicate:predicate] valueForKeyPath:@"@unionOfArrays.document.publications"];
}

- (BOOL)useOrphanedFiles;
{
    return useOrphanedFiles;
}

- (void)orphanedFilesFinderFinished:(NSNotification *)note{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BDSKOrphanedFilesFinderFinishedNotification object:[BDSKOrphanedFilesFinder sharedFinder]];
    if (useOrphanedFiles)
        [[self mutableArrayValueForKey:@"files"] addObjectsFromArray:[[BDSKOrphanedFilesFinder sharedFinder] orphanedFiles]];
}

- (void)setUseOrphanedFiles:(BOOL)flag;
{
    useOrphanedFiles = flag;
    BDSKOrphanedFilesFinder *finder = [BDSKOrphanedFilesFinder sharedFinder];
    if (flag) {
        if ([finder wasLaunched] == NO) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orphanedFilesFinderFinished:) name:BDSKOrphanedFilesFinderFinishedNotification object:finder];
            [finder showWindow:nil];
        } else {
            [[self mutableArrayValueForKey:@"files"] addObjectsFromArray:[finder orphanedFiles]];
        }
    }
    else {
        [[self mutableArrayValueForKey:@"files"] removeObjectsInArray:[finder orphanedFiles]];
    }
}
    
- (NSString *)windowNibName { return @"FileMatcherConfigSheet"; }

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
    NSPasteboard *pboard = [info draggingPasteboard];
    if ([pboard canReadFileURLOfTypes:nil]) {
        [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
        return NSDragOperationLink;
    }
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op;
{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSArray *fileURLs = [pboard readFileURLsOfTypes:nil];
    if ([fileURLs count] > 0) {
        [[self mutableArrayValueForKey:@"files"] addObjectsFromArray:[self URLsFromURLsAndDirectories:fileURLs]];
        return YES;
    }
    return NO;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return 0; }
- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tc row:(NSInteger)r { return nil; }

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [addRemoveButton setEnabled:[fileTableView numberOfSelectedRows] > 0 forSegment:1];
}

@end
