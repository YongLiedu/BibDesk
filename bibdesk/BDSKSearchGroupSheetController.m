//
//  BDSKSearchGroupSheetController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/26/06.
/*
 This software is Copyright (c) 2006-2009
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
#import "NSFileManager_BDSKExtensions.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "NSWindowController_BDSKExtensions.h"

#define SERVERS_FILENAME @"SearchGroupServers"
#define SERVERS_DIRNAME @"SearchGroupServers"

#define DEFAULT_SERVER_NAME @"PubMed"

static NSMutableArray *searchGroupServers = nil;
static NSMutableDictionary *searchGroupServerFiles = nil;
static NSArray *sortDescriptors = nil;

#define BDSKSearchGroupServersDidChangeNotification @"BDSKSearchGroupServersDidChangeNotification"

@implementation BDSKSearchGroupSheetController

#pragma mark Search group servers

static BOOL isSearchFileAtPath(NSString *path)
{
    return [[[NSWorkspace sharedWorkspace] typeOfFile:[[path stringByStandardizingPath] stringByResolvingSymlinksInPath] error:NULL] isEqualToUTI:@"net.sourceforge.bibdesk.bdsksearch"];
}
    
+ (void)resetServers;
{
    [searchGroupServers removeAllObjects];
    [searchGroupServerFiles removeAllObjects];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:SERVERS_FILENAME ofType:@"plist"];
    
    NSDictionary *serverDicts = [NSDictionary dictionaryWithContentsOfFile:path];
    for (NSString *type in [NSArray arrayWithObjects:BDSKSearchGroupEntrez, BDSKSearchGroupZoom, BDSKSearchGroupISI, BDSKSearchGroupDBLP, nil]) {
        NSArray *dicts = [serverDicts objectForKey:type];
        for (NSDictionary *dict in dicts) {
            BDSKServerInfo *info = [[BDSKServerInfo alloc] initWithType:type dictionary:dict];
            if (info) {
                [searchGroupServers addObject:info];
                [info release];
            }
        }
    }
    
    [searchGroupServers sortUsingDescriptors:sortDescriptors];
}

+ (void)loadCustomServers;
{
    NSString *applicationSupportPath = [[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser]; 
    NSString *serversPath = [applicationSupportPath stringByAppendingPathComponent:SERVERS_DIRNAME];
    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:serversPath isDirectory:&isDir] && isDir) {
        NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:serversPath];
        NSString *file;
        while (file = [dirEnum nextObject]) {
            if ([[[dirEnum fileAttributes] valueForKey:NSFileType] isEqualToString:NSFileTypeDirectory]) {
                [dirEnum skipDescendents];
            } else if (isSearchFileAtPath([serversPath stringByAppendingPathComponent:file])) {
                NSString *path = [serversPath stringByAppendingPathComponent:file];
                NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
                BDSKServerInfo *info = [[BDSKServerInfo alloc] initWithType:nil dictionary:dict];
                if (info) {
                    NSUInteger idx = [[searchGroupServers valueForKey:@"name"] indexOfObject:[info name]];
                    if (idx != NSNotFound)
                        [searchGroupServers replaceObjectAtIndex:idx withObject:info];
                    else
                        [searchGroupServers addObject:info];
                    [searchGroupServerFiles setObject:path forKey:[info name]];
                    [info release];
                }
            }
        }
    }
    [searchGroupServers sortUsingDescriptors:sortDescriptors];
}

+ (void)saveServerFile:(BDSKServerInfo *)serverInfo;
{
    NSString *error = nil;
    NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:[serverInfo dictionaryValue] format:format errorDescription:&error];
    if (error) {
        NSLog(@"Error writing: %@", error);
        [error release];
    } else {
        NSString *applicationSupportPath = [[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser];
        NSString *serversPath = [applicationSupportPath stringByAppendingPathComponent:SERVERS_DIRNAME];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:serversPath isDirectory:&isDir] == NO) {
            if ([[NSFileManager defaultManager] createDirectoryAtPath:serversPath withIntermediateDirectories:NO attributes:nil error:NULL] == NO) {
                NSLog(@"Unable to save server info");
                return;
            }
        } else if (isDir == NO) {
            NSLog(@"Unable to save server info");
            return;
        }
        
        NSString *path = [searchGroupServerFiles objectForKey:[serverInfo name]];
        if (path)
            [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        path = [serversPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.bdsksearch", [serverInfo name], [serverInfo type]]];
        [data writeToFile:path atomically:YES];
        [searchGroupServerFiles setObject:path forKey:[serverInfo name]];
    }
}

+ (void)deleteServerFile:(BDSKServerInfo *)serverInfo;
{
    NSString *path = [searchGroupServerFiles objectForKey:[serverInfo name]];
    if (path) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        [searchGroupServerFiles removeObjectForKey:[serverInfo name]];
    }
}

+ (NSArray *)servers
{ 
    return searchGroupServers;
}

+ (void)addServer:(BDSKServerInfo *)serverInfo
{
    [searchGroupServers addObject:[[serverInfo copy] autorelease]];
    [searchGroupServers sortUsingDescriptors:sortDescriptors];
    [self saveServerFile:serverInfo];
}

+ (void)setServer:(BDSKServerInfo *)serverInfo atIndex:(NSUInteger)idx
{
    [self deleteServerFile:[searchGroupServers objectAtIndex:idx]];
    [searchGroupServers replaceObjectAtIndex:idx withObject:[[serverInfo copy] autorelease]];
    [searchGroupServers sortUsingDescriptors:sortDescriptors];
    [self saveServerFile:serverInfo];
}

+ (void)removeServerAtIndex:(NSUInteger)idx
{
    [self deleteServerFile:[searchGroupServers objectAtIndex:idx]];
    [searchGroupServers removeObjectAtIndex:idx];
}

#pragma mark Initialization

+ (void)initialize {
    BDSKINITIALIZE;
    
    NSSortDescriptor *typeSort = [[[NSSortDescriptor alloc] initWithKey:@"serverType" ascending:YES selector:@selector(compare:)] autorelease];
    NSSortDescriptor *nameSort = [[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
    
    searchGroupServers = [[NSMutableArray alloc] init];
    searchGroupServerFiles = [[NSMutableDictionary alloc] init];
    sortDescriptors = [[NSArray alloc] initWithObjects:typeSort, nameSort, nil];
    [self resetServers];
    [self loadCustomServers];
}

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
    if (self = [super init]) {
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
    [group release];
    [undoManager release];
    [serverInfo release];
    [serverView release];
    [super dealloc];
}

- (NSString *)windowNibName { return @"BDSKSearchGroupSheet"; }

- (void)reloadServersSelectingServerNamed:(NSString *)name{
    NSArray *servers = [[self class] servers];
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
        NSArray *servers = [[self class] servers];
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
    NSArray *servers = [[self class] servers];
    
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
            group = [[BDSKSearchGroup alloc] initWithType:[self type] serverInfo:serverInfo searchTerm:nil];
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
        NSArray *servers = [[self class] servers];
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
        
        NSArray *servers = [[self class] servers];
        if ([[servers valueForKey:@"name"] containsObject:[[self serverInfo] name]]) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Duplicate Server Name", @"Message in alert dialog when adding a search group server with a duplicate name")
                                             defaultButton:nil
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"A default server with the specified name already exists. Edit and Set the default server or use a different name.", @"Informative text in alert dialog when adding a search group server server with a duplicate name")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
            return;
        }
        
        [[self class] addServer:[self serverInfo]];
        [self reloadServersSelectingServerNamed:[[self serverInfo] name]];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKSearchGroupServersDidChangeNotification object:self];
        
    } else {
        // remove the selected default server
        
        [[self class] removeServerAtIndex:[serverPopup indexOfSelectedItem]];
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
        NSUInteger existingIndex = [[[[self class] servers] valueForKey:@"name"] indexOfObject:[serverPopup titleOfSelectedItem]];
        if (existingIndex != NSNotFound && existingIndex != idx) {
            NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Duplicate Server Name", @"Message in alert dialog when setting a search group server with a duplicate name")
                                             defaultButton:nil
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:NSLocalizedString(@"Another default server with the specified name already exists. Edit and Set the default server or use a different name.", @"Informative text in alert dialog when setting a search group server server with a duplicate name")];
            [alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
            return;
        }
        
        [[self class] setServer:[self serverInfo] atIndex:idx];
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
    if (returnCode == NSOKButton) {
        [[self class] resetServers];
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
    if ([objectController commitEditing] == NO)
        return NO;
    
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
                             informativeTextWithFormat:message];
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
