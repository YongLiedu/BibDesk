//
//  BDSKSearchButtonController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 04/04/07.
/*
 This software is Copyright (c) 2007-2009
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

#import "BDSKSearchButtonController.h"
#import "BDSKEdgeView.h"
#import "BDSKGradientView.h"
#import "AMButtonBarItem.h"

@implementation BDSKSearchButtonController

- (id)init { 
    id obj = [self initWithWindowNibName:[self windowNibName]];
    [obj window];
    return obj;
}

- (void)dealloc {
    [fileContentItem release];
    [skimNotesItem release];
    [super dealloc];
}

- (NSString *)windowNibName { return @"SearchButtonView"; }

- (void)awakeFromNib
{
    NSParameterAssert(nil != edgeView);
    [edgeView setEdges:BDSKMinYEdgeMask];
    
    [gradientView setGradient:[[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.82 alpha:1.0] endingColor:[NSColor colorWithCalibratedWhite:0.914 alpha:1.0]] autorelease]];
    [buttonBar setAllowsMultipleSelection:NO];
    
    AMButtonBarItem *item = [[AMButtonBarItem alloc] initWithIdentifier:BDSKPersonString];
    [item setTitle:NSLocalizedString(@"Person", @"Search button")];
    [buttonBar insertItem:item atIndex:0];
    [item release];
    
    item = [[AMButtonBarItem alloc] initWithIdentifier:BDSKTitleString];
    [item setTitle:NSLocalizedString(@"Title", @"Search button")];
    [buttonBar insertItem:item atIndex:0];
    [item release];
    
    item = [[AMButtonBarItem alloc] initWithIdentifier:BDSKAllFieldsString];
    [item setTitle:NSLocalizedString(@"Any Field", @"Search button")];
    [buttonBar insertItem:item atIndex:0];
    [item release];
    
    skimNotesItem = [[AMButtonBarItem alloc] initWithIdentifier:BDSKSkimNotesString];
    [skimNotesItem setTitle:NSLocalizedString(@"Skim Notes", @"Search button")];
    
    fileContentItem = [[AMButtonBarItem alloc] initWithIdentifier:BDSKFileContentSearchString];
    [fileContentItem setTitle:NSLocalizedString(@"File Content", @"Search button")];
}

- (NSString *)selectedItemIdentifier { return [buttonBar selectedItemIdentifier]; }

- (void)selectItemWithIdentifier:(NSString *)ident { [buttonBar selectItemWithIdentifier:ident]; }

- (id)view { return edgeView; }

- (void)setDelegate:(id)delegate { [buttonBar setDelegate:delegate]; }

- (id)delegate { return [buttonBar delegate]; }

- (void)addFileContentItem {
    if (hasFileContentItem == NO) {
        [buttonBar insertItem:fileContentItem atIndex:[[buttonBar items] count]];
        hasFileContentItem = YES;
        [buttonBar setNeedsDisplay:YES];
    }
}

- (void)removeFileContentItem {
    if (hasFileContentItem) {
        [buttonBar removeItem:fileContentItem];
        hasFileContentItem = NO;
        [buttonBar setNeedsDisplay:YES];
    }
}

- (void)addSkimNotesItem {
    if (hasSkimNotesItem == NO) {
        [buttonBar insertItem:skimNotesItem atIndex:[[buttonBar items] count]];
        hasSkimNotesItem = YES;
        [buttonBar setNeedsDisplay:YES];
    }
}

- (void)removeSkimNotesItem {
    if (hasSkimNotesItem) {
        [buttonBar removeItem:skimNotesItem];
        hasSkimNotesItem = NO;
        [buttonBar setNeedsDisplay:YES];
    }
}

@end
