//
//  FVTextIcon.h
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FVIcon.h"
#import "FVIcon_Private.h"

@interface FVTextIcon : FVIcon
{
@private
    CGImageRef      _fullImageRef;
    NSSize          _fullSize;
    CGImageRef      _thumbnailRef;
    NSSize          _thumbnailSize;
    NSURL          *_fileURL;
    BOOL            _inDiskCache;
    char           *_diskCacheName;
    pthread_mutex_t _mutex;
}
+ (BOOL)canInitWithURL:(NSURL *)aURL;
- (id)initWithTextAtURL:(NSURL *)aURL;
@end
