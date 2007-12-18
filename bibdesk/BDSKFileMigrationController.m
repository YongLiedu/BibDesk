//
//  BDSKFileMigrationController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/16/07.
/*
 This software is Copyright (c) 2007
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
#import "BibDocument_Actions.h"
#import "BibDocument_Groups.h"
#import "BDSKPublicationsArray.h"
#import "BibItem.h"
#import "BDSKLinkedFile.h"
#import "NSWindowController_BDSKExtensions.h"

static NSString *BDSKFileMigrationFrameAutosaveName = @"BDSKFileMigrationWindow";

@interface BDSKURLTransformer : NSValueTransformer
@end

@interface BDSKBibItemTransformer : NSValueTransformer
@end

// Presently we have an array of dictionaries with 3 keys: @"URL" (NSURL *), @"error" (NSString *), and @"publication" (BibItem *).  These are returned in the NSError from the BibItem, and we just display the values as-is.  Displaying icons doesn't make sense since the files don't exist.  There's no helpful functionality here for resolving problems yet, and the error message is lame.
// Table column identifiers are "File", "Publication", "Error"

@implementation BDSKFileMigrationController

+ (void)initialize
{
    OBINITIALIZE;
    [NSValueTransformer setValueTransformer:[[[BDSKURLTransformer alloc] init] autorelease] forName:@"BDSKURLTransformer"];
    [NSValueTransformer setValueTransformer:[[[BDSKBibItemTransformer alloc] init] autorelease] forName:@"BDSKBibItemTransformer"];
}

- (id)init
{
    self = [self initWithWindowNibName:[self windowNibName]];
    if (self) {
        results = [NSMutableArray new];
        keepOriginalValues = YES;
        useSelection = NO;
    }
    return self;
}

- (void)dealloc
{
    [results release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [self setWindowFrameAutosaveNameOrCascade:BDSKFileMigrationFrameAutosaveName];
    [tableView setDoubleAction:@selector(editPublication:)];
    [tableView setTarget:self];
    [tableView setDataSource:self];
    [progressBar setUsesThreadedAnimation:NO];
}

- (NSString *)windowNibName { return @"BDSKFileMigration"; }

- (int)numberOfRowsInTableView:(NSTableView *)tableView { return 0; }
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row { return nil; }
- (NSMenu *)tableView:(NSTableView *)tv contextMenuForRow:(int)row column:(int)column;
{
    NSZone *zone = [NSMenu menuZone];
    NSMenu *menu = [[[NSMenu allocWithZone:zone] initWithTitle:@""] autorelease];
    if (row >= 0 && column >=0) {
        NSMenuItem *anItem = [[NSMenuItem allocWithZone:zone] initWithTitle:NSLocalizedString(@"Open Parent Directory in Finder", @"") action:@selector(openParentDirectory:) keyEquivalent:@""];
        [anItem setRepresentedObject:[[self mutableArrayValueForKey:@"results"] objectAtIndex:row]];
        [menu addItem:anItem];
        [anItem release];
        anItem = [[NSMenuItem allocWithZone:zone] initWithTitle:NSLocalizedString(@"Edit Publication", @"") action:@selector(editPublication:) keyEquivalent:@""];
        [anItem setRepresentedObject:[[self mutableArrayValueForKey:@"results"] objectAtIndex:row]];
        [menu addItem:anItem];
        [anItem release];
    }
    return [menu numberOfItems] > 0 ? menu : nil;
}

- (IBAction)migrate:(id)sender;
{
    // get rid of leftovers from a previous run
    [[self mutableArrayValueForKey:@"results"] removeAllObjects];
    
    NSArray *pubs = nil;
    if (useSelection == NO)
        pubs = [[self document] publications];
    else if ([[self document] hasExternalGroupsSelected] == NO)
        pubs = [[self document] selectedPublications];
    
    [progressBar setDoubleValue:0.0];
    [progressBar setHidden:NO];
    
    double current = 0, final = [pubs count];
    unsigned update = 0;
    NSEnumerator *pubEnum = [pubs objectEnumerator];
    BibItem *aPub;
    
    while (aPub = [pubEnum nextObject]) {
        NSError *error;
        if (NO == [aPub migrateFilesAndRemove:(NO == keepOriginalValues) error:&error]) {
            NSArray *messages = [error valueForKey:@"messages"];
            NSEnumerator *msgEnum = [messages objectEnumerator];
            NSDictionary *dict;
            while (dict = [msgEnum nextObject]) {
                NSMutableDictionary *displayDict = [dict mutableCopy];
                [displayDict setObject:aPub forKey:@"publication"];
                [[self mutableArrayValueForKey:@"results"] addObject:displayDict];
                [displayDict release];
            }
        }
        [progressBar setDoubleValue:(++current / final) * 100];
        
        if ((update++ % 5) == 0) {
            // tickling the runloop rather than using -displayIfNeeded keeps spindump from running on Leopard and slowing things down even more
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantPast]];
        }
    }
    
    [progressBar setDoubleValue:100.0];
    [progressBar setHidden:YES];

    [[self document] updatePreviews];
}

- (IBAction)editPublication:(id)sender;
{
    int row = [tableView clickedRow];
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
    int row = [tableView clickedRow];
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

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation
{
    NSString *tooltip = nil;
    if ([[tc identifier] isEqualToString:@"File"]) {
        NSURL *theURL = [[[self mutableArrayValueForKey:@"results"] objectAtIndex:row] objectForKey:@"URL"];
        tooltip = [theURL isFileURL] ? [theURL path] : [theURL absoluteString]; 
    }
    return tooltip;
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
    return [NSDictionary dictionaryWithObjectsAndKeys:[pub title], OATextWithIconCellStringKey, [NSImage imageNamed:@"cacheDoc"], OATextWithIconCellImageKey, nil];
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
    return [aURL isFileURL] ? [[NSFileManager defaultManager] displayNameAtPath:[aURL path]] : [aURL absoluteString];
}

@end

