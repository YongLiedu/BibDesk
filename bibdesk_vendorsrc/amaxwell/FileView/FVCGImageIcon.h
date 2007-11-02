//
//  FVCGImageIcon.h
//  FileView
//
//  Created by Adam Maxwell on 10/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FVIcon.h"
#import "FVIcon_Private.h"

@interface FVCGImageIcon : FVIcon
{
@private
    NSURL          *_fileURL;
    CGImageRef      _thumbnailRef;
    NSSize          _thumbnailSize;
    CGImageRef      _fullImageRef;
    NSSize          _fullSize;
    FVIconType      _iconType;
    BOOL            _inDiskCache;
    char           *_diskCacheName;
    pthread_mutex_t _mutex;
}
- (id)initWithImageAtURL:(NSURL *)aURL;
- (id)initWithQTMovieAtURL:(NSURL *)aURL;
@end
