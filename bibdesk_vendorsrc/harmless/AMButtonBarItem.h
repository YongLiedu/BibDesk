//
//  AMButtonBarItem.h
//  ButtonBarTest
//
//  Created by Andreas on 09.02.07.
//  Copyright 2007 Andreas Mayer. All rights reserved.
//

//  tool tips and special items like separators and overflow menus are not yet supported


#import <Cocoa/Cocoa.h>

@class AMButtonBarCell, AMButtonBar;

@interface AMButtonBarItem : NSButton <NSCoding> {
	BOOL active;
	NSString *itemIdentifier;
    AMButtonBar *buttonBar;
}

- (id)initWithIdentifier:(NSString *)identifier;

- (BOOL)isActive;
- (void)setActive:(BOOL)value;

- (NSString *)itemIdentifier;
- (void)setItemIdentifier:(NSString *)value;

- (void)setButtonBar:(AMButtonBar *)aBar;

@end
