//
//	AMButtonBar.m
//	ButtonBarTest
//
//	Created by Andreas on 09.02.07.
//	Copyright 2007 Andreas Mayer. All rights reserved.
//

#import "AMButtonBar.h"
#import "AMButtonBarItem.h"
#import "AMButtonBarCell.h"

static float const AM_START_GAP_WIDTH = 8.0;
static float const AM_BUTTON_GAP_WIDTH = 2.0;
static float const AM_BUTTON_HEIGHT = 17.0;

NSString *const AMButtonBarSelectionDidChangeNotification = @"AMButtonBarSelectionDidChangeNotification";

@interface AMButtonBar (Private)
- (void)setItems:(NSArray *)newItems;
- (void)layoutItems;
- (void)frameDidChange:(NSNotification *)aNotification;
@end


@implementation AMButtonBar

- (id)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
        [self setItems:[NSMutableArray array]];
        allowsMultipleSelection = NO;
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder]) {
        delegate = [decoder decodeObjectForKey:@"AMBBDelegate"];
        allowsMultipleSelection = [decoder decodeBoolForKey:@"AMBBAllowsMultipleSelection"];
        [self setItems:[decoder decodeObjectForKey:@"AMBBItems"]];
	}
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeConditionalObject:delegate forKey:@"AMBBDelegate"];
	[coder encodeBool:allowsMultipleSelection forKey:@"AMBBAllowsMultipleSelection"];
	[coder encodeObject:items forKey:@"AMBBItems"];
}


- (void)dealloc
{
	[items release];
	[super dealloc];
}


//====================================================================
#pragma mark 		accessors
//====================================================================

- (id)delegate
{
	return delegate;
}

- (void)setDelegate:(id)value
{
	// do not retain delegate
	delegate = value;
}

- (BOOL)allowsMultipleSelection
{
	return allowsMultipleSelection;
}

- (void)setAllowsMultipleSelection:(BOOL)value
{
	if (allowsMultipleSelection != value) {
		allowsMultipleSelection = value;
	}
}

- (NSArray *)items
{
	return items;
}

- (void)setItems:(NSArray *)newItems
{
	if (items != newItems) {
		[items release];
		items = [newItems mutableCopy];
	}
}

- (NSString *)selectedItemIdentifier
{
	NSString *result = nil;
	NSEnumerator *enumerator = [[self items] objectEnumerator];
	AMButtonBarItem *item;
	while (item = [enumerator nextObject]) {
		if ([item state] == NSOnState) {
			result = [item itemIdentifier];
			break;
		}
	}
	return result;
}

- (NSArray *)selectedItemIdentifiers
{
	NSMutableArray *result = [NSMutableArray array];
	NSEnumerator *enumerator = [[self items] objectEnumerator];
	AMButtonBarItem *item;
	while (item = [enumerator nextObject]) {
		if ([item state] == NSOnState) {
			[result addObject:[item itemIdentifier]];
		}
	}
	return result;
}

//====================================================================
#pragma mark 		public methods
//====================================================================

- (AMButtonBarItem *)itemAtIndex:(NSInteger)idx
{
	return [items objectAtIndex:idx];
}

- (void)insertItem:(AMButtonBarItem *)item atIndex:(NSInteger)idx
{
	[items insertObject:item atIndex:idx];
    [item setTarget:self];
    [item setAction:@selector(didClickItem:)];
    [self addSubview:item];
    [self setNeedsDisplay:YES];
}

- (void)removeItem:(AMButtonBarItem *)item
{
    [item setTarget:nil];
	[items removeObject:item];
    [item removeFromSuperviewWithoutNeedingDisplay];
	[self setNeedsDisplay:YES];
}

- (void)removeItemAtIndex:(NSInteger)idx
{
	[self removeItem:[items objectAtIndex:idx]];
}

- (void)removeAllItems
{
    [items makeObjectsPerformSelector:@selector(removeFromSuperviewWithoutNeedingDisplay)];
    [items makeObjectsPerformSelector:@selector(setTarget:) withObject:nil];
	[items removeAllObjects];
	[self setNeedsDisplay:YES];
}

- (void)selectItemWithIdentifier:(NSString *)identifier
{
	NSEnumerator *enumerator = [[self items] objectEnumerator];
	AMButtonBarItem *item;
	while (item = [enumerator nextObject]) {
		if ([[item itemIdentifier] isEqualToString:identifier]) {
			[self didClickItem:item];
			break;
		}
	}
}

- (void)selectItemsWithIdentifiers:(NSArray *)identifierList
{
	if ([self allowsMultipleSelection] || ([identifierList count] < 2)) {
		NSEnumerator *enumerator = [[self items] objectEnumerator];
		AMButtonBarItem *item;
		while (item = [enumerator nextObject]) {
			if ([identifierList containsObject:[item itemIdentifier]]) {
				[self didClickItem:item];
			}
		}
	}
}


//====================================================================
#pragma mark 		private methods
//====================================================================

- (void)layoutItems
{
	NSPoint origin = NSMakePoint(AM_START_GAP_WIDTH, floorf((NSHeight([self frame]) - AM_BUTTON_HEIGHT) / 2.0));
	NSEnumerator *enumerator = [[self items] objectEnumerator];
	id item;
	while (item = [enumerator nextObject]) {
        [item sizeToFit];
		[item setFrameOrigin:origin];
		origin.x += [item frame].size.width + AM_BUTTON_GAP_WIDTH;
	}
}

- (void)didClickItem:(AMButtonBarItem *)theItem
{
	BOOL didChangeSelection = NO;
	if (![self allowsMultipleSelection]) {
        NSEnumerator *enumerator = [[self items] objectEnumerator];
        AMButtonBarItem *item;
        while (item = [enumerator nextObject]) {
            if (item == theItem) {
                // the button click already swaps the state
                if ([item state] == NSOnState)
                    didChangeSelection = YES;
                else
                    [item setState:NSOnState];
            }
            else if ([item state] == NSOnState && item != theItem) {
                [item setState:NSOffState];
                [self setNeedsDisplayInRect:[item frame]];
                didChangeSelection = YES;
            }
        }
	} else {
		didChangeSelection = YES;
	}
    [self setNeedsDisplayInRect:[theItem frame]];
	if (didChangeSelection) {
        NSNotification *notification = [NSNotification notificationWithName:AMButtonBarSelectionDidChangeNotification object:self userInfo:[NSDictionary dictionaryWithObject:[self selectedItemIdentifiers] forKey:@"selectedItems"]];
		if ([delegate respondsToSelector:@selector(buttonBarSelectionDidChange:)]) {
			[delegate buttonBarSelectionDidChange:notification];
		}
		[[NSNotificationCenter defaultCenter] postNotification:notification];
	}
}

//====================================================================
#pragma mark 		NSView methods
//====================================================================

- (void)drawRect:(NSRect)rect
{
    [self layoutItems];
    [super drawRect:rect];
}

- (BOOL)isFlipped
{
	return NO;
}


@end
