//
//  BDSKBackgroundView.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 26/2/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "BDSKBackgroundView.h"

@implementation BDSKBackgroundView
- (void)drawRect:(NSRect)rect
{
	[[NSColor controlColor] set];
	[NSBezierPath fillRect:rect];
	[super drawRect:rect];
}
@end
