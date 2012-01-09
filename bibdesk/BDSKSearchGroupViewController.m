//
//  BDSKSearchGroupViewController.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 1/2/07.
/*
 This software is Copyright (c) 2007-2012
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
 
 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BDSKSearchGroupViewController.h"
#import "BDSKSearchGroup.h"
#import "BDSKCollapsibleView.h"
#import "BDSKEdgeView.h"


@implementation BDSKSearchGroupViewController

- (id)init {
    return [super initWithNibName:@"BDSKSearchGroupView" bundle:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [searchField setDelegate:nil];
    [super dealloc];
}

- (void)awakeFromNib {
    [collapsibleView setMinSize:[collapsibleView frame].size];
    [collapsibleView setCollapseEdges:BDSKMaxXEdgeMask | BDSKMaxYEdgeMask];
    BDSKEdgeView *edgeView = (BDSKEdgeView *)[self view];
    [edgeView setEdges:BDSKMinYEdgeMask];
    [edgeView setColor:[edgeView colorForEdge:NSMaxYEdge] forEdge:NSMinYEdge];
}

- (void)updateSearchView {
    BDSKASSERT([self group]);
    [self view];
    BDSKSearchGroup *group = [self group];
    NSString *name = [[group serverInfo] name];
    [searchField setStringValue:[group searchTerm] ?: @""];
    [searchField setRecentSearches:[group history]];
    [searchButton setEnabled:[group isRetrieving] == NO];
    [[searchField cell] setPlaceholderString:[NSString stringWithFormat:NSLocalizedString(@"Search %@", @"search group field placeholder"), name ?: @""]];
    [searchField setFormatter:[group searchStringFormatter]];
    [searchField selectText:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSearchGroupUpdatedNotification:) name:BDSKExternalGroupUpdatedNotification object:group];
}

- (BDSKSearchGroup *)group {
    return [self representedObject];
}

- (void)setGroup:(BDSKSearchGroup *)newGroup {
    if ([self representedObject] != newGroup) {
        if ([self representedObject])
            [[NSNotificationCenter defaultCenter] removeObserver:self name:BDSKExternalGroupUpdatedNotification object:[self representedObject]];
        [self setRepresentedObject:newGroup];
        if ([self representedObject])
            [self updateSearchView];
    }
}

- (IBAction)changeSearchTerm:(id)sender {
    [[self group] setSearchTerm:[sender stringValue]];
    [[self group] setHistory:[sender recentSearches]];
}

- (IBAction)nextSearch:(id)sender {
    [self changeSearchTerm:searchField];
    [[self group] search];
}

- (IBAction)searchHelp:(id)sender{
    NSString *helpBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"SearchingExternalDatabases" inBook:helpBookName];
}

- (BOOL)control:(NSControl *)control didFailToFormatString:(NSString *)aString errorDescription:(NSString *)error {
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid search string syntax", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:error];
    [alert setShowsHelp:YES];
    [alert setHelpAnchor:@"SearchingExternalDatabases"];
    [alert beginSheetModalForWindow:[[self view] window] modalDelegate:nil didEndSelector:nil contextInfo:NULL];
    return YES;
}

- (void)handleSearchGroupUpdatedNotification:(NSNotification *)notification{
    [searchButton setEnabled:[[self group] isRetrieving] == NO];
}

@end
