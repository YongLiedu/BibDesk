//
//  FVScaledImageView.h
//  FileView
//
//  Created by Adam Maxwell on 09/22/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class FVIcon;

@interface FVScaledImageView : NSView
{
@private
    FVIcon             *_icon;
    NSURL              *_fileURL;
    NSBox              *_box;
    NSAttributedString *_text;
}

- (void)displayIconForURL:(NSURL *)aURL;
- (void)displayImageAtURL:(NSURL *)aURL;
@end
