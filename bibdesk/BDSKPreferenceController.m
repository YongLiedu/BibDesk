//
//  BDSKPreferenceController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 05/04/06.
/*
 This software is Copyright (c) 2006-2010
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

#import "BDSKPreferenceController.h"
#import "BDSKPreferenceRecord.h"
#import "BDSKPreferencePane.h"
#import "BDSKPreferenceIconView.h"
#import "BDSKOverlayWindow.h"
#import "BDSKVersionNumber.h"
#import <Sparkle/Sparkle.h>

#define LOCALIZATION_TABLE          @"Preferences"
#define DEFAULTS_TABLE              @"Preferences"
#define IDENTIFIER_KEY              @"identifier"
#define TITLE_KEY                   @"title"
#define INITIAL_VALUES_KEY          @"initialValues"
#define PANES_KEY                   @"panes"
#define MINIMUM_SYSTEM_VERSION_KEY  @"minimumSystemVersion"
#define MAXIMUM_SYSTEM_VERSION_KEY  @"maximumSystemVersion"

#define BDSKPreferencesToolbarIdentifier                @"BDSKPreferencesToolbarIdentifier"
#define BDSKPreferencesToolbarShowAllItemIdentifier     @"BDSKPreferencesToolbarShowAllItemIdentifier"
#define BDSKPreferencesToolbarPreviousItemIdentifier    @"BDSKPreferencesToolbarPreviousItemIdentifier"
#define BDSKPreferencesToolbarNextItemIdentifier        @"BDSKPreferencesToolbarNextItemIdentifier"
#define BDSKPreferencesToolbarSearchItemIdentifier      @"BDSKPreferencesToolbarSearchItemIdentifier"


@interface BDSKPreferenceController (BDSKPrivate)
- (void)iconViewShowPane:(id)sender;
- (void)setSelectedPaneIdentifier:(NSString *)identifier;
- (void)setupToolbar;
- (void)loadPreferences;
- (void)loadPanes;
- (BDSKPreferenceIconView *)iconView;
- (void)changeContentView:(NSView *)view display:(BOOL)display;
- (void)updateSearchAndShowAll:(BOOL)showAll;
@end


@interface NSToolbar (BDSKPrivateDeclarations)
- (void)_setCustomizesAlwaysOnClickAndDrag:(BOOL)flag;
- (void)_setWantsToolbarContextMenu:(BOOL)flag;
- (void)_setFirstMoveableItemIndex:(NSInteger)index;
@end


@implementation BDSKPreferenceController

// we want to be able to get the shared instance in MainMenu.nib, which passes through alloc/init, so we need to be a bit more careful

static id sharedController = nil;

+ (id)sharedPreferenceController {
    if (nil == sharedController)
        [[[self alloc] init] release];
    return sharedController;
}

+ (id)allocWithZone:(NSZone *)zone {
    return [sharedController retain] ?: [super allocWithZone:zone];
}

- (id)init {
    if (sharedController == nil) {
        if (self = [super initWithWindowNibName:@"Preferences"]) {
            categories = [[NSMutableArray alloc] init];
            categoryDicts = [[NSMutableDictionary alloc] init];
            records = [[NSMutableDictionary alloc] init];
            panes = [[NSMutableDictionary alloc] init];
            identifierSearchTerms = [[NSMutableDictionary alloc] init];
            selectedPaneIdentifier = [@"" retain];
            helpBookName = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleHelpBookName"] retain];
            [self loadPreferences];
        }
        sharedController = [self retain];
    } else if (self != sharedController) {
        BDSKASSERT_NOT_REACHED("shouldn't be able to create multiple instances");
        [self release];
        self = [sharedController retain];
    }
    return sharedController;
}

// windiwDidLoad comes after the window is already moved onscreen, I think that's wrong
- (void)windowDidLoad {
    [self setupToolbar];
    [[self window] setShowsToolbarButton:NO];
    [self setWindowFrameAutosaveName:@"BDSKPreferencesWindow"];
    
    [[self window] setTitle:[self defaultWindowTitle]];
    
    [self loadPanes];
    
    iconView = [[BDSKPreferenceIconView alloc] initWithPreferenceController:self];
    [iconView setAction:@selector(iconViewShowPane:)];
    [iconView setTarget:self];
    [self changeContentView:iconView display:NO];
    
    overlay = [[BDSKOverlayWindow alloc] initWithContentRect:[[self window] contentRectForFrameRect:[[self window] frame]] styleMask:[[self window] styleMask] backing:[[self window] backingType] defer:YES];
    [overlay setReleasedWhenClosed:NO];
    BDSKSpotlightView *spotlightView = [[BDSKSpotlightView alloc] initFlipped:[iconView isFlipped]];
    [spotlightView setDelegate:self];
    [overlay setContentView:spotlightView];
    [spotlightView release];
    
    [self setSelectedPaneIdentifier:@""];
    
    [helpButton setHidden:YES];
    [revertButton setEnabled:NO];
}

- (BOOL)windowShouldClose:(id)window {
    if ([[[self window] firstResponder] isKindOfClass:[NSText class]])
        [[self window] makeFirstResponder:nil];
    if ([[self window] attachedSheet])
        return NO;
    BDSKPreferencePane *pane = [self selectedPane];
    return pane == nil || [pane shouldCloseWindow];
}

- (void)windowWillClose:(NSNotification *)notification {
    [[self selectedPane] willCloseWindow];
}

- (void)showWindow:(id)sender {
    BOOL wasVisible = [[self window] isVisible];
    if (wasVisible == NO)
        [[self selectedPane] willShowWindow];
    [super showWindow:sender];
    [self updateSearchAndShowAll:NO];
    if (wasVisible == NO)
        [[self selectedPane] didShowWindow];
}

- (NSString *)defaultWindowTitle {
    return [NSString stringWithFormat:NSLocalizedString(@"%@ Preferences", @""), [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]];
}

#pragma mark Actions

- (void)revertPaneSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertDefaultReturn) {
        NSDictionary *initialValues = [[self selectedPane] initialValues];
        if ([initialValues count])
            [[[NSUserDefaultsController sharedUserDefaultsController] values] setValuesForKeysWithDictionary:initialValues];
        [[self selectedPane] defaultsDidRevert];
    }
}

- (IBAction)revertPaneDefaults:(id)sender {
    NSString *label = [self localizedLabelForIdentifier:[self selectedPaneIdentifier]];
    NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Reset %@ preferences to their original values?", @"Message in alert dialog when pressing Reset All button"), label]
                                     defaultButton:NSLocalizedString(@"Reset", @"Button title")
                                   alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                       otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"Choosing Reset will restore all settings in this pane to the state they were in when the application was first installed.", @"Informative text in alert dialog when pressing Reset All button")];
    [alert beginSheetModalForWindow:[self window]
                      modalDelegate:self
                     didEndSelector:@selector(revertPaneSheetDidEnd:returnCode:contextInfo:)
                        contextInfo:NULL];


}

- (void)revertAllSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertDefaultReturn) {
        [[NSUserDefaultsController sharedUserDefaultsController] revertToInitialValues:nil];
        NSTimeInterval interval = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"SUScheduledCheckInterval"] doubleValue];
        [[SUUpdater sharedUpdater] setUpdateCheckInterval:interval];
        [[SUUpdater sharedUpdater] setAutomaticallyChecksForUpdates:interval > 0.0];
        [[panes allValues] makeObjectsPerformSelector:@selector(defaultsDidRevert)];
    }
}

- (IBAction)revertAllDefaults:(id)sender {
    NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Reset all preferences to their original values?", @"Message in alert dialog when pressing Reset All button") 
                                     defaultButton:NSLocalizedString(@"Reset", @"Button title")
                                   alternateButton:NSLocalizedString(@"Cancel", @"Button title")
                                       otherButton:nil
                         informativeTextWithFormat:NSLocalizedString(@"Choosing Reset will restore all settings to the state they were in when the application was first installed.", @"Informative text in alert dialog when pressing Reset All button")];
    [alert beginSheetModalForWindow:[self window]
                      modalDelegate:self
                     didEndSelector:@selector(revertAllSheetDidEnd:returnCode:contextInfo:)
                        contextInfo:NULL];
}

- (IBAction)showHelp:(id)sender {
    NSString *helpAnchor;
    NSURL *helpURL;
    if (helpBookName && (helpAnchor = [[self selectedPane] helpAnchor]))
        [[NSHelpManager sharedHelpManager] openHelpAnchor:helpAnchor inBook:helpBookName];
    else if (helpURL = [[self selectedPane] helpURL])
        [[NSWorkspace sharedWorkspace] openURL:helpURL];
}

- (IBAction)showAll:(id)sender {
    [self selectPaneWithIdentifier:@""];
}

- (IBAction)showPane:(id)sender {
    if ([sender respondsToSelector:@selector(itemIdentifier)])
        [self selectPaneWithIdentifier:[sender itemIdentifier]];
    else if ([sender respondsToSelector:@selector(representedObject)] && [sender representedObject])
        [self selectPaneWithIdentifier:[sender representedObject]];
    else if ([sender respondsToSelector:@selector(tag)] && (NSUInteger)[sender tag] < [[self allPaneIdentifiers] count])
        [self selectPaneWithIdentifier:[[self allPaneIdentifiers] objectAtIndex:[sender tag]]];
}

- (void)iconViewShowPane:(id)sender {
    [self selectPaneWithIdentifier:[sender clickedIdentifier]];
}

- (IBAction)showNextPane:(id)sender {
    BDSKPreferencePane *pane = [self selectedPane];
    NSString *identifier = [pane identifier];
    NSArray *allPanes = [self allPaneIdentifiers];
    NSUInteger idx = identifier ? [allPanes indexOfObject:identifier] : NSNotFound;
    if (idx == NSNotFound || idx + 1 >= [allPanes count])
        idx = 0;
    else
        idx++;
    [self selectPaneWithIdentifier:[allPanes objectAtIndex:idx]];
}

- (IBAction)showPreviousPane:(id)sender {
    BDSKPreferencePane *pane = [self selectedPane];
    NSString *identifier = [pane identifier];
    NSArray *allPanes = [self allPaneIdentifiers];
    NSUInteger idx = identifier ? [allPanes indexOfObject:identifier] : NSNotFound;
    if (idx == NSNotFound || idx == 0)
        idx = [allPanes count] - 1;
    else
        idx--;
    [self selectPaneWithIdentifier:[allPanes objectAtIndex:idx]];
}

- (IBAction)search:(id)sender {
    [self updateSearchAndShowAll:YES];
}

#pragma mark Categories and Panes

- (NSArray *)categories {
    return categories;
}

- (NSArray *)panesForCategory:(NSString *)category {
    return [[categoryDicts objectForKey:category] valueForKey:PANES_KEY];
}

- (NSArray *)allPaneIdentifiers {
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *cat in categories)
        [result addObjectsFromArray:[self panesForCategory:cat]];
    return result;
}

- (id)paneForIdentifier:(NSString *)identifier {
    return [panes objectForKey:identifier];
}

- (NSString *)selectedPaneIdentifier {
    return selectedPaneIdentifier;
}

- (void)setSelectedPaneIdentifier:(NSString *)identifier {
    if (identifier != selectedPaneIdentifier) {
        [selectedPaneIdentifier release];
        selectedPaneIdentifier = [identifier retain];
    }
}

- (id)selectedPane {
    NSString *paneID = [self selectedPaneIdentifier];
    return [paneID length] ? [self paneForIdentifier:paneID] : nil;
}

- (void)setDelayedPaneIdentifier:(NSString *)identifier {
    if (identifier != delayedPaneIdentifier) {
        [delayedPaneIdentifier release];
        delayedPaneIdentifier = [identifier retain];
    }
}

- (void)selectPaneWithIdentifier:(NSString *)identifier force:(BOOL)force {
    if ([identifier isEqualToString:[self selectedPaneIdentifier]] == NO && (force || delayedPaneIdentifier == nil)) {
        BDSKPreferencePane *pane = [self paneForIdentifier:identifier];
        BDSKPreferencePane *oldPane = [self selectedPane];
        NSView *view = pane ? [pane view] : [self iconView];
        if ((pane || [identifier isEqualToString:@""]) && view) {
            if ([[[self window] firstResponder] isKindOfClass:[NSText class]] && [(NSView *)[[self window] firstResponder] isDescendantOf:[oldPane view]])
                [[self window] makeFirstResponder:nil];
            BDSKPreferencePaneUnselectReply shouldUnselect = [[self window] attachedSheet] ? BDSKPreferencePaneUnselectCancel : (force == NO && oldPane) ? [oldPane shouldUnselect]  : BDSKPreferencePaneUnselectNow;
            [self setDelayedPaneIdentifier:nil];
            if (shouldUnselect == BDSKPreferencePaneUnselectNow) {
                [oldPane willUnselect];
                [pane willSelect];
                [[self window] setTitle:pane ? [self localizedTitleForIdentifier:identifier] : [self defaultWindowTitle]];
                [self changeContentView:view display:[[self window] isVisible]];
                [oldPane didUnselect];
                [pane didSelect];
                [self setSelectedPaneIdentifier:identifier];
                [[[self window] toolbar] setSelectedItemIdentifier:pane ? identifier : BDSKPreferencesToolbarShowAllItemIdentifier];
                [helpButton setHidden:(helpBookName == nil || [pane helpAnchor] == nil) && [pane helpURL] == nil];
                [revertButton setEnabled:[[pane initialValues] count] > 0];
                [self updateSearchAndShowAll:NO];
            } else if (shouldUnselect == BDSKPreferencePaneUnselectLater) {
                [self setDelayedPaneIdentifier:identifier];
            }
        }
    }
}

- (void)selectPaneWithIdentifier:(NSString *)identifier {
    [self selectPaneWithIdentifier:identifier force:NO];
}

- (void)replyToShouldUnselect:(BOOL)shouldUnselect {
    if (shouldUnselect && delayedPaneIdentifier)
        [self selectPaneWithIdentifier:delayedPaneIdentifier force:YES];
    [self setDelayedPaneIdentifier:nil];
}

- (NSString *)localizedString:(NSString *)string {
    return string ? [[NSBundle mainBundle] localizedStringForKey:string value:nil table:LOCALIZATION_TABLE] : nil;
}

- (NSString *)titleForCategory:(NSString *)category {
    return [[categoryDicts objectForKey:category] valueForKey:TITLE_KEY] ?: category;
}

- (NSString *)localizedTitleForCategory:(NSString *)category {
    return [self localizedString:[self titleForCategory:category]];
}

- (NSImage *)iconForIdentifier:(NSString *)identifier {
    return [[self paneForIdentifier:identifier] icon];
}

- (NSString *)localizedTitleForIdentifier:(NSString *)identifier {
    return [self localizedString:[[self paneForIdentifier:identifier] title]];
}

- (NSString *)localizedLabelForIdentifier:(NSString *)identifier {
    return [self localizedString:[[self paneForIdentifier:identifier] label]];
}

- (NSString *)localizedToolTipForIdentifier:(NSString *)identifier {
    return [self localizedString:[[self paneForIdentifier:identifier] toolTip]];
}

#pragma mark NSToolbar delegate

- (void)setupToolbar {
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:BDSKPreferencesToolbarIdentifier];
    [toolbar setDelegate:self];
    [toolbar setVisible:YES];
    [toolbar setAllowsUserCustomization:YES];
    //[toolbar setAutosavesConfiguration:YES];
    if ([toolbar respondsToSelector:@selector(_setCustomizesAlwaysOnClickAndDrag:)])
        [toolbar _setCustomizesAlwaysOnClickAndDrag:YES];
    if ([toolbar respondsToSelector:@selector(_setWantsToolbarContextMenu:)])
        [toolbar _setWantsToolbarContextMenu:NO];
    if ([toolbar respondsToSelector:@selector(_setFirstMoveableItemIndex:)])
        [toolbar _setFirstMoveableItemIndex:4];
    [[self window] setToolbar:toolbar];
    [toolbar setSelectedItemIdentifier:BDSKPreferencesToolbarShowAllItemIdentifier];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    NSToolbarItem *item = [toolbarItems objectForKey:itemIdentifier];
    if (item == nil) {
        BDSKPreferencePane *pane;
        if (toolbarItems == nil)
            toolbarItems = [[NSMutableDictionary alloc] init];
        if ([itemIdentifier isEqualToString:BDSKPreferencesToolbarShowAllItemIdentifier]) {
            if (item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier]) {
                [item setTarget:self];
                [item setAction:@selector(showAll:)];
                [item setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
                [item setLabel:NSLocalizedString(@"Show All", @"Toolbar item label")];
            }
        } else if ([itemIdentifier isEqualToString:BDSKPreferencesToolbarPreviousItemIdentifier]) {
            if (item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier]) {
                [item setTarget:self];
                [item setAction:@selector(showPreviousPane:)];
                [item setImage:[NSImage imageNamed:@"previous"]];
                [item setLabel:NSLocalizedString(@"Previous", @"Toolbar item label")];
            }
        } else if ([itemIdentifier isEqualToString:BDSKPreferencesToolbarNextItemIdentifier]) {
            if (item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier]) {
                [item setTarget:self];
                [item setAction:@selector(showNextPane:)];
                [item setImage:[NSImage imageNamed:@"next"]];
                [item setLabel:NSLocalizedString(@"Next", @"Toolbar item label")];
            }
        } else if ([itemIdentifier isEqualToString:BDSKPreferencesToolbarSearchItemIdentifier]) {
            if (item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier]) {
                [item setMinSize:[searchField frame].size];
                [item setMaxSize:NSMakeSize(200.0, NSHeight([searchField frame]))];
                [item setView:searchField];
                [item setLabel:NSLocalizedString(@"Search", @"Toolbar item label")];
            }
        } else if (pane = [self paneForIdentifier:itemIdentifier]) {
            if (item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier]) {
                [item setTarget:self];
                [item setAction:@selector(showPane:)];
                [item setImage:[pane icon]];
                [item setLabel:[self localizedLabelForIdentifier:itemIdentifier]];
            }
        }
        if (item) {
            [toolbarItems setObject:item forKey:itemIdentifier];
            [item release];
        }
    }
    if (flag == NO)
        item = [[item copy] autorelease];
	return item;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	NSMutableArray *identifiers = [NSMutableArray array];
    [identifiers addObject:BDSKPreferencesToolbarShowAllItemIdentifier];
    [identifiers addObject:BDSKPreferencesToolbarPreviousItemIdentifier];
    [identifiers addObject:BDSKPreferencesToolbarNextItemIdentifier];
    [identifiers addObject:NSToolbarSeparatorItemIdentifier];
    [identifiers addObject:BDSKPreferencesToolbarSearchItemIdentifier];
	return identifiers;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	NSMutableArray *identifiers = [NSMutableArray array];
    [identifiers addObject:BDSKPreferencesToolbarShowAllItemIdentifier];
    [identifiers addObject:BDSKPreferencesToolbarPreviousItemIdentifier];
    [identifiers addObject:BDSKPreferencesToolbarNextItemIdentifier];
    [identifiers addObject:NSToolbarSeparatorItemIdentifier];
    [identifiers addObject:BDSKPreferencesToolbarSearchItemIdentifier];
    [identifiers addObjectsFromArray:[self allPaneIdentifiers]];
	return identifiers;
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
	NSMutableArray *identifiers = [NSMutableArray array];
    [identifiers addObject:BDSKPreferencesToolbarShowAllItemIdentifier];
    [identifiers addObjectsFromArray:[self allPaneIdentifiers]];
	return identifiers;
}

#pragma mark BDSKSpotlightView delegate

- (NSArray *)spotlightViewCircleRects:(BDSKSpotlightView *)spotlightView {
    if ([[searchField stringValue] length] == 0)
        return nil;
    
    NSString *searchTerm = [searchField stringValue];
    NSUInteger i, iMax = [categories count];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:iMax];
    
    for (i = 0; i < iMax; i++) {
        NSArray *paneIDs = [self panesForCategory:[categories objectAtIndex:i]];
        NSUInteger j, jMax = [paneIDs count];
        
        for (j = 0; j < jMax; j++) {
            NSString *string = [identifierSearchTerms objectForKey:[paneIDs objectAtIndex:j]];
            if ([string rangeOfString:searchTerm options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound) {
                // as the overlay exactly covers the iconView, and both the spotlightView and the iconView are flipped, they should use the same coordinate space
                // don't go through screen coordinates, as the overlay may not have been put in place yet at this point
                [array addObject:[NSValue valueWithRect:[[self iconView] iconFrameAtRow:i column:j]]];
            }
        }
    }
        
    return array;
}

#pragma mark Private

- (void)loadPreferences {
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:DEFAULTS_TABLE ofType:@"plist"];
    NSArray *categoryArray = [NSArray arrayWithContentsOfFile:plistPath];
    NSMutableDictionary *initialValues = [NSMutableDictionary dictionary];
	
    NSAssert(categoryArray != nil, @"Could not find preferences in main bundle");
    
    SInt32 majorVersion = 0, minorVersion = 0, bugfixVersion = 0;
	BDSKVersionNumber *systemVersion = nil;
    if (noErr == Gestalt(gestaltSystemVersionMajor, &majorVersion) && noErr == Gestalt(gestaltSystemVersionMinor, &minorVersion) && noErr == Gestalt(gestaltSystemVersionBugFix, &bugfixVersion))
        systemVersion = [BDSKVersionNumber versionNumberWithVersionString:[NSString stringWithFormat:@"%i.%i.%i", majorVersion, minorVersion, bugfixVersion]];
    
    for (NSDictionary *dict in categoryArray) {
        NSMutableArray *paneArray = [[NSMutableArray alloc] init];
        
        for (NSDictionary *paneDict in [dict valueForKey:PANES_KEY]) {
            BDSKPreferenceRecord *record = [[BDSKPreferenceRecord alloc] initWithDictionary:paneDict];
            NSString *identifier = [record identifier];
            // should we register defaults for panes that are not loaded?
            [initialValues addEntriesFromDictionary:[record initialValues]];
            [records setObject:record forKey:identifier];
            [record release];
            BDSKVersionNumber *minimumSystemVersion = [BDSKVersionNumber versionNumberWithVersionString:[paneDict valueForKey:MINIMUM_SYSTEM_VERSION_KEY]];
            BDSKVersionNumber *maximumSystemVersion = [BDSKVersionNumber versionNumberWithVersionString:[paneDict valueForKey:MAXIMUM_SYSTEM_VERSION_KEY]];
            if ((minimumSystemVersion == nil || [systemVersion compareToVersionNumber:minimumSystemVersion] != NSOrderedAscending) &&
                (maximumSystemVersion == nil || [systemVersion compareToVersionNumber:maximumSystemVersion] != NSOrderedDescending))
                [paneArray addObject:identifier];
        }
        
        NSString *category = [dict valueForKey:IDENTIFIER_KEY];
        BDSKPOSTCONDITION(category != nil);
        NSMutableDictionary *catDict = [[NSMutableDictionary alloc] init];
        [catDict setValue:category forKey:IDENTIFIER_KEY];
        [catDict setValue:[dict valueForKey:TITLE_KEY] forKey:TITLE_KEY];
        [catDict setObject:paneArray forKey:PANES_KEY];
        [categoryDicts setObject:catDict forKey:category];
        [categories addObject:category];
        [catDict release];
        [initialValues addEntriesFromDictionary:[dict valueForKey:INITIAL_VALUES_KEY]];
        [paneArray release];
    }
    
    if ([initialValues count]) {
        [[NSUserDefaults standardUserDefaults] registerDefaults:initialValues];
        [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:initialValues];
    }
}

- (void)loadPanes {
    for (NSString *category in categories) {
        for (NSString *identifier in [[categoryDicts objectForKey:category] valueForKey:PANES_KEY]) {
            BDSKPreferenceRecord *record = [records objectForKey:identifier];
            BDSKPreferencePane *pane = [[[record paneClass] alloc] initWithRecord:record forPreferenceController:self];
            BDSKPOSTCONDITION(pane != nil);
            [panes setObject:pane forKey:identifier];
            [pane release];
            NSArray *searchTerms = [record searchTerms];
            if ([searchTerms count]) {
                NSMutableString *searchString = [[NSMutableString alloc] init];
                for (NSString *string in searchTerms)
                    [searchString appendFormat:@"%@%C", [[NSBundle mainBundle] localizedStringForKey:string value:@"" table:DEFAULTS_TABLE], 0x1E];
                [identifierSearchTerms setObject:searchString forKey:identifier];
                [searchString release];
            }
        }
    }
}

- (BDSKPreferenceIconView *)iconView {
    if (iconView == nil)
        [self window];
    return iconView;
}

- (void)changeContentView:(NSView *)view display:(BOOL)display {
	NSRect viewFrame = [view frame];
    NSSize winSize = NSMakeSize(fmax(NSWidth(viewFrame), 200.0), fmax(NSHeight(viewFrame), 100.0));
    NSRect contentRect = [[[self window] contentView] bounds];
    
    if ([view isEqual:[self iconView]]) {
        viewFrame.size.width = NSWidth(contentRect);
        [controlView removeFromSuperview];
        [view setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    } else {
        NSRect controlRect;
        NSDivideRect(contentRect, &controlRect, &contentRect, NSHeight([controlView frame]), NSMinYEdge);
        winSize.height += NSHeight(controlRect);
        [controlView setFrame:controlRect];
        [[[self window] contentView] addSubview:controlView];
        [view setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
        [overlay remove];
    }
    [[contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [contentView setFrame:contentRect];
    viewFrame.origin = NSMakePoint(0.0, NSHeight(contentRect) - NSHeight(viewFrame));
    [view setFrame:viewFrame];
    [contentView addSubview:view];
	
    contentRect = [[self window] contentRectForFrameRect:[[self window] frame]];
    contentRect.origin.y = NSMaxY(contentRect) - winSize.height;
    contentRect.size = winSize;
    contentRect = [[self window] frameRectForContentRect:contentRect];
    
    NSRect screenRect = [([[self window] screen] ?: [NSScreen mainScreen]) visibleFrame];
    if (NSMaxX(contentRect) > NSMaxX(screenRect))
        contentRect.origin.y = NSMaxX(screenRect) - NSWidth(contentRect);
    if (NSMinX(contentRect) < NSMinX(screenRect))
        contentRect.origin.y = NSMinY(screenRect);
    if (NSMinY(contentRect) < NSMinY(screenRect))
        contentRect.origin.y = NSMinY(screenRect);
    if (NSMaxY(contentRect) > NSMaxY(screenRect))
        contentRect.origin.y = NSMaxY(screenRect) - NSHeight(contentRect);
        
	[[self window] setFrame:contentRect display:display animate:display];
}

- (void)updateSearchAndShowAll:(BOOL)showAll {
    if ([[searchField stringValue] length] > 0) {
        if (showAll && [[self selectedPaneIdentifier] isEqualToString:@""] == NO) {
            // this will call back to us to show the overlay
            [self selectPaneWithIdentifier:@""];
        } else if ([[[self iconView] window] isEqual:[self window]]) {
            // the view will now ask us which icons to highlight
            [[overlay contentView] setNeedsDisplay:YES];
            if ([[overlay parentWindow] isEqual:[self window]] == NO)
                [overlay overlayView:[self iconView]];
        }
    } else {
        [overlay remove];
    }
}

@end
