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
- (void)am_commonInit;
- (void)setItems:(NSArray *)newItems;
- (void)layoutItems;
- (void)frameDidChange:(NSNotification *)aNotification;
@end


@implementation AMButtonBar

- (id)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		[self am_commonInit];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];
	[self am_commonInit];
	delegate = [decoder decodeObjectForKey:@"AMBBDelegate"];
	allowsMultipleSelection = [decoder decodeBoolForKey:@"AMBBAllowsMultipleSelection"];
	[self setItems:[decoder decodeObjectForKey:@"AMBBItems"]];
	return self;
}

- (void)am_commonInit
{
	[self setItems:[NSMutableArray array]];
    allowsMultipleSelection = NO;
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
		id old = items;
		items = [newItems mutableCopy];
		[old release];
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

- (AMButtonBarItem *)itemAtIndex:(int)idx
{
	return [items objectAtIndex:idx];
}

- (void)insertItem:(AMButtonBarItem *)item atIndex:(int)idx
{
	[items insertObject:item atIndex:idx];
    [item setButtonBar:self];
    [self addSubview:item];
    [self setNeedsDisplay:YES];
}

- (void)removeItem:(AMButtonBarItem *)item
{
    [item setButtonBar:nil];
	[items removeObject:item];
    [item removeFromSuperviewWithoutNeedingDisplay];
	[self setNeedsDisplay:YES];
}

- (void)removeItemAtIndex:(int)idx
{
	[self removeItem:[items objectAtIndex:idx]];
}

- (void)removeAllItems
{
    [items makeObjectsPerformSelector:@selector(removeFromSuperviewWithoutNeedingDisplay)];
    [items makeObjectsPerformSelector:@selector(setButtonBar:) withObject:nil];
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

- (void)resetTrackingRects
{
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4) {
        NSEnumerator *enumerator = [[self items] objectEnumerator];
        id item;
        while (item = [enumerator nextObject]) {
            NSRect frame = [item frame];
            [self removeTrackingRect:[item tag]];
            if (nil != [self window]) {
                NSTrackingRectTag tag = [self addTrackingRect:frame owner:self userData:item assumeInside:NO];
                [item setTag:tag];
            }
        }
    }
}

- (void)resetCursorRects
{
    [super resetCursorRects];
    [self resetTrackingRects];
}

- (void)mouseEntered:(NSEvent *)event
{
    [[(AMButtonBarItem *)[event userData] cell] mouseEntered:event];
    [super mouseEntered:event];
}
    
- (void)mouseExited:(NSEvent *)event
{
    [[(AMButtonBarItem *)[event userData] cell] mouseExited:event];
    [super mouseExited:event];
}

- (void)layoutItems
{
	NSPoint origin;
	origin.y = (([self frame].size.height-1 - AM_BUTTON_HEIGHT) / 2.0);
	if (![self isFlipped]) {
		origin.y += 1;
	}
	origin.x = AM_START_GAP_WIDTH;
	NSEnumerator *enumerator = [[self items] objectEnumerator];
	id item;
	while (item = [enumerator nextObject]) {
        [item sizeToFit];
		[item setFrameOrigin:origin];
		origin.x += [item frame].size.width;
		origin.x += AM_BUTTON_GAP_WIDTH;
	}
    [self resetTrackingRects];
}

- (void)didClickItem:(AMButtonBarItem *)theItem
{
	BOOL didChangeSelection = NO;
	if (![self allowsMultipleSelection]) {
        NSEnumerator *enumerator = [[self items] objectEnumerator];
        AMButtonBarItem *item;
        while (item = [enumerator nextObject]) {
            if (item == theItem && [item state] != NSOnState) {
                [item setState:NSOnState];
                didChangeSelection = YES;
            }
            else if ([item state] == NSOnState && item != theItem) {
                [item setState:NSOffState];
            }
        }
        [self setNeedsDisplay:YES];
	} else {
		[theItem setState:(([theItem state] == NSOnState) ? NSOffState : NSOnState)];
		[self setNeedsDisplayInRect:[theItem frame]];
		didChangeSelection = YES;
	}
	NSNotification *notification = [NSNotification notificationWithName:AMButtonBarSelectionDidChangeNotification object:self userInfo:[NSDictionary dictionaryWithObject:[self selectedItemIdentifiers] forKey:@"selectedItems"]];
	if (didChangeSelection) {
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

- (void)viewDidMoveToWindow
{
    [self resetTrackingRects];
}

- (BOOL)isFlipped
{
	return NO;
}


@end
