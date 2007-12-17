//
//  BDSKFileMigrationController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/16/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BDSKFileMigrationController.h"
#import "BibDocument.h"
#import "BibItem.h"
#import "BDSKLinkedFile.h"

@interface BDSKURLTransformer : NSValueTransformer
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

@interface BDSKBibItemTransformer : NSValueTransformer
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
    [tableView setDoubleAction:@selector(openParentDirectory:)];
    [tableView setTarget:self];
}

- (NSString *)windowNibName { return @"BDSKFileMigration"; }

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

- (NSString *)deepestPathForRow:(unsigned)row
{
    // assumes a file URL
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *theURL = [[[self mutableArrayValueForKey:@"results"] objectAtIndex:row] valueForKey:@"URL"];
    NSString *path = nil;
    if ([theURL isFileURL]) {
        path = [theURL path];
        while ([fm fileExistsAtPath:path] == NO)
            path = [path stringByDeletingLastPathComponent];
    }
    return path;
}

- (IBAction)openParentDirectory:(id)sender;
{
    int row = [tableView clickedRow];
    NSString *path;
    if (row >= 0 && (path = [self deepestPathForRow:row]) != nil)
        [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:@""];
    else NSBeep();
}

@end
