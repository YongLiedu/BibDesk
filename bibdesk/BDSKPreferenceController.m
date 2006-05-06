//
//  BDSKPreferenceController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 05/04/06.
/*
 This software is Copyright (c) 2006
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
#import "BDSKOverlay.h"
#import <OmniAppKit/OAPreferencesIconView.h>
#import <OmniAppKit/NSToolbar-OAExtensions.h>
#import <OmniAppKit/OAPreferenceClient.h>

@interface NSArray (Search)
- (BOOL)containsCaseInsensitiveSubstring:(NSString *)substring;
@end

@implementation NSArray (Search)

- (BOOL)containsCaseInsensitiveSubstring:(NSString *)substring;
{
    unsigned idx = [self count];
    id anObject;
    Class NSStringClass = [NSString class];
    while(idx--){
        anObject = [self objectAtIndex:idx];
        if([anObject isKindOfClass:NSStringClass] && [anObject rangeOfString:substring options:NSCaseInsensitiveSearch].length > 0)
            return YES;
    }
    return NO;
}

@end

@interface OAPreferenceController (PrivateOverride)
- (void)_showAllIcons:(id)sender;
@end

@implementation BDSKPreferenceController

+ (id)sharedPreferenceController;
{
    if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3)
        return [OAPreferenceController sharedPreferenceController];
    
    static id sharedController = nil;

    if(nil == sharedController)
            sharedController = [[self alloc] init];
    
    return sharedController;
}

- (id)init
{
    if(self = [super init]){
        NSWindow *theWindow = [self window];
        overlayWindow = [[BDSKOverlayWindow alloc] initWithContentRect:[[theWindow contentView] frame] styleMask:[theWindow styleMask] backing:[theWindow backingType] defer:YES];
        NSView *view = [[NSClassFromString(@"BDSKSpotlightView") alloc] initWithFrame:[[theWindow contentView] frame] delegate:self];
        [overlayWindow overlayView:[theWindow contentView]];
        [[overlayWindow contentView] addSubview:view];
        [view release];
        isSearchActive = NO;
        NSString *path = [[NSBundle mainBundle] pathForResource:@"PreferenceSearchTerms" ofType:@"plist"];
        if(nil == path)
            [NSException raise:NSInternalInconsistencyException format:@"unable to find search terms dictionary"];
        clientIdentiferSearchTerms = [[NSDictionary alloc] initWithContentsOfFile:path];
    }
    return self;
}

- (void)dealloc
{
    [clientIdentiferSearchTerms release];
    [searchTerm release];
    [overlayWindow release];
    [super dealloc];
}

- (void)iconView:(OAPreferencesIconView *)iconView buttonHitAtIndex:(unsigned int)index;
{
    isSearchActive = NO;
    [[overlayWindow contentView] setNeedsDisplay:YES];
    [super iconView:iconView buttonHitAtIndex:index];
}

- (IBAction)showPreferencesPanel:(id)sender;
{
    [super showPreferencesPanel:sender];
    [overlayWindow orderFront:nil];
}

- (BOOL)isSearchActive { return isSearchActive; }

static NSRect insetButtonRectAndShift(const NSRect aRect)
{
    // convert to a square
    float side = MAX(NSHeight(aRect), NSWidth(aRect));
    NSPoint center = NSMakePoint(NSMidX(aRect), NSMidY(aRect));
    
    // raise to account for the text; this is the button rect
    center.y += 10;
    
    return NSInsetRect(NSMakeRect(center.x - side/2, center.y - side/2, side, side), 10, 10);
}

- (NSArray *)highlightRects;
{
    // we have an array of OAPreferencesIconViews; one per category (row)
    NSEnumerator *viewE = [preferencesIconViews objectEnumerator];
    OAPreferencesIconView *view;
    NSMutableArray *rectArray = [NSMutableArray arrayWithCapacity:10];

    while(view = [viewE nextObject]){
        
        // get the preference client records; these are basically plists for each pref pane
        NSArray *records = [view preferenceClientRecords];
        unsigned i, numberOfRecords = [records count];
        NSString *identifier;
        
        for(i = 0; i < numberOfRecords; i++){
            
            
            NSArray *array = nil;
            identifier = [[records objectAtIndex:i] identifier];

            OBPRECONDITION(identifier != nil);
            if(nil != identifier)
                array = [clientIdentiferSearchTerms objectForKey:identifier];
            OBPOSTCONDITION(array != nil);
            
            if(array != nil && [array containsCaseInsensitiveSubstring:searchTerm]){
                // this is a private method, but declared in the header
                NSRect rect = [view _boundsForIndex:i];
                
                // convert from view-local to window coordinates
                rect = [view convertRect:rect toView:nil];
                [rectArray addObject:[NSValue valueWithRect:insetButtonRectAndShift(rect)]];
            }
        }
    }
        
    return rectArray;
}

// override this private method so we can add the searchfield to the toolbar item array (don't call super)
- (void)_setupCustomizableToolbar;
{
    NSArray *constantToolbarItems, *defaultClients;
    NSMutableArray *allClients;
    NSEnumerator *enumerator;
    id aClientRecord;
    
    constantToolbarItems = [NSArray arrayWithObjects:@"OAPreferencesShowAll", @"OAPreferencesPrevious", @"OAPreferencesNext", NSToolbarSeparatorItemIdentifier, @"PreferencesSearchField", nil];
    
    defaultClients = [[NSUserDefaults standardUserDefaults] arrayForKey:@"FavoritePreferenceIdentifiers"];
    
    allClients = [[NSMutableArray alloc] initWithCapacity:[_clientRecords count]];
    enumerator = [_clientRecords objectEnumerator];
    while ((aClientRecord = [enumerator nextObject])) {
        [allClients addObject:[(OAPreferenceClientRecord *)aClientRecord identifier]];
    }
    
    defaultToolbarItems = [[constantToolbarItems arrayByAddingObjectsFromArray:defaultClients] retain];
    allowedToolbarItems = [[constantToolbarItems arrayByAddingObjectsFromArray:allClients] retain];
    
    toolbar = [[NSToolbar alloc] initWithIdentifier:@"OAPreferenceIdentifiers"];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:NO]; // Don't store the configured items or new items won't show up!
    [toolbar setDelegate:self];
    [toolbar setAlwaysCustomizableByDrag:YES];
    [toolbar setShowsContextMenu:NO];
    [window setToolbar:toolbar];
    [toolbar setIndexOfFirstMovableItem:([constantToolbarItems count] - 1)];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)tb;
{
    NSMutableArray *array = [NSMutableArray arrayWithArray:[super toolbarSelectableItemIdentifiers:tb]];
    [array removeObject:@"PreferencesSearchField"];
    return array;
}

- (void)setSearchTerm:(NSString *)term;
{
    [searchTerm autorelease];
    searchTerm = [term copy];
}    

- (void)search:(id)sender;
{
    NSString *term = [sender stringValue];

    if([[[preferenceBox contentView] subviews] lastObject] != showAllIconsView){
        // this method will lose our first responder
        if([self respondsToSelector:@selector(_showAllIcons:)])
            [self _showAllIcons:nil];
        [[self window] makeFirstResponder:sender];
        
        // we just lost the insertion point; if the user just started typing, it should be at the end
        NSText *editor = (NSText *)[[self window] firstResponder];
        if(nil != editor && [editor isKindOfClass:[NSText class]])
            [editor setSelectedRange:NSMakeRange([term length], 0)];
    }

    isSearchActive = ([term isEqualToString:@""] || nil == term) ? NO : YES;
    [self setSearchTerm:[sender stringValue]];
    
    // the view will now ask us which icons to highlight
    [[overlayWindow contentView] setNeedsDisplay:YES];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)tb itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
{
    NSToolbarItem *tbItem = nil;
    if([itemIdentifier isEqual:@"PreferencesSearchField"]){
        tbItem = [[NSToolbarItem alloc] initWithItemIdentifier:@"PreferencesSearchField"];
        NSSearchField *searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect(0, 0, 30, 22)];
        [searchField setTarget:self];
        [searchField setAction:@selector(search:)];
        
        [tbItem setAction:@selector(search:)];
        [tbItem setTarget:self];
        [tbItem setMinSize:NSMakeSize(60, NSHeight([searchField frame]))];
        [tbItem setMaxSize:NSMakeSize(200,NSHeight([searchField frame]))];
        [tbItem setView:searchField];
        [searchField release];
        
        [tbItem setLabel:NSLocalizedString(@"Search", @"")];
        [tbItem setPaletteLabel:NSLocalizedString(@"Search", @"")];
        [tbItem setEnabled:YES];
        [tbItem autorelease];
    }        
    else tbItem = [super toolbar:tb itemForItemIdentifier:itemIdentifier willBeInsertedIntoToolbar:flag];
    
    return tbItem;
}

@end
