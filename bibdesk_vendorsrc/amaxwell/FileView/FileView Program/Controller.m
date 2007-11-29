//
//  Controller.m
//  FileViewTest
//
//  Created by Adam Maxwell on 06/23/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "Controller.h"

@implementation Controller

- (id)init
{
    self = [super init];
    if (self) {
        _filePaths = [[NSMutableArray alloc] initWithCapacity:100];
    }
    return self;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    [_slider unbind:@"value"];
    [_fileView unbind:@"iconURLs"];
    [_fileView unbind:@"selectionIndexes"];
    [_fileView setDataSource:nil];
    [_fileView setDelegate:nil];
    _fileView = nil;
}

- (void)selectAndSort
{
    [arrayController setSelectionIndex:5];
    NSSortDescriptor *sort = [[[NSSortDescriptor alloc] initWithKey:@"path" ascending:YES] autorelease];
    [arrayController setSortDescriptors:[NSArray arrayWithObject:sort]];    
}

- (void)awakeFromNib
{
    NSString *base = [@"~/Desktop" stringByStandardizingPath];
    NSArray *files = [[NSFileManager defaultManager] directoryContentsAtPath:base];
    NSString *path;
    NSUInteger i, iMax = [files count];
    for (i = 0; i < iMax; i++) {
        path = [files objectAtIndex:i];
        [arrayController addObject:[NSURL fileURLWithPath:[base stringByAppendingPathComponent:path]]];
    }
    [arrayController addObject:[NSNull null]];
    [arrayController addObject:[NSURL URLWithString:@"http://www.apple.com/"]];
    
    [_fileView bind:@"iconURLs" toObject:arrayController withKeyPath:@"arrangedObjects" options:nil];
    [_fileView bind:@"selectionIndexes" toObject:arrayController withKeyPath:@"selectionIndexes" options:nil];
    
    // for optional datasource method
    [_fileView setDataSource:self];
}

- (void)dealloc
{
    [_filePaths release];
    [super dealloc];
}

- (NSUInteger)numberOfIconsInFileView:(FileView *)aFileView { return [_filePaths count]; }
- (NSURL *)fileView:(FileView *)aFileView URLAtIndex:(NSUInteger)idx { return [_filePaths objectAtIndex:idx]; }

- (BOOL)fileView:(FileView *)aFileView moveURLsAtIndexes:(NSIndexSet *)aSet toIndex:(NSUInteger)anIndex;
{
    NSArray *toMove = [[[arrayController arrangedObjects] objectsAtIndexes:aSet] copy];
    [arrayController removeObjectsAtArrangedObjectIndexes:aSet];
    
    aSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(anIndex, [aSet count])];
    [arrayController insertObjects:toMove atArrangedObjectIndexes:aSet];
    [toMove release];
    return YES;
}    

- (BOOL)fileView:(FileView *)fileView replaceURLsAtIndexes:(NSIndexSet *)aSet withURLs:(NSArray *)newURLs;
{
    if ([_filePaths count] > [aSet count]) {
        [[self mutableArrayValueForKey:@"_filePaths"] replaceObjectsAtIndexes:aSet withObjects:newURLs];
        return YES;
    }
    return NO;
}

- (BOOL)fileView:(FileView *)fileView deleteURLsAtIndexes:(NSIndexSet *)indexes;
{
    if ([_filePaths count] >= [indexes count]) {
        [arrayController removeObjectsAtArrangedObjectIndexes:indexes];
        return YES;
    }
    return NO;
}

- (void)fileView:(FileView *)aFileView insertURLs:(NSArray *)absoluteURLs atIndexes:(NSIndexSet *)aSet;
{
    [arrayController insertObjects:absoluteURLs atArrangedObjectIndexes:aSet];
}

- (NSString *)fileView:(FileView *)aFileView subtitleAtIndex:(NSUInteger)anIndex;
{
    return @"This is only a test.";
}

@end
