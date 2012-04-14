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

@interface AMButtonBarItem : NSButton

- (id)initWithIdentifier:(NSString *)identifier;

- (NSString *)itemIdentifier;
- (void)setItemIdentifier:(NSString *)value;

@end
