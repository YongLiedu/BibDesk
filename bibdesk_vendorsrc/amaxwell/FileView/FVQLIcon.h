//
//  FVQLIcon.h
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FVIcon.h"
#import "FVIcon_Private.h"

@interface FVQLIcon : FVIcon
{
@private
    NSURL          *_fileURL;
    CGImageRef      _imageRef;
    NSSize          _fullSize;
    NSSize          _desiredSize;
    FVIcon         *_fallbackIcon;
    pthread_mutex_t _mutex;
}
- (id)initWithURL:(NSURL *)theURL;
@end
