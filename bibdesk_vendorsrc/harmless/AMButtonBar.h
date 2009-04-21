//
//  AMButtonBar.h
//  ButtonBarTest
//
//  Created by Andreas on 09.02.07.
//  Copyright 2007 Andreas Mayer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AMButtonBarItem;
@class AMButtonBarCell;


extern NSString *const AMButtonBarSelectionDidChangeNotification;


@interface NSObject (AMButtonBarDelegate)
- (void)buttonBarSelectionDidChange:(NSNotification *)aNotification;
@end


@interface AMButtonBar : NSView {
	id delegate;
	NSColor *baselineSeparatorColor;
	BOOL showsBaselineSeparator;
	BOOL allowsMultipleSelection;
	NSMutableArray *items;
}


- (id)initWithFrame:(NSRect)frame;

- (NSArray *)items;

- (NSString *)selectedItemIdentifier;
- (NSArray *)selectedItemIdentifiers;

- (AMButtonBarItem *)itemAtIndex:(NSInteger)index;
- (void)didClickItem:(AMButtonBarItem *)item;

- (void)insertItem:(AMButtonBarItem *)item atIndex:(NSInteger)index;

- (void)removeItem:(AMButtonBarItem *)item;
- (void)removeItemAtIndex:(NSInteger)index;
- (void)removeAllItems;

- (void)selectItemWithIdentifier:(NSString *)identifier;
- (void)selectItemsWithIdentifiers:(NSArray *)identifierList;

- (id)delegate;
- (void)setDelegate:(id)value;

- (BOOL)allowsMultipleSelection;
- (void)setAllowsMultipleSelection:(BOOL)value;

@end
