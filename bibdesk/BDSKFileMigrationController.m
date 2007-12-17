//
//  BDSKFileMigrationController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/16/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BDSKFileMigrationController.h"
#import "BibDocument.h"
#import "BibDocument_Actions.h"
#import "BibItem.h"
#import "BDSKLinkedFile.h"

@interface BDSKURLTransformer : NSValueTransformer
@end

@interface BDSKBibItemTransformer : NSValueTransformer
@end

// Presently we have an array of dictionaries with 3 keys: @"URL" (NSURL *), @"error" (NSString *), and @"publication" (BibItem *).  These are returned in the NSError from the BibItem, and we just display the values as-is.  Displaying icons doesn't make sense since the files don't exist.  There's no helpful functionality here for resolving problems yet, and the error message is lame.

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
    [tableView setDoubleAction:@selector(editPublication:)];
    [tableView setTarget:self];
    [tableView setDataSource:self];
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
    BDSKPublicationsArray *pubs = [[self document] publications];
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
    }
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

// find the deepest directory that actually exists
- (NSString *)deepestDirectoryPathForURL:(NSURL *)theURL
{
    // assumes a file URL
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
    return [aURL isFileURL] ? [[aURL path] stringByAbbreviatingWithTildeInPath] : [aURL absoluteString];
}

@end

