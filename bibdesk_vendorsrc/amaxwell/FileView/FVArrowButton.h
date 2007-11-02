//
//  FVArrowButton.h
//  FileViewTest
//
//  Created by Adam Maxwell on 09/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FVArrowButton : NSButton
{
    NSUInteger _arrowDirection;
}

+ (id)newLeftArrowWithSize:(NSSize)size;
+ (id)newRightArrowWithSize:(NSSize)size;

@end
