//
//  BDSKSearchGroupSheetController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/26/06.
/*
 This software is Copyright (c) 2006-2012
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

#import "BDSKSearchGroupSheetController.h"
#import "BDSKSearchGroup.h"
#import "BDSKZoomGroupServer.h"
#import "BDSKServerInfo.h"
#import "BDSKCollapsibleView.h"
#import "BDSKSearchGroupServerManager.h"
#import "NSWindowController_BDSKExtensions.h"

#define DEFAULT_SERVER_NAME @"PubMed"

#define BDSKSearchGroupServersDidChangeNotification @"BDSKSearchGroupServersDidChangeNotification"

@implementation BDSKSearchGroupSheetController

+ (NSSet *)keyPathsForValuesAffectingType {
    return [NSSet setWithObjects:@"serverInfo", nil];
}

+ (NSSet *)keyPathsForValuesAffectingTypeTag {
    return [NSSet setWithObjects:@"type", nil];
}

+ (NSSet *)keyPathsForValuesAffectingZoom {
    return [NSSet setWithObjects:@"type", nil];
}

- (id)init {
    return [self initWithGroup:nil];
}

- (id)initWithGroup:(BDSKSearchGroup *)aGroup;
{
    self = [super init];
    if (self) {
        group = [aGroup retain];
        undoManager = nil;
        
        serverInfo = group ? [[group serverInfo] mutableCopy] : [[BDSKServerInfo defaultServerInfoWithType:BDSKSearchGroupEntrez] mutableCopy];
        
        isCustom = NO;
        isEditable = NO;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    BDSKDESTROY(group);
    BDSKDESTROY(undoManager);
    BDSKDESTROY(serverInfo);
    BDSKDESTROY(serverView);
    [super dealloc];
}

- (NSString *)windowNibName { return @"BDSKSearchGroupSheet"; }

- (void)reloadServersSelectingServerNamed:(NSString *)name{
    NSArray *servers = [[BDSKSearchGroupServerManager sharedManager] servers];
    NSArray *names = [servers valueForKey:@"name"];
    NSUInteger idx = (name == nil || [names count] == 0) ? [names count] + 1 : [names indexOfObject:name];
    if (idx == NSNotFound)
        idx = 0;
    [serverPopup removeAllItems];
    [serverPopup addItemsWithTitles:names];
    [[serverPopup menu] addItem:[NSMenuItem separatorItem]];
    [serverPopup addItemWithTitle:NSLocalizedString(@"Other", @"Popup menu item name for other search group server")];
    [serverPopup selectItemAtIndex:idx];
    [self selectPredefinedServer:serverPopup];
}

- (void)changeOptions {
    NSString *value = [serverInfo recordSyntax];
    if (value == nil) {
        [syntaxPopup selectItemAtIndex:0];
    } else {
        if ([syntaxPopup itemWithTitle:value] == nil)
            [syntaxPopup addItemWithTitle:value];
        [syntaxPopup selectItemWithTitle:value];
    }
}

- (void)handleServersChanged:(NSNotification *)note {
    if ([note object] != self) {
        NSString *name = nil;
        NSArray *servers = [[BDSKSearchGroupServerManager sharedManager] servers];
        BDSKServerInfo *info = [[self serverInfo] copy];
        
        if ([self isCustom] == NO) {
            NSUInteger idx = [servers indexOfObject:info];
            if (idx == NSNotFound)
                idx = [[servers valueForKey:@"name"] indexOfObject:[serverPopup titleOfSelectedItem]];
            if (idx != NSNotFound)
                name = [[servers objectAtIndex:idx] name];
        }
        
        [self reloadServersSelectingServerNamed:name];
        
        if (name == nil)
            [self setServerInfo:info];
        [info release];
    }
}

- (void)awakeFromNib
{
    [serverView retain];
    [serverView setMinSize:[serverView frame].size];
    [serverView setCollapseEdges:BDSKMaxXEdgeMask | BDSKMinYEdgeMask];
    
    [revealButton setBezelStyle:NSRoundedDisclosureBezelStyle];
    [revealButton performClick:self];
    
    NSString *name = nil;
    NSArray *servers = [[BDSKSearchGroupServerManager sharedManager] servers];
    
    if (group) {
        NSUInteger idx = [servers indexOfObject:[group serverInfo]];
        if (idx != NSNotFound)
            name = [[servers objectAtIndex:idx] name];
    } else if ([servers count]) {
        name = DEFAULT_SERVER_NAME;
    }
    
    [syntaxPopup addItemsWithTitles:[BDSKZoomGroupServer supportedRecordSyntaxes]];
    
    [self reloadServersSelectingServerNamed:name];
    [self changeOptions];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleServersChanged:) name:BDSKSearchGroupServersDidChangeNotification object:nil];
}

#pragma mark Actions

- (IBAction)dismiss:(id)sender {
    if ([sender tag] == NSOKButton) {
        
        if ([self commitEditing] == NO) {
            NSBeep();
            return;
        }
                
        // we don't have a group, so create  a new one
        if(group == nil){
            group = [[BDSKSearchGroup alloc] initWithServerInfo:serverInfo searchTerm:nil];
        }else{
            [group setServerInfo:serverInfo];
            [[group undoManager] setActionName:NSLocalizedString(@"Edit Search Group", @"Undo action name")];
        }
    }
    
    [super dismiss:sender];
}

- (IBAction)selectPredefinedServer:(id)sender;
{
    NSInteger i = [sender indexOfSelectedItem];
    
    [editButton setTitle:NSLocalizedString(@"Edit", @"Button title")];
    [editButton setToolTip:NSLocalizedString(@"Edit the selected default server settings", @"Tool tip message")];
    
    if (i == [sender numberOfItems] - 1) {
        [self setServerInfo:[group serverInfo] ?: [BDSKServerInfo defaultServerInfoWithType:[self type]]];
        if ([revealButton state] == NSOffState)
            [revealButton performClick:self];
        [self setCustom:YES];
        [self setEditable:YES];
        [addRemoveButton setTitle:NSLocalizedString(@"Add", @"Button title")];
        [addRemoveButton setToolTip:NSLocalizedString(@"Add a new default server with the current settings", @"Tool tip message")];
    } else {
        NSArray *servers = [[BDSKSearchGroupServerManager sharedManager] servers];
        [self setServerInfo:[servers objectAtIndex:i]];
        [self setCustom:NO];
        [self setEditable:NO];
        [addRemoveButton setTitle:NSLocalizedString(@"Remove", @"Button title")];
        [addRemoveButton setToolTip:NSLocalizedString(@"Remove the selected default server", @"Tool tip message")];
    }
}

- (IBAction)selectSyntax:(id)sender;
{
    NSString *syntax = [sender indexOfSelectedItem] == 0 ? nil : [sender titleOfSelectedItem];
    [serverInfo setRecordSyntax:syntax];
}

- (IBAction)addRemoveServer:(id)sender;
{
    if ([self commitEditing] == NO) {
        NSBeep();
        return;
    }
    
    if ([self isCustom]) {
        // add the custom server as a default server
        
        NSArray *servers = [[BDSKSearchGroupServerManager sharedManager] servers];
        if ([[servers valueForKey:@"name"] containsObject:[[self serverInfo] name]]) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Duplicate Server Name", @"Message in alert dialog when adding a search group server with a duplicate name")
                                             defaultButton:nil
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"A default server with the specified name already exists. Edit and Set the default server or use a different name.", @"Informative text in alert dialog when adding a search group server server with a duplicate name")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
            return;
        }
        
        [[BDSKSearchGroupServerManager sharedManager] addServer:[self serverInfo]];
        [self reloadServersSelectingServerNamed:[[self serverInfo] name]];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSearchGroupServersDidChangeNotification object:self];
        
    } else {
        // remove the selected default server
        
        [[BDSKSearchGroupServerManager sharedManager] removeServerAtIndex:[serverPopup indexOfSelectedItem]];
        [self reloadServersSelectingServerNamed:DEFAULT_SERVER_NAME];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSearchGroupServersDidChangeNotification object:self];
        
    }
}

- (IBAction)editServer:(id)sender;
{
    if ([revealButton state] == NSOffState)
        [revealButton performClick:sender];
    
    if ([self isCustom]) {
        NSBeep();
        return;
    }
    
    if ([self isEditable]) {
        if ([self commitEditing] == NO)
            return;
        
        NSUInteger idx = [serverPopup indexOfSelectedItem];
        NSUInteger existingIndex = [[[[BDSKSearchGroupServerManager sharedManager] servers] valueForKey:@"name"] indexOfObject:[serverPopup titleOfSelectedItem]];
        if (existingIndex != NSNotFound && existingIndex != idx) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Duplicate Server Name", @"Message in alert dialog when setting a search group server with a duplicate name")
                                             defaultButton:nil
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"Another default server with the specified name already exists. Edit and Set the default server or use a different name.", @"Informative text in alert dialog when setting a search group server server with a duplicate name")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
            return;
        }
        
        [[BDSKSearchGroupServerManager sharedManager] setServer:[self serverInfo] atIndex:idx];
        [self reloadServersSelectingServerNamed:[[self serverInfo] name]];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSearchGroupServersDidChangeNotification object:self];
    } else {
        [editButton setTitle:NSLocalizedString(@"Set", @"Button title")];
        [editButton setToolTip:NSLocalizedString(@"Set the selected default server settings", @"Tool tip message")];
        [self setEditable:YES];
        
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Edit Server Setting", @"Message in alert dialog when editing default search group server")
                                         defaultButton:NSLocalizedString(@"OK", @"Button title")
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"After editing, commit by choosing Set.", @"Informative text in alert dialog when editing default search group server")];
        [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
    }
}

- (void)resetAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSAlertDefaultReturn) {
        [[BDSKSearchGroupServerManager sharedManager] resetServers];
        [self reloadServersSelectingServerNamed:DEFAULT_SERVER_NAME];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSearchGroupServersDidChangeNotification object:self];
    }
}

- (IBAction)resetServers:(id)sender;
{
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Reset Servers", @"Message in alert dialog when resetting default search group servers")
                                     defaultButton:NSLocalizedString(@"OK", @"Button title")
                                   alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                       otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"This will restore the default server settings to their original values. This action cannot be undone.", @"Informative text in alert dialog when resetting default search group servers")];
    [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(resetAlertDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (IBAction)toggle:(id)sender;
{
    BOOL collapse = [revealButton state] == NSOffState;
    NSRect winRect = [[self window] frame];
    NSSize minSize = [[self window] minSize];
    NSSize maximumSize = [[self window] maxSize];
    CGFloat dh = [serverView minSize].height;
    if (collapse)
        dh *= -1;
    winRect.size.height += dh;
    winRect.origin.y -= dh;
    minSize.height += dh;
    maximumSize.height += dh;
    if (collapse == NO)
        [serverView setHidden:NO];
    [[self window] setFrame:winRect display:[[self window] isVisible] animate:[[self window] isVisible]];
    [[self window] setMinSize:minSize];
    [[self window] setMaxSize:maximumSize];
    if (collapse)
        [serverView setHidden:YES];
}

#pragma mark Accessors

- (void)setCustom:(BOOL)flag;
{
    isCustom = flag;
}

- (BOOL)isCustom { return isCustom; }

- (void)setEditable:(BOOL)flag;
{ 
    isEditable = flag;
}

- (BOOL)isEditable { return isEditable; }

- (BOOL)isZoom { return [serverInfo isZoom]; }

- (BDSKSearchGroup *)group { return group; }

- (BDSKServerInfo *)serverInfo { return serverInfo; }

- (void)setServerInfo:(BDSKServerInfo *)info;
{
    [objectController discardEditing];
    [serverInfo autorelease];
    serverInfo = [info mutableCopy];
    [self changeOptions];
}

- (NSString *)type { return [serverInfo type] ?: BDSKSearchGroupEntrez; }

- (void)setType:(NSString *)newType {
    if ([newType isEqualToString:[serverInfo type]] == NO)
        [serverInfo setType:newType];
}
 
- (NSInteger)typeTag {
    return [serverInfo serverType];
}

- (void)setTypeTag:(NSInteger)tag {
    // use [self setType:] to trigger KVO
    switch (tag) {
        case BDSKServerTypeEntrez: [self setType:BDSKSearchGroupEntrez]; break;
        case BDSKServerTypeZoom:   [self setType:BDSKSearchGroupZoom];   break;
        case BDSKServerTypeISI:    [self setType:BDSKSearchGroupISI];    break;
        case BDSKServerTypeDBLP:   [self setType:BDSKSearchGroupDBLP];   break;
        default: BDSKASSERT_NOT_REACHED("Unknown search type tag");
    }
}
 
#pragma mark NSEditor

- (BOOL)commitEditing {
    id firstResponder = [[self window] firstResponder];
    NSTextView *editor = nil;
    NSRange selection = {0, 0};
    
    if ([firstResponder isKindOfClass:[NSTextView class]]) {
        editor = firstResponder;
        selection = [editor selectedRange];
        if ([editor isFieldEditor])
            firstResponder = [firstResponder delegate];
    }
    
    if ([objectController commitEditing] == NO)
        return NO;
    
    if (editor && [[self window] firstResponder] != editor && 
        [[self window] makeFirstResponder:firstResponder] && 
        [[editor string] length] >= NSMaxRange(selection))
        [editor setSelectedRange:selection];
    
    NSString *message = nil;
    
    if ([self isZoom] == NO && ([NSString isEmptyString:[serverInfo name]] || [NSString isEmptyString:[serverInfo database]])) {
        message = NSLocalizedString(@"Unable to create a search group with an empty server name or database", @"Informative text in alert dialog when search group is invalid");
    } else if ([self isZoom] && ([NSString isEmptyString:[serverInfo name]] || [NSString isEmptyString:[serverInfo host]] || [NSString isEmptyString:[serverInfo database]] || [[serverInfo port] integerValue] == 0)) {
        message = NSLocalizedString(@"Unable to create a search group with an empty server name, address, database or port", @"Informative text in alert dialog when search group is invalid");
    }
    if (message) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Empty value", @"Message in alert dialog when data for a search group is invalid")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"%@", message];
        [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:NULL contextInfo:NULL];
        return NO;
    }
    return YES;
}

#pragma mark Undo support

- (NSUndoManager *)undoManager{
    if(undoManager == nil)
        undoManager = [[NSUndoManager alloc] init];
    return undoManager;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender{
    return [self undoManager];
}


@end
