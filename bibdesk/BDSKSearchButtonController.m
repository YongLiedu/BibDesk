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

- (NSButton *)newButtonWithItemIdentifier:(NSString *)identifier title:(NSString *)title {
    NSButton *item = [[NSButton alloc] init];
    [item setBezelStyle:NSRecessedBezelStyle];
    [item setShowsBorderOnlyWhileMouseInside:YES];
    [item setButtonType:NSPushOnPushOffButton];
    [[item cell] setControlSize:NSSmallControlSize];
    [item setFont:[NSFont boldSystemFontOfSize:12.0]];
    [item setTitle:title];
    [[item cell] setRepresentedObject:identifier];
    return item;
}

- (void)changeSelectedSearchButton:(id)sender {
    [[self delegate] searchButtonControllerSelectionDidChange:self];
}

- (void)awakeFromNib
{
    [(BDSKEdgeView *)[self view] setEdges:BDSKMinYEdgeMask];
    
    [buttonBar setTarget:self];
    [buttonBar setAction:@selector(changeSelectedSearchButton:)];
    
    NSButton *item = [self newButtonWithItemIdentifier:BDSKPersonString title:NSLocalizedString(@"Person", @"Search button")];
    [buttonBar insertButton:item atIndex:0];
    [item release];
    
    item = [self newButtonWithItemIdentifier:BDSKTitleString title:NSLocalizedString(@"Title", @"Search button")];
    [buttonBar insertButton:item atIndex:0];
    [item release];
    
    item = [self newButtonWithItemIdentifier:BDSKAllFieldsString title:NSLocalizedString(@"Any Field", @"Search button")];
    [buttonBar insertButton:item atIndex:0];
    [item release];
    
    skimNotesItem = [self newButtonWithItemIdentifier:BDSKSkimNotesString title:NSLocalizedString(@"Skim Notes", @"Search button")];
    fileContentItem = [self newButtonWithItemIdentifier:BDSKFileContentSearchString title:NSLocalizedString(@"File Content", @"Search button")];
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

- (void)addFileContentItem {
    if (hasFileContentItem == NO) {
        [buttonBar insertButton:fileContentItem atIndex:[[buttonBar buttons] count]];
        hasFileContentItem = YES;
        [buttonBar setNeedsDisplay:YES];
    }
}

- (void)removeFileContentItem {
    if (hasFileContentItem) {
        [buttonBar removeButton:fileContentItem];
        hasFileContentItem = NO;
        [buttonBar setNeedsDisplay:YES];
    }
}

- (void)addSkimNotesItem {
    if (hasSkimNotesItem == NO) {
        [buttonBar insertButton:skimNotesItem atIndex:[[buttonBar buttons] count]];
        hasSkimNotesItem = YES;
    }
}

- (void)removeSkimNotesItem {
    if (hasSkimNotesItem) {
        [buttonBar removeButton:skimNotesItem];
        hasSkimNotesItem = NO;
    }
}

@end
