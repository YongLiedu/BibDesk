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
#import "BDSKButtonBar.h"

@implementation BDSKSearchButtonController

- (id)init { 
    if (self = [super initWithNibName:@"SearchButtonView" bundle:nil]) {
        [self view];
    }
    return self;
}

- (void)dealloc {
    BDSKDESTROY(fileContentItem);
    BDSKDESTROY(skimNotesItem);
    [super dealloc];
}

- (void)changeSelectedSearchButton:(id)sender {
    [[self delegate] searchButtonControllerSelectionDidChange:self];
}

- (void)awakeFromNib
{
    [(BDSKEdgeView *)[self view] setEdges:BDSKMinYEdgeMask];
    
    [buttonBar setTarget:self];
    [buttonBar setAction:@selector(changeSelectedSearchButton:)];
    
    [buttonBar addButtonWithTitle:NSLocalizedString(@"Any Field", @"Search button") representedObject:BDSKAllFieldsString];
    [buttonBar addButtonWithTitle:NSLocalizedString(@"Title", @"Search button") representedObject:BDSKTitleString];
    [buttonBar addButtonWithTitle:NSLocalizedString(@"Person", @"Search button") representedObject:BDSKPersonString];
    
    skimNotesItem = [buttonBar newButtonWithTitle:NSLocalizedString(@"Skim Notes", @"Search button") representedObject:BDSKSkimNotesString];
    fileContentItem = [buttonBar newButtonWithTitle:NSLocalizedString(@"File Content", @"Search button") representedObject:BDSKFileContentSearchString ];
}

- (NSString *)selectedItemIdentifier {
    return [buttonBar representedObjectOfSelectedButton];
}

- (void)selectItemWithIdentifier:(NSString *)ident {
    [buttonBar selectButtonWithRepresentedObject:ident];
}

- (void)setDelegate:(id<BDSKSearchButtonControllerDelegate>)newDelegate {
    delegate = newDelegate;
}

- (id<BDSKSearchButtonControllerDelegate>)delegate {
    return delegate;
}

- (void)addFileItems {
    if ([[buttonBar buttons] containsObject:skimNotesItem] == NO)
        [buttonBar addButton:skimNotesItem];
    if ([[buttonBar buttons] containsObject:fileContentItem] == NO)
        [buttonBar addButton:fileContentItem];
}

- (void)removeFileItems {
    if ([[buttonBar buttons] containsObject:fileContentItem])
        [buttonBar removeButton:fileContentItem];
    if ([[buttonBar buttons] containsObject:skimNotesItem])
        [buttonBar removeButton:skimNotesItem];
}

@end
