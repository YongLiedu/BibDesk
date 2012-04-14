//
//  AMButtonBarCell.h
//  AMButtonBar
//
//  Created by Andreas on Sat 2007-02-10
//  Copyright (c) 2004 Andreas Mayer. All rights reserved.

//	different representations:
// - off
//		(no background, text, text shadow)
// - off + mouse over
//		(light background without shadow, text, text shadow)
// - on
//		(medium background, top shadow, bottom light (shadow), text, text shadow)
// - on + mouse over
//		(light background, top shadow, bottom light (shadow), text, text shadow)
// - on/off + mouse down
//		(dark background, top shadow, bottom light (shadow), text, text shadow)


#import <AppKit/AppKit.h>

@interface AMButtonBarCell : NSButtonCell
{
    BOOL isMouseOver;
}



@end
