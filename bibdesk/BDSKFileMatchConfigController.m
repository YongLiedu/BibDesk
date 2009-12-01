/*
 This software is Copyright (c) 2006-2009
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

@implementation BDSKFileMatchConfigController

- (id)init
{
    self = [super init];
    if (self) {
        documents = [NSMutableArray new];
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

static BOOL fileURLIsVisible(NSURL *fileURL)
{
    OSStatus err;
    FSRef fileRef;
    err = CFURLGetFSRef((CFURLRef)fileURL, &fileRef) ? noErr : fnfErr;
    CFBooleanRef isInvisible;
    BOOL isVisible = YES;
    
    if (noErr == err)
        err = LSCopyItemAttribute(&fileRef, kLSRolesAll, kLSItemIsInvisible, (CFTypeRef *)&isInvisible);
    
    if (noErr == err) {
        isVisible = (CFBooleanGetValue(isInvisible) == FALSE);
        CFRelease(isInvisible);
    }
    return isVisible;
}

- (NSArray *)URLsFromPathsAndDirectories:(NSArray *)filesAndDirectories
{
    NSMutableArray *URLs = [NSMutableArray arrayWithCapacity:[filesAndDirectories count]];
    BOOL isDir;
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in filesAndDirectories) {
        // presumably the file exists, since it arrived here because of drag-and-drop or the open panel, but we handle directories specially
        if (([fm fileExistsAtPath:path isDirectory:&isDir])) {
            // if not a directory, or it's a package, add it immediately
            if (NO == isDir || [[NSWorkspace sharedWorkspace] isFilePackageAtPath:path]) {
                [URLs addObject:[NSURL fileURLWithPath:path]];
            } else {
                // shallow directory traversal: only add the (non-folder) contents of a folder that was dropped, since an arbitrarily deep traversal would have performance issues for file listing and for the search kit indexing
                for (NSString *relPath in [fm contentsOfDirectoryAtPath:path error:NULL]) {
                    // directoryContentsAtPath returns relative paths with the starting directory as base
                    NSString *subpath = [path stringByAppendingPathComponent:relPath];
                    NSURL *fileURL = [NSURL fileURLWithPath:subpath];
                    [fm fileExistsAtPath:subpath isDirectory:&isDir];
                    if (fileURLIsVisible(fileURL) && NO == isDir || [[NSWorkspace sharedWorkspace] isFilePackageAtPath:subpath])
                        [URLs addObject:fileURL];
                }
            }
        }
    }
    return URLs;
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if (returnCode == NSOKButton)
		[[self mutableArrayValueForKey:@"files"] addObjectsFromArray:[self URLsFromPathsAndDirectories:[panel filenames]]];
}

- (IBAction)addRemove:(id)sender;
{
    if ([sender selectedSegment] == 0) { // add
        
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        [openPanel setAllowsMultipleSelection:YES];
        [openPanel setCanChooseDirectories:YES];
        [openPanel setPrompt:NSLocalizedString(@"Choose", @"")];
        [openPanel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
        
    } else { // remove
        
        [fileArrayController remove:self];
        
    }
}

- (IBAction)selectAllDocuments:(id)sender;
{
    BOOL flag = (BOOL)[sender tag];
    [documents setValue:[NSNumber numberWithBool:flag] forKeyPath:@"useDocument"];
}

- (void)handleDocumentAddRemove:(NSNotification *)note
{
    NSArray *docs = [[NSDocumentController sharedDocumentController] documents];
    NSMutableArray *array = [NSMutableArray array];
    for (NSDocument *doc in docs) {
        NSString *docType = [[[NSDocumentController sharedDocumentController] fileExtensionsFromType:[doc fileType]] lastObject] ?: @"";
        NSDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:[doc displayName], BDSKTextWithIconCellStringKey, [[NSWorkspace sharedWorkspace] iconForFileType:docType], BDSKTextWithIconCellImageKey, [NSNumber numberWithBool:NO], @"useDocument", doc, @"document", nil];
        [array addObject:dict];
    }
    [self setDocuments:array];
}

- (void)windowDidLoad
{
    [self handleDocumentAddRemove:nil];
    [fileTableView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
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
    [documents autorelease];
    documents = [docs mutableCopy];
}

- (NSArray *)documents { return documents; }

- (void)setFiles:(NSArray *)newFiles;
{
    [files autorelease];
    files = [newFiles mutableCopy];
}

- (NSArray *)files { return files; }

- (NSArray *)publications;
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"useDocument == YES"];
    return [[documents filteredArrayUsingPredicate:predicate] valueForKeyPath:@"@unionOfArrays.document.publications"];
}

- (BOOL)useOrphanedFiles;
{
    return useOrphanedFiles;
}

- (void)setUseOrphanedFiles:(BOOL)flag;
{
    useOrphanedFiles = flag;
    if (flag)
        [[self mutableArrayValueForKey:@"files"] addObjectsFromArray:[[BDSKOrphanedFilesFinder sharedFinder] orphanedFiles]];
    else
        [[self mutableArrayValueForKey:@"files"] removeObjectsInArray:[[BDSKOrphanedFilesFinder sharedFinder] orphanedFiles]];
}
    
- (NSString *)windowNibName { return @"FileMatcherConfigSheet"; }

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
    [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
    return NSDragOperationLink;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op;
{
    NSPasteboard *pboard = [info draggingPasteboard];
    NSArray *types = [pboard types];
    if ([types containsObject:NSFilenamesPboardType]) {
        NSArray *newFiles = [pboard propertyListForType:NSFilenamesPboardType];
        if ([newFiles count])
            [[self mutableArrayValueForKey:@"files"] addObjectsFromArray:[self URLsFromPathsAndDirectories:newFiles]];
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
