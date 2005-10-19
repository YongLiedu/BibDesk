//
//  ImageBackgroundBox.m
//  bd2xtest
//
//  Created by Michael McCracken on 7/26/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "ImageBackgroundBox.h"


@implementation ImageBackgroundBox

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        backgroundImage = nil;
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
    [[NSColor whiteColor] set];
    NSRectFill(rect);
    if(backgroundImage){
        [backgroundImage compositeToPoint:[self bounds].origin 
                                operation:NSCompositeSourceOver
                                 fraction:0.2];
    }
}

- (NSImage *)backgroundImage{
    return backgroundImage;
}

- (void)setBackgroundImage:(NSImage *)image{
    if(image != backgroundImage){
        [image autorelease];
        backgroundImage = [image retain];
    }
}

@end
