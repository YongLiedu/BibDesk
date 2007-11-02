//
//  Controller.m
//  FileViewTest
//
//  Created by Adam Maxwell on 06/23/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "Controller.h"

#define BASEPATH @"/Volumes/Local/Users/amaxwell/Desktop/"

@implementation Controller

- (id)init
{
    self = [super init];
    if (self) {
        _filePaths = [[NSMutableArray alloc] initWithCapacity:100];
        /*
        [_filePaths addObject:BASEPATH @"WebOfScienceSearch.g"];
        [_filePaths addObject:BASEPATH @"Sent Messages (Personal).mbox"];
        [_filePaths addObject:BASEPATH @"tex_test"];
        [_filePaths addObject:BASEPATH @"navier.bib"];
        [_filePaths addObject:BASEPATH @"wos_search.l"];
        [_filePaths addObject:BASEPATH @"test.rtf"];
        [_filePaths addObject:@"/Volumes/Local/Users/amaxwell/Doctorate/Pictures and Movies/BWsheetflow.mov"];
        [_filePaths addObject:@"/Volumes/Local/Users/amaxwell/Doctorate/Pictures and Movies/Glasrud 20mm tube FeOH.tiff"];
        */
        //unsigned exceptionMask = (NSLogUncaughtExceptionMask|NSLogUncaughtSystemExceptionMask|NSLogUncaughtRuntimeErrorMask|NSLogTopLevelExceptionMask);
        //[[NSExceptionHandler defaultExceptionHandler] setExceptionHandlingMask:exceptionMask];
        //[[NSExceptionHandler defaultExceptionHandler] setDelegate:self];

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

#define URL(x) \
[NSURL fileURLWithPath:x]

- (void)testBindings
{
    [arrayController addObject:URL(BASEPATH @"WebOfScienceSearch.g")];
    [arrayController addObject:URL(BASEPATH @"Sent Messages (Personal).mbox")];
    [arrayController addObject:URL(BASEPATH @"tex_test")];
    [arrayController addObject:URL(BASEPATH @"navier.bib")];
    [arrayController addObject:URL(BASEPATH @"wos_search.l")];
    [arrayController addObject:URL(BASEPATH @"test.rtf")];
    [arrayController addObject:URL(@"/Volumes/Local/Users/amaxwell/Doctorate/Pictures and Movies/BWsheetflow.mov")];
    [arrayController addObject:URL(@"/Volumes/Local/Users/amaxwell/Doctorate/Pictures and Movies/Glasrud 20mm tube FeOH.tiff")];
    [arrayController addObject:URL(@"/Volumes/Local/Users/amaxwell/Doctorate/Articles/3st1d-papanicolaou.pdf")];
    [arrayController addObject:[NSNull null]];

    //[self performSelector:@selector(selectAndSort) withObject:nil afterDelay:5.0f];
}

- (void)awakeFromNib
{
    [_fileView setDelegate:self];
    [_fileView setDataSource:nil];
    [_fileView bind:@"iconURLs" toObject:arrayController withKeyPath:@"arrangedObjects" options:nil];
    [_fileView bind:@"selectionIndexes" toObject:arrayController withKeyPath:@"selectionIndexes" options:nil];
    [self performSelector:@selector(testBindings) withObject:nil afterDelay:1.0f];
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
    //[_filePaths addObjectsFromArray:absoluteURLs];
    [arrayController insertObjects:absoluteURLs atArrangedObjectIndexes:aSet];
    //[arrayController addObjects:absoluteURLs];
}

- (BOOL)allowsEditingFileView:(FileView *)aView;
{
    return YES;
}

@end
