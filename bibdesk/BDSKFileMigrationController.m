//
//  BDSKFileMigrationController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/16/07.
/*
 This software is Copyright (c) 2007-2011
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

#import "BDSKFileMigrationController.h"
#import "BibDocument.h"
#import "BibDocument_UI.h"
#import "BibDocument_Actions.h"
#import "BibDocument_Groups.h"
#import "BDSKPublicationsArray.h"
#import "BibItem.h"
#import "BDSKLinkedFile.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKTextWithIconCell.h"
#import "NSMenu_BDSKExtensions.h"

#define BDSKURLTransformerName @"BDSKURLTransformer"
#define BDSKBibItemTransformerName @"BDSKBibItemTransformer"

#define BDSKFileMigrationFrameAutosaveName @"BDSKFileMigrationWindow"

@interface BDSKURLTransformer : NSValueTransformer
@end

@interface BDSKBibItemTransformer : NSValueTransformer
@end

// Presently we have an array of dictionaries with 3 keys: @"URL" (NSURL *), @"error" (NSString *), and @"publication" (BibItem *).  These are returned in the NSError from the BibItem, and we just display the values as-is.  Displaying icons doesn't make sense since the files don't exist.  There's no helpful functionality here for resolving problems yet, and the error message is lame.
// Table column identifiers are "File", "Publication", "Error"

@implementation BDSKFileMigrationController

+ (void)initialize
{
    BDSKINITIALIZE;
    [NSValueTransformer setValueTransformer:[[[BDSKURLTransformer alloc] init] autorelease] forName:BDSKURLTransformerName];
    [NSValueTransformer setValueTransformer:[[[BDSKBibItemTransformer alloc] init] autorelease] forName:BDSKBibItemTransformerName];
}

- (id)init
{
    self = [self initWithWindowNibName:[self windowNibName]];
    if (self) {
        NSUserDefaults*sud = [NSUserDefaults standardUserDefaults];
        results = [NSMutableArray new];
        keepLocalFileFields = NO == [sud boolForKey:BDSKRemoveConvertedLocalFileFieldsKey];
        keepRemoteURLFields = NO == [sud boolForKey:BDSKRemoveConvertedRemoteURLFieldsKey];
        useSelection = NO;
    }
    return self;
}

- (void)dealloc
{
    [tableView setDelegate:nil];
    [tableView setDataSource:nil];
    BDSKDESTROY(results);
    [super dealloc];
}

- (void)awakeFromNib
{
    [self setWindowFrameAutosaveNameOrCascade:BDSKFileMigrationFrameAutosaveName];
    [tableView setDoubleAction:@selector(editPublication:)];
    [tableView setTarget:self];
    [tableView setDataSource:self];
    [progressBar setUsesThreadedAnimation:YES];
}

- (NSString *)windowNibName { return @"BDSKFileMigration"; }

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName{
    NSString *title = NSLocalizedString(@"Convert Files and URLs", @"title for file migration window");
    if ([NSString isEmptyString:displayName] == NO)
        title = [NSString stringWithFormat:@"%@ %@ %@", title, [NSString emdashString], displayName];
    return title;
}

- (IBAction)migrate:(id)sender;
{
    NSMutableArray *observedResults = [self mutableArrayValueForKey:@"results"];
    
    // get rid of leftovers from a previous run
    [observedResults removeAllObjects];
    
    [statusField setStringValue:@""];
    
    NSArray *pubs = nil;
    if (useSelection == NO)
        pubs = [[self document] publications];
    else if ([[self document] hasExternalGroupsSelected] == NO)
        pubs = [[self document] selectedPublications];
    
    // Workaround for an AppKit bug in Tiger, the progress bar does not work after the first time it is used, so we replace it by a copy.  Apparently also in Leopard under some conditions
    NSProgressIndicator *newProgressBar = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:progressBar]];
    [[progressBar superview] replaceSubview:progressBar with:newProgressBar];
    progressBar = newProgressBar;

    [progressBar setDoubleValue:0.0];
    [progressBar setMaxValue:[pubs count]];
    [progressBar setHidden:NO];
    [migrateButton setEnabled:NO];
    
    NSInteger current = 0, final = [pubs count];
    NSInteger numberOfAddedFiles = 0, numberOfRemovedFields = 0, addedFiles, removedFields;
    NSInteger mask = BDSKRemoveNoFields;
    if (keepLocalFileFields == NO)
        mask |= BDSKRemoveLocalFileFieldsMask;
    if (keepRemoteURLFields == NO)
        mask |= BDSKRemoveRemoteURLFieldsMask;
        
    for (BibItem *aPub in pubs) {
        
        // Causes the progress bar and other UI to update
        if ((current++ % 5) == 0)
            [[self window] displayIfNeeded];
        
        NSError *error;
        if (NO == [aPub migrateFilesWithRemoveOptions:mask numberOfAddedFiles:&addedFiles numberOfRemovedFields:&removedFields error:&error]) {
            NSArray *messages = [error valueForKey:@"messages"];
            for (NSDictionary *dict in messages) {
                NSMutableDictionary *displayDict = [dict mutableCopy];
                [displayDict setObject:aPub forKey:@"publication"];
                [observedResults addObject:displayDict];
                [displayDict release];
            }
        }
        numberOfAddedFiles += addedFiles;
        numberOfRemovedFields += removedFields;
        [progressBar incrementBy:1.0];
        [statusField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%ld of %ld", @"Status message"), (long)current, (long)final]];
    }
    
    [progressBar setHidden:YES];
    [migrateButton setEnabled:YES];
    
    NSString *messageFormat = nil;
    if (mask == BDSKRemoveNoFields)
        messageFormat = NSLocalizedString(@"Converted %ld files or URLs.", @"Status message");
    else
        messageFormat = NSLocalizedString(@"Converted %ld files or URLs, removed %ld fields.", @"Status message");
    [statusField setStringValue:[NSString stringWithFormat:messageFormat, (long)numberOfAddedFiles, (long)numberOfRemovedFields]];
    
    // BibItem change notifications are only posted if the old fields are removed, so this ensures that the file view is updated
    if (numberOfAddedFiles > 0)
        [[self document] updatePreviews];
}

- (IBAction)editPublication:(id)sender;
{
    NSInteger row = [tableView clickedRow];
    BibItem *pub = nil;
    if ([sender respondsToSelector:@selector(representedObject)])
        pub = [[sender representedObject] valueForKey:@"publication"];
    if (nil == pub && row >= 0)
        pub = [[[self mutableArrayValueForKey:@"results"] objectAtIndex:row] objectForKey:@"publication"];

    if (pub)
        [[self document] editPub:pub];
    else
        NSBeep();
}

// find the deepest directory that actually exists; returns nil for non-file URLs
- (NSString *)deepestDirectoryPathForURL:(NSURL *)theURL
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = nil;
    if ([theURL isFileURL]) {
        path = [[theURL path] stringByDeletingLastPathComponent];
        while ([fm fileExistsAtPath:path] == NO)
            path = [path stringByDeletingLastPathComponent];
    }
    return path;
}

- (IBAction)openParentDirectory:(id)sender;
{
    NSInteger row = [tableView clickedRow];
    NSURL *theURL = nil;
    NSString *path = nil;
    if ([sender respondsToSelector:@selector(representedObject)])
        theURL = [[sender representedObject] valueForKey:@"URL"];
    if (nil == theURL && row >= 0)
        theURL = [[[self mutableArrayValueForKey:@"results"] objectAtIndex:row] objectForKey:@"URL"];
    if (theURL)
        path = [self deepestDirectoryPathForURL:theURL];
    if (path)
        [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:@""];
    else NSBeep();
}

- (void)showHelp:(id)sender
{
    NSString *helpBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"FileMigration" inBook:helpBookName];
}

#pragma mark TableView delegate

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation
{
    NSString *tooltip = nil;
    if ([[tc identifier] isEqualToString:@"File"]) {
        NSURL *theURL = [[[self mutableArrayValueForKey:@"results"] objectAtIndex:row] objectForKey:@"URL"];
        tooltip = [theURL isFileURL] ? [theURL path] : [theURL absoluteString]; 
    }
    return tooltip;
}

#pragma mark Contextual menu

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu == [tableView menu]) {
        NSInteger row = [tableView clickedRow];
        [menu removeAllItems];
        if (row >= 0) {
            NSMenuItem *anItem = [menu addItemWithTitle:NSLocalizedString(@"Open Parent Directory in Finder", @"") action:@selector(openParentDirectory:) keyEquivalent:@""];
            [anItem setRepresentedObject:[[self mutableArrayValueForKey:@"results"] objectAtIndex:row]];
            [menu addItem:anItem];
            anItem = [menu addItemWithTitle:NSLocalizedString(@"Edit Publication", @"") action:@selector(editPublication:) keyEquivalent:@""];
            [anItem setRepresentedObject:[[self mutableArrayValueForKey:@"results"] objectAtIndex:row]];
            [menu addItem:anItem];
        }
    }
}

@end

@implementation BDSKBibItemTransformer

+ (Class)transformedValueClass {
    return [NSDictionary class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)pub {
    return [NSDictionary dictionaryWithObjectsAndKeys:[pub title], BDSKTextWithIconCellStringKey, [NSImage imageNamed:@"cacheDoc"], BDSKTextWithIconCellImageKey, nil];
}

@end

@implementation BDSKURLTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)aURL {
    NSString *stringValue = nil;
    if ([aURL isFileURL]) {
        CFStringRef displayName = NULL;
        LSCopyDisplayNameForURL((CFURLRef)aURL, &displayName);
        stringValue = [(id)displayName autorelease];
    }
    if (nil == stringValue)
        stringValue = [aURL absoluteString];
    return stringValue;
}

@end

