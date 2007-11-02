//
//  FVFinderIcon.h
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FVIcon.h"
#import "FVIcon_Private.h"

@interface FVFinderIcon : FVIcon
{
@private
    IconRef         _iconRef;
    CGImageRef      _imageRef;
    NSSize          _iconSize;
    NSSize          _desiredSize;
    FVIconType      _iconType;
    BOOL            _inDiskCache;
    pthread_mutex_t _mutex;
}
- (id)initWithFinderIconOfURL:(NSURL *)theURL ofSize:(NSSize)iconSize;
- (id)initWithURLScheme:(NSString *)scheme ofSize:(NSSize)iconSize;
@end
