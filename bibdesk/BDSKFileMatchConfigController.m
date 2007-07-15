#import "BDSKFileMatchConfigController.h"
#import "BibDocument.h"
#import "BDSKOrphanedFilesFinder.h"

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
    [documents release];
    [files release];
    [super dealloc];
}

- (NSArray *)URLsFromPathsAndDirectories:(NSArray *)filesAndDirectories
{
    NSMutableArray *URLs = [NSMutableArray arrayWithCapacity:[filesAndDirectories count]];
    NSEnumerator *e = [filesAndDirectories objectEnumerator];
    NSString *path;
    BOOL isDir;
    NSFileManager *fm = [NSFileManager defaultManager];
    while ((path = [e nextObject])) {
        // presumably the file exists, since it arrived here because of drag-and-drop or the open panel, but we handle directories specially
        if (([fm fileExistsAtPath:path isDirectory:&isDir])) {
            // if not a directory, or it's a package, add it immediately
            if (NO == isDir || [[NSWorkspace sharedWorkspace] isFilePackageAtPath:path]) {
                [URLs addObject:[NSURL fileURLWithPath:path]];
            } else {
                // shallow directory traversal: only add the (non-folder) contents of a folder that was dropped, since an arbitrarily deep traversal would have performance issues for file listing and for the search kit indexing
                NSArray *dirContent = [fm directoryContentsAtPath:path];
                unsigned i, iMax = [dirContent count];
                for (i = 0; i < iMax; i++) {
                    // directoryContentsAtPath returns relative paths with the starting directory as base
                    NSString *subpath = [dirContent objectAtIndex:i];
                    // exclude .DS_Store and others
                    if ([subpath hasPrefix:@"."] == NO) {
                        subpath = [path stringByAppendingPathComponent:subpath];
                        if ([fm fileExistsAtPath:subpath isDirectory:&isDir] && (NO == isDir || [[NSWorkspace sharedWorkspace] isFilePackageAtPath:subpath]))
                            [URLs addObject:[NSURL fileURLWithPath:subpath]];
                    }
                }
            }
        }
    }
    return URLs;
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (returnCode == NSOKButton)
		[[self mutableArrayValueForKey:@"files"] addObjectsFromArray:[self URLsFromPathsAndDirectories:[panel filenames]]];
}

- (IBAction)add:(id)sender;
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:YES];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setPrompt:NSLocalizedString(@"Choose", @"")];
    [openPanel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (IBAction)remove:(id)sender;
{
    [fileArrayController remove:self];
}

- (IBAction)selectAllDocuments:(id)sender;
{
    BOOL flag = (BOOL)[sender tag];
    [documents setValue:[NSNumber numberWithBool:flag] forKeyPath:@"useDocument"];
}

- (void)handleDocumentAddRemove:(NSNotification *)note
{
    NSArray *docs = [[NSDocumentController sharedDocumentController] documents];
    NSEnumerator *e = [docs objectEnumerator];
    NSMutableArray *array = [NSMutableArray array];
    NSDocument *doc;
    while (doc = [e nextObject]) {
        NSString *docType = [[[NSDocumentController sharedDocumentController] fileExtensionsFromType:[doc fileType]] lastObject];
        if (nil == docType)
            docType = @"";
        NSDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:[doc displayName], OATextWithIconCellStringKey, [NSImage imageForFileType:docType], OATextWithIconCellImageKey, [NSNumber numberWithBool:NO], @"useDocument", doc, @"document", nil];
        [array addObject:dict];
    }
    [self setDocuments:array];
}

- (void)awakeFromNib
{
    [self handleDocumentAddRemove:nil];
    [fileTableView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
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

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
    [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
    return NSDragOperationLink;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op;
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

- (int)numberOfRowsInTableView:(NSTableView *)tableView { return 0; }
- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tc row:(int)r { return nil; }

@end
