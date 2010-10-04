//
//  BDSKFilerErrorController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/23/10.
/*
 This software is Copyright (c) 2010
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
 
 - Neither the name of Michael McCracken nor the names of any
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

#import "BDSKFilerErrorController.h"
#import "BDSKFiler.h"
#import "NSFileManager_BDSKExtensions.h"
#import "BibItem.h"
#import "BibDocument.h"
#import "BibDocument_Actions.h"
#import "NSWindowController_BDSKExtensions.h"
#import "BDSKPathColorTransformer.h"

#define BDSKFilerSelectKey @"select"

@implementation BDSKFilerErrorController

+ (void)initialize {
    BDSKINITIALIZE;
	// register transformer class
	[NSValueTransformer setValueTransformer:[[[BDSKOldPathColorTransformer alloc] init] autorelease]
									forName:@"BDSKOldPathColorTransformer"];
	[NSValueTransformer setValueTransformer:[[[BDSKNewPathColorTransformer alloc] init] autorelease]
									forName:@"BDSKNewPathColorTransformer"];
}

- (id)initWithErrors:(NSArray *)infoDicts forField:(NSString *)field fromDocument:(BibDocument *)doc options:(NSInteger)mask {
    if (self = [super initWithWindowNibName:@"AutoFile"]) {
        document = [doc retain];
        fieldName = [field retain];
        options = mask;
        
        NSMutableArray *tmpArray = [[NSMutableArray alloc] initWithCapacity:[infoDicts count]];
        for (NSDictionary *infoDict in infoDicts)
            [tmpArray addObject:[[infoDict mutableCopy] autorelease]];
        errorInfoDicts = [tmpArray copy];
        [tmpArray release];
    }
    return self;
}

- (void)dealloc {
    [tv setDelegate:nil];
    [tv setDataSource:nil];
    BDSKDESTROY(errorInfoDicts);
    BDSKDESTROY(document);
    BDSKDESTROY(fieldName);
    [super dealloc];
}

- (void)windowDidLoad {
    [self setWindowFrameAutosaveNameOrCascade:@"AutoFileWindow"];
    
    if (options & BDSKInitialAutoFileOptionMask)
        [infoTextField setStringValue:NSLocalizedString(@"There were problems moving the following files to the location generated using the format string. You can retry to move items selected in the first column.",@"description string")];
    else
        [infoTextField setStringValue:NSLocalizedString(@"There were problems moving the following files to the target location. You can retry to move items selected in the first column.",@"description string")];
	
    [tv setDoubleAction:@selector(showFile:)];
	[tv setTarget:self];
}

#pragma mark Actions

- (IBAction)done:(id)sender{
    [[self window] performClose:sender];
}

- (IBAction)tryAgain:(id)sender{
    NSArray *fileInfoDicts = [[self errorInfoDicts] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"select == YES"]];
    
    if ([fileInfoDicts count] == 0) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Nothing Selected", @"Message in alert dialog when retrying to autofile without selection")
                                         defaultButton:NSLocalizedString(@"OK", @"Button title")
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"Please select the items you want to auto file again or press Done.", @"Informative text in alert dialog")];
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:nil
                         didEndSelector:NULL 
                            contextInfo:NULL];
        return;
    }
    
    BibDocument *doc = [[document retain] autorelease];
    NSString *field = [[fieldName retain] autorelease];
    NSInteger mask = (options & BDSKInitialAutoFileOptionMask);
    mask |= ([forceCheckButton state]) ? BDSKForceAutoFileOptionMask : (options & BDSKCheckCompleteAutoFileOptionMask);
    
    [[self window] performClose:sender];
    
    [[BDSKFiler sharedFiler] movePapers:fileInfoDicts forField:field fromDocument:doc options:mask];
}

- (IBAction)dump:(id)sender{
    NSMutableString *string = [NSMutableString string];
    
    for (NSDictionary *info in errorInfoDicts) {
        [string appendStrings:NSLocalizedString(@"Publication key: ", @"Label for autofile dump"),
                              [[info objectForKey:BDSKFilerPublicationKey] citeKey], @"\n", 
                              NSLocalizedString(@"Original path: ", @"Label for autofile dump"),
                              [[[info objectForKey:BDSKFilerFileKey] URL] path], @"\n", 
                              NSLocalizedString(@"New path: ", @"Label for autofile dump"),
                              [info objectForKey:BDSKFilerNewPathKey], @"\n", 
                              NSLocalizedString(@"Status: ",@"Label for autofile dump"),
                              [info objectForKey:BDSKFilerStatusKey], @"\n", 
                              NSLocalizedString(@"Fix: ", @"Label for autofile dump"),
                              (([info objectForKey:BDSKFilerFixKey] == nil) ? NSLocalizedString(@"Cannot fix.", @"Cannot fix AutoFile error") : [info objectForKey:BDSKFilerFixKey]),
                              @"\n\n", nil];
    }
    
    NSString *fileName = NSLocalizedString(@"BibDesk AutoFile Errors", @"Filename for dumped autofile errors.");
    NSString *path = [[NSFileManager defaultManager] desktopDirectory];
    if (path)
        path = [[NSFileManager defaultManager] uniqueFilePathWithName:[fileName stringByAppendingPathExtension:@"txt"] atPath:path];
    
    [string writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (IBAction)selectAll:(id)sender{
    [errorInfoDicts setValue:[NSNumber numberWithBool:(BOOL)[sender tag]] forKey:BDSKFilerSelectKey];
}

- (IBAction)showFile:(id)sender{
    NSInteger row = [tv clickedRow];
    if (row == -1)
        return;
    NSDictionary *dict = [self objectInErrorInfoDictsAtIndex:row];
    NSInteger statusFlag = [[dict objectForKey:BDSKFilerFlagKey] integerValue];
    NSString *tcid = nil;
    NSString *path = nil;
    BibItem *pub = nil;
    NSInteger type = -1;

    if(sender == tv){
        NSInteger column = [tv clickedColumn];
        if(column == -1)
            return;
        tcid = [[[tv tableColumns] objectAtIndex:column] identifier];
        if([tcid isEqualToString:BDSKFilerOldPathKey])
            type = 0;
        else if([tcid isEqualToString:BDSKFilerNewPathKey])
            type = 1;
        else if([tcid isEqualToString:BDSKFilerStatusKey] || [tcid isEqualToString:BDSKFilerFixKey])
            type = 2;
    }else if([sender isKindOfClass:[NSMenuItem class]]){
        type = [sender tag];
    }
    
    switch(type){
        case 0:
            if(statusFlag & BDSKSourceFileDoesNotExistErrorMask)
                return;
            path = [[[dict objectForKey:BDSKFilerFileKey] URL] path];
            [[NSWorkspace sharedWorkspace]  selectFile:path inFileViewerRootedAtPath:nil];
            break;
        case 1:
            if(!(statusFlag & BDSKTargetFileExistsErrorMask))
                return;
            path = [dict objectForKey:BDSKFilerNewPathKey];
            [[NSWorkspace sharedWorkspace]  selectFile:path inFileViewerRootedAtPath:nil];
            break;
        case 2:
            pub = [dict objectForKey:BDSKFilerPublicationKey];
            // at this moment we have the document set
            [document editPub:pub];
            break;
	}
}

#pragma mark Accessors

- (NSArray *)errorInfoDicts {
    return errorInfoDicts;
}

- (NSUInteger)countOfErrorInfoDicts {
    return [errorInfoDicts count];
}

- (id)objectInErrorInfoDictsAtIndex:(NSUInteger)idx {
    return [errorInfoDicts objectAtIndex:idx];
}

#pragma mark table view stuff

// dummy dataSource implementation
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tView{ return 0; }
- (id)tableView:(NSTableView *)tView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{ return nil; }

- (NSString *)tableView:(NSTableView *)tv toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation{
	NSString *tcid = [tableColumn identifier];
    if ([tcid isEqualToString:BDSKFilerSelectKey])
        return NSLocalizedString(@"Select items to Try Again or to Force.", @"Tool tip message");
    else
        return [[self objectInErrorInfoDictsAtIndex:row] objectForKey:tcid];
}

@end
